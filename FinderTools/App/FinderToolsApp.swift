import AppKit
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "AppDelegate")
    private var receivedFinderActionDuringLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        FinderMenuPreferences.updateApplications(AppDiscovery.allApplications())
        FinderMenuPreferences.startSyncingWithExtension()

        // LSUIElement keeps a background launch out of the Dock. A normal user
        // launch has no Finder command, so it becomes a regular foreground app.
        guard !receivedFinderActionDuringLaunch else { return }
        showForegroundApp(NSApp)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let commandURLs = urls.filter { $0.scheme == "findertools" }
        guard !commandURLs.isEmpty else { return }

        receivedFinderActionDuringLaunch = true
        logger.notice("Received \(commandURLs.count, privacy: .public) Finder action(s) in the background")
        for url in commandURLs {
            FinderActionHandler.shared.handle(url)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showForegroundApp(sender)

        // A background Finder action can leave the initial window hidden. Reuse
        // that window instead of asking SwiftUI to create a duplicate.
        if !flag, let window = sender.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }

    private func showForegroundApp(_ application: NSApplication) {
        application.setActivationPolicy(.regular)
        application.unhide(nil)
        application.activate(ignoringOtherApps: true)
    }
}

@main
struct FinderToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("FinderTools", id: "main") {
            ContentView()
        }
        .defaultSize(width: 900, height: 620)
        .windowResizability(.contentMinSize)
        // Finder commands are handled by AppDelegate instead of being routed
        // through this scene. That keeps a closed main window closed.
        .handlesExternalEvents(matching: [])
        .commands {
            // FinderTools only needs one settings window. Removing the standard
            // New Window command prevents accidental duplicate windows while a
            // WindowGroup keeps the app running after its last window closes.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
