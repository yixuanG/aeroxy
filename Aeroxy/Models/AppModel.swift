import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var tabs: [HTMLTab] = []
    @Published var selectedTabID: HTMLTab.ID?

    let history = HistoryStore()

    var selectedTab: HTMLTab? {
        guard let selectedTabID else {
            return nil
        }

        return tabs.first { $0.id == selectedTabID }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .html,
            UTType(filenameExtension: "htm"),
            UTType(filenameExtension: "xhtml")
        ].compactMap { $0 }
        panel.message = "Open local HTML reports"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            guard response == .OK else {
                return
            }

            Task { @MainActor in
                self?.openFileURLs(panel.urls)
            }
        }
    }

    func handleIncomingURL(_ url: URL) {
        if URLPolicy.isOpenableLocalHTML(url) {
            openFileURL(url)
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openFileURLs(_ urls: [URL]) {
        urls.forEach(openFileURL)
    }

    func openFileURL(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        let accessGranted = standardizedURL.startAccessingSecurityScopedResource()
        openResolvedFile(
            ResolvedHistoryFile(
                url: standardizedURL,
                securityScopeAccessGranted: accessGranted
            ),
            shouldRemember: true
        )
    }

    func openHistoryItem(_ item: HistoryItem) {
        do {
            let resolvedFile = try history.resolve(item)
            openResolvedFile(resolvedFile, shouldRemember: true)
        } catch {
            history.remember(item.fileURL)
        }
    }

    func openLinkedFileInNewTab(_ url: URL) {
        openFileURL(url)
    }

    func closeTab(_ tab: HTMLTab) {
        guard let index = tabs.firstIndex(of: tab) else {
            return
        }

        tabs.remove(at: index)

        if selectedTabID == tab.id {
            if tabs.indices.contains(index) {
                selectedTabID = tabs[index].id
            } else {
                selectedTabID = tabs.last?.id
            }
        }
    }

    func closeSelectedTab() {
        guard let selectedTab else {
            return
        }

        closeTab(selectedTab)
    }

    func selectPreviousTab() {
        selectTab(offset: -1)
    }

    func selectNextTab() {
        selectTab(offset: 1)
    }

    private func openResolvedFile(
        _ resolvedFile: ResolvedHistoryFile,
        shouldRemember: Bool
    ) {
        let standardizedURL = resolvedFile.url.standardizedFileURL

        if let existingTab = tabs.first(where: { $0.fileURL == standardizedURL }) {
            selectedTabID = existingTab.id

            if resolvedFile.securityScopeAccessGranted {
                standardizedURL.stopAccessingSecurityScopedResource()
            }

            if shouldRemember {
                history.remember(standardizedURL)
            }

            return
        }

        let tab = HTMLTab(
            fileURL: standardizedURL,
            securityScopeAccessGranted: resolvedFile.securityScopeAccessGranted
        )
        tabs.append(tab)
        selectedTabID = tab.id

        if shouldRemember {
            history.remember(standardizedURL)
        }
    }

    private func selectTab(offset: Int) {
        guard
            tabs.count > 1,
            let currentSelectedTabID = selectedTabID,
            let currentIndex = tabs.firstIndex(where: { $0.id == currentSelectedTabID })
        else {
            return
        }

        let nextIndex = (currentIndex + offset + tabs.count) % tabs.count
        selectedTabID = tabs[nextIndex].id
    }
}
