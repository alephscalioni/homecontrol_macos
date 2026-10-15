import Foundation

/// Public release configuration only. The signing private key never belongs in an app bundle.
public struct UpdateConfiguration: Equatable, Sendable {
    public let feedURL: URL
    public let publicEDKey: String

    public static func read(info: [String: Any]) throws -> Self? {
        let feed = info["SUFeedURL"] as? String
        let key = info["SUPublicEDKey"] as? String
        if feed == nil && key == nil { return nil }
        guard let feed, let key,
              let components = URLComponents(string: feed), components.scheme == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              let url = components.url,
              let decodedKey = Data(base64Encoded: key), decodedKey.count == 32 else {
            throw ConfigurationError.invalid
        }
        return Self(feedURL: url, publicEDKey: key)
    }

    public enum ConfigurationError: LocalizedError {
        case invalid
        public var errorDescription: String? { L10n.text("A configuração de atualizações precisa de um feed HTTPS e de uma chave pública Ed25519 válida.") }
    }
}
