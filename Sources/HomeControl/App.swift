import AppKit
import SwiftUI
import HomeCore

@main
struct HomeControlMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private let store = HomeStore()
    private let updater = AppUpdater()
    private lazy var cameras = CameraManager(store: store)
    private var cameraWindow: NSWindow?
    private var cameraSession: CameraLiveSession?
    private var miniCameraWindow: MiniCameraWindow?
    private var miniCameraSession: CameraLiveSession?
    private var miniCameraID: String?
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var previewWindow: NSWindow?
    private var controlCoordinator: AnyObject?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let demo = CommandLine.arguments.contains("--demo")
        updater.start(enabled: !demo)
        installMainMenu()
        if demo { store.useDemo() } else { store.restore() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "house.fill", accessibilityDescription: "HomeControl")
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.target = self; button.action = #selector(togglePopover)
            button.toolTip = L10n.text("HomeControl · sua casa a um clique")
            button.setAccessibilityLabel("HomeControl")
        }
        let root = PanelView().environmentObject(store).environmentObject(updater).environmentObject(cameras)
            .environment(\.demoReduceMotion, demo && CommandLine.arguments.contains("--reduce-motion"))
        popover = NSPopover()
        popover.delegate = self
        popover.behavior = .semitransient
        popover.contentSize = NSSize(width: 440, height: 632)
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(rootView: root)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.wake() }
        }
        if demo && CommandLine.arguments.contains("--widget-preview") {
            let single = CommandLine.arguments.contains("--widget-single-preview")
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: single ? 206 : 400), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.text("Widget · Demonstração")
            window.isReleasedWhenClosed = false; window.delegate = self
            window.appearance = NSAppearance(named: .darkAqua)
            window.isOpaque = false; window.backgroundColor = .clear
            window.contentViewController = NSHostingController(rootView: WidgetDemoView(single: single, camerasPreview: CommandLine.arguments.contains("--camera-preview")).environmentObject(store).environmentObject(cameras))
            window.center(); window.makeKeyAndOrderFront(nil)
            previewWindow = window; updatePanelVisibility()
            NSApp.activate(ignoringOtherApps: true)
        } else if CommandLine.arguments.contains("--window") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 632), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = demo ? L10n.text("HomeControl · Demonstração") : "HomeControl"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.appearance = NSAppearance(named: .darkAqua)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentViewController = NSHostingController(rootView: root)
            window.center(); window.makeKeyAndOrderFront(nil)
            previewWindow = window
            updatePanelVisibility()
            NSApp.activate(ignoringOtherApps: true)
        } else if store.serverAddress.isEmpty || demo {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.showPopover() }
        }
        cameras.openViewer = { [weak self] id in self?.showMiniCamera(id: id) }
        controlCoordinator = HostControlCoordinator(store: store, cameras: cameras)

    }
    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }
    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let previewWindow { previewWindow.makeKeyAndOrderFront(nil) } else { showPopover() }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        (controlCoordinator as? HostControlCoordinator)?.stop()
        cameraSession?.stop(clear: true)
        miniCameraSession?.stop(clear: true)
        store.stopConnection()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
    func applicationDidResignActive(_ notification: Notification) {
        if popover?.isShown == true { popover.close() }
    }
    func popoverDidShow(_ notification: Notification) { updatePanelVisibility() }
    func popoverDidClose(_ notification: Notification) { updatePanelVisibility() }
    func windowDidChangeOcclusionState(_ notification: Notification) { updatePanelVisibility() }
    func windowDidMiniaturize(_ notification: Notification) { updatePanelVisibility() }
    func windowDidDeminiaturize(_ notification: Notification) { updatePanelVisibility() }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === miniCameraWindow {
            miniCameraSession?.stop(clear: true); miniCameraSession = nil; miniCameraWindow = nil; miniCameraID = nil
        }
        if let window = notification.object as? NSWindow, window === cameraWindow {
            cameraSession?.stop(clear: true); cameraSession = nil; cameraWindow = nil
        }
        store.isPanelVisible = popover?.isShown == true
        if CommandLine.arguments.contains("--widget-preview"),
           let window = notification.object as? NSWindow, window === previewWindow {
            previewWindow = nil
            store.stopConnection()
            store.entities = []; store.areas = [:]
            store.serverAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? ""
            store.favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
            store.showSettings = true
            store.restore()
            updater.start(enabled: true)
        }
    }
    private func showCamera(id: String) {
        guard let entity = store.cameraEntity(id: id) else { return }
        cameraWindow?.close()
        miniCameraWindow?.close()
        let session = CameraLiveSession(cameras: cameras, id: id)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 540), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = entity.name; window.minSize = NSSize(width: 540, height: 380)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false; window.delegate = self
        window.contentViewController = NSHostingController(rootView: CameraViewer(session: session, name: entity.name, room: store.areas[entity.id], makeMini: { [weak self] in self?.showMiniCamera(id: id) }).environmentObject(store))
        cameraSession = session; cameraWindow = window
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showMiniCamera(id: String) {
        guard let entity = store.cameraEntity(id: id) else { return }
        if miniCameraID == id, let window = miniCameraWindow {
            window.orderFrontRegardless()
            if miniCameraSession?.running == false { miniCameraSession?.start() }
            return
        }
        miniCameraWindow?.close(); cameraWindow?.close()
        let session = CameraLiveSession(cameras: cameras, id: id)
        let window = MiniCameraWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 191.25), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        window.title = L10n.format("Minicâmera · %@", entity.name)
        window.minSize = NSSize(width: 240, height: 135); window.maxSize = NSSize(width: 1280, height: 720)
        window.contentAspectRatio = NSSize(width: 16, height: 9)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        window.hidesOnDeactivate = false
        // The image owns dragging; the control strip keeps its mouse events.
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false; window.delegate = self
        let key = "cameraMini.alwaysOnTop"
        let staysOnTop = UserDefaults.standard.object(forKey: key) as? Bool ?? true
        window.level = staysOnTop ? .floating : .normal
        let controller = NSHostingController(rootView: MiniCameraView(session: session, name: entity.name, staysOnTop: staysOnTop, changeLevel: { [weak window] value in
                window?.level = value ? .floating : .normal
                UserDefaults.standard.set(value, forKey: key)
            },
            resize: { [weak self] in self?.resizeMiniCamera() },
            expand: { [weak self] in self?.showCamera(id: id) }, close: { [weak window] in window?.close() }).environmentObject(store))
        controller.sizingOptions = []
        window.contentViewController = controller
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: visible.maxX - 364, y: visible.minY + 24))
        }
        if window.setFrameUsingName("HomeControlMiniCamera"),
           !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) {
            window.center()
        }
        window.setFrameAutosaveName("HomeControlMiniCamera")
        miniCameraID = id; miniCameraSession = session; miniCameraWindow = window
        popover.performClose(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resizeMiniCamera() {
        guard let window = miniCameraWindow, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let current = window.frame
        let requested: CGFloat = current.width < 300 ? 340 : current.width < 400 ? 480 : 240
        let width = min(requested, visible.width, visible.height * 16 / 9)
        let height = width * 9 / 16
        let x = max(visible.minX, min(current.maxX - width, visible.maxX - width))
        let y = max(visible.minY, min(current.maxY - height, visible.maxY - height))
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func updatePanelVisibility() {
        let windowVisible = previewWindow.map { $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) } ?? false
        store.isPanelVisible = popover?.isShown == true || windowVisible
    }
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: L10n.text("Sair do HomeControl"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let editMenu = NSMenu(title: L10n.text("Editar")); editItem.submenu = editMenu
        editMenu.addItem(withTitle: L10n.text("Recortar"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.text("Copiar"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.text("Colar"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.text("Selecionar tudo"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
}
