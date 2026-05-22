import AppKit
import SwiftUI

@main
struct AeroxyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 680, minHeight: 440)
                .onAppear {
                    model.offerDefaultHTMLViewerRegistrationIfNeeded()
                    model.offerClipboardHTMLIfAvailable()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.offerClipboardHTMLIfAvailable()
                }
                .onOpenURL { url in
                    model.handleIncomingURL(url)
                }
                .background(WindowConfigurator())
        }
        .defaultSize(width: 980, height: 660)
        .windowResizability(.contentMinSize)
        .commands {
            AeroxyCommands(model: model)
        }
    }
}
