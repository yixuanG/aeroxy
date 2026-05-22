import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var pathText = ""
    @State private var pathError: String?

    var body: some View {
        ZStack {
            WindowMaterialBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabBarView(model: model)

                PathOpenBar(
                    pathText: $pathText,
                    pathError: pathError,
                    openAction: openTypedPath
                )

                Divider()
                    .opacity(0.42)

                Group {
                    if let tab = model.selectedTab {
                        WebView(
                            tab: tab,
                            printRequestID: model.printRequestID,
                            pdfExportRequest: model.pdfExportRequest,
                            didHandlePDFExportRequest: model.clearPDFExportRequest,
                            openFileInNewTab: model.openLinkedFileInNewTab
                        )
                        .id(tab.id)
                        .overlay {
                            if let loadError = tab.loadError {
                                LoadErrorView(message: loadError)
                                    .padding(24)
                            }
                        }
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

    private func openTypedPath() {
        do {
            try model.openLocalHTMLPathText(pathText)
            pathText = ""
            pathError = nil
        } catch {
            pathError = error.localizedDescription
        }
    }
}

private struct PathOpenBar: View {
    @Binding var pathText: String
    let pathError: String?
    let openAction: () -> Void

    private var canOpen: Bool {
        !pathText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Paste local HTML file path or file:// URL", text: $pathText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(openAction)

            if let pathError {
                Text(pathError)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Button {
                openAction()
            } label: {
                Image(systemName: "arrow.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.aeroxyGlass)
            .disabled(!canOpen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial)
    }
}

private struct LoadErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Could not render this HTML file")
                .font(.system(size: 14, weight: .semibold))

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
        .padding(18)
        .frame(maxWidth: 420)
        .aeroxyGlass(cornerRadius: 12)
    }
}
