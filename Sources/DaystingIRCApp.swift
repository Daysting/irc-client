import SwiftUI
import AppKit

private struct ThemeMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Theme") {
            Button("Theme Controls") {
                openWindow(id: "theme-controls")
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
        }
    }
}

final class AppActivationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Defer activation until the first run loop to avoid re-entrant layout during launch.
        DispatchQueue.main.async {
            self.activateAndFocusWindowIfNeeded()
        }
    }

    private func activateAndFocusWindowIfNeeded() {
        NSApp.activate(ignoringOtherApps: true)

        // Only force a key window if none is currently key.
        guard NSApp.keyWindow == nil else { return }
        guard let window = NSApp.windows.first(where: { !$0.isMiniaturized && $0.canBecomeKey }) else { return }

        window.orderFront(nil)
        window.makeKey()
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
        .commands {
            ThemeMenuCommands()
        }

        Window("Theme Controls", id: "theme-controls") {
            ThemeControlsView()
                .environmentObject(viewModel)
                .frame(minWidth: 760, minHeight: 360)
        }
        .windowResizability(.contentSize)
    }
}
