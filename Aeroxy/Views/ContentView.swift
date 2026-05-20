import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            WindowMaterialBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabBarView(model: model)

                Divider()
                    .opacity(0.42)

                Group {
                    if let tab = model.selectedTab {
                        WebView(
                            tab: tab,
                            openFileInNewTab: model.openLinkedFileInNewTab
                        )
                        .id(tab.id)
                    } else {
                        EmptyStateView(openAction: model.showOpenPanel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?

                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                guard let url else {
                    return
                }

                Task { @MainActor in
                    model.handleIncomingURL(url)
                }
            }

            return true
        }

        return false
    }
}

