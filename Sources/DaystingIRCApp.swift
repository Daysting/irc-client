import SwiftUI

@main
struct DaystingIRCApp: App {
    @StateObject private var viewModel = IRCViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}
