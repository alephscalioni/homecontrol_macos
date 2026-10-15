import Foundation
import HomeCore

@main
struct HomeControlCLI {
    struct Inventory: Codable {
        let server: String
        let capturedAt: String
        let administrator: Bool
        let registry: HARegistry
    }
    @MainActor static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("Erro: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    @MainActor private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first, ["inventory", "apply"].contains(command) else {
            print("HomeControlCLI inventory [arquivo.json]\nHomeControlCLI apply plano.json [pasta-de-backup]\nUsa somente o endereço e o token já configurados no app. Nunca recebe tokens pela linha de comando.")
            return
        }
        guard let saved = UserDefaults(suiteName: "br.com.homecontrol.mac")?.string(forKey: "serverAddress") else {
            throw HAError.server("Configure a conexão no aplicativo HomeControl primeiro.")
        }
        let url = try ServerAddress.normalize(saved)
        let account = url.absoluteString
        guard let token = try await Task.detached(operation: { try TokenVault.read(for: account) }).value else {
            throw HAError.server("Não há token salvo no Chaves para este Home Assistant. Conecte pelo app primeiro.")
        }
        let client = HomeAssistantClient()
        var names: [String: String] = [:]
        client.onEvent = { event in
            if case .snapshot(let entities) = event {
                names = Dictionary(entities.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            }
        }
        try await client.connect(to: url, token: token)
        defer { client.disconnect() }
        let user = try await client.request(["type": .string("auth/current_user")])
        let admin = user["is_admin"].bool == true || user["is_owner"].bool == true
        let registry = try await HARegistry.fetch(using: client, friendlyNames: names)
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        let inventory = Inventory(server: account, capturedAt: capturedAt, administrator: admin, registry: registry)
        if command == "inventory" {
            if arguments.count > 1 { try writePrivate(inventory, path: arguments[1]) }
            else { print(String(decoding: try encoder.encode(inventory), as: UTF8.self)) }
            printSummary(inventory)
            return
        }
        guard admin else { throw HAError.server("O usuário conectado não é administrador do Home Assistant; não foram feitas alterações.") }
        guard arguments.count > 1 else { throw HAError.server("Informe o arquivo de plano de organização.") }
        let plan = try JSONDecoder().decode(AreaAssignmentPlan.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
        guard try ServerAddress.normalize(plan.server) == url else { throw HAError.server("O plano pertence a outro servidor Home Assistant.") }
        try plan.validate(against: registry)
        let directory = arguments.count > 2 ? arguments[2] : ".homeassistant/backups"
        let stamp = capturedAt.replacingOccurrences(of: ":", with: "-")
        try writePrivate(inventory, path: "\(directory)/\(stamp)-before.json")
        try writePrivate(AreaAssignmentPlan(server: account, changes: plan.changes.reversed().map(\.reversed)), path: "\(directory)/\(stamp)-rollback.json")
        var applied: [AreaAssignment] = []
        do {
            for change in plan.changes {
                let current = try await HARegistry.fetch(using: client)
                try AreaAssignmentPlan(server: account, changes: [change]).validate(against: current)
                _ = try await client.request(change.payload)
                applied.append(change)
                print("Organizado: \(change.name)")
            }
            let after = try await HARegistry.fetch(using: client, friendlyNames: names)
            try AreaAssignmentPlan(server: account, changes: plan.changes.map(\.reversed)).validate(against: after)
            try writePrivate(Inventory(server: account, capturedAt: ISO8601DateFormatter().string(from: Date()), administrator: admin, registry: after), path: "\(directory)/\(stamp)-after.json")
            print("Verificado: \(applied.count) associações de cômodo. Nenhum comando de aparelho foi enviado.")
        } catch {
            FileHandle.standardError.write(Data("A aplicação falhou. Verificando reversão das alterações já confirmadas…\n".utf8))
            for change in applied.reversed() {
                do {
                    let current = try await HARegistry.fetch(using: client)
                    try AreaAssignmentPlan(server: account, changes: [change.reversed]).validate(against: current)
                    _ = try await client.request(change.reversed.payload)
                } catch {
                    FileHandle.standardError.write(Data("Não foi possível reverter \(change.name). Consulte o backup privado.\n".utf8))
                }
            }
            throw error
        }
    }
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder
    }
    private static func writePrivate<T: Encodable>(_ value: T, path: String) throws {
        let url = URL(fileURLWithPath: path)
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard !FileManager.default.fileExists(atPath: url.path) else { throw HAError.server("O arquivo já existe: \(url.lastPathComponent). Escolha um novo nome para preservar o inventário anterior.") }
        try encoder.encode(value).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private static func printSummary(_ inventory: Inventory) {
        let registry = inventory.registry
        print("Home Assistant conectado. Administrador: \(inventory.administrator ? "sim" : "não").")
        print("\(registry.areas.count) cômodos, \(registry.devices.count) dispositivos, \(registry.entities.count) entidades no registro.")
        print("Sem cômodo: \(registry.devices.filter { $0.areaID == nil }.count) dispositivos; \(registry.entities.filter { registry.effectiveAreaID(for: $0.id) == nil }.count) entidades.")
    }
}
