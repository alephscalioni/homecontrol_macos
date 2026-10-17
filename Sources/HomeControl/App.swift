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
        let root = PanelView().environmentObject(store).environmentObject(updater)
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
            window.contentViewController = NSHostingController(rootView: WidgetDemoView(single: single).environmentObject(store))
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
        controlCoordinator = HostControlCoordinator(store: store)

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
