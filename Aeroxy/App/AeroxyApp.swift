import SwiftUI

@main
struct AeroxyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 680, minHeight: 440)
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
