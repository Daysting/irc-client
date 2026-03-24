import SwiftUI
import AppKit

final class AppActivationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Ensure a key/main window is available for immediate text input.
        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct DaystingIRCApp: App {
    @StateObject private var viewModel = IRCViewModel()
    @NSApplicationDelegateAdaptor(AppActivationDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}
