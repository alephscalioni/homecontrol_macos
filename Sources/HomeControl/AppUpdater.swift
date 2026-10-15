import AppKit
import Combine
import HomeCore
import OSLog
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var isConfigured = false
    @Published private(set) var canCheckForUpdates = false
    private var controller: SPUStandardUpdaterController?
    private var observation: AnyCancellable?

    func start(enabled: Bool) {
        guard enabled, controller == nil, Bundle.main.bundleURL.pathExtension == "app" else { return }
        do {
            guard try UpdateConfiguration.read(info: Bundle.main.infoDictionary ?? [:]) != nil else { return }
            let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            self.controller = controller
            isConfigured = true
            observation = controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.canCheckForUpdates = $0 }
        } catch {
            Logger(subsystem: "br.com.homecontrol.mac", category: "updates").error("Configuração de atualização inválida; o atualizador não foi iniciado.")
        }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }
}
