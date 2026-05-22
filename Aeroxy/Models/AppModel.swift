import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

struct PDFExportRequest: Equatable, Identifiable {
    let id = UUID()
    let destinationURL: URL
}

@MainActor
final class AppModel: ObservableObject {
    private let defaultHTMLViewerPromptKey = "DidOfferDefaultHTMLViewerRegistration"
    private var didOfferDefaultHTMLViewerRegistration = false
    private var lastPromptedClipboardChangeCount = -1

    @Published private(set) var tabs: [HTMLTab] = []
    @Published var selectedTabID: HTMLTab.ID?
    @Published private(set) var printRequestID = UUID()
    @Published private(set) var pdfExportRequest: PDFExportRequest?

    let history = HistoryStore()

    var selectedTab: HTMLTab? {
        guard let selectedTabID else {
            return nil
        }

        return tabs.first { $0.id == selectedTabID }
    }

    func registerBundleWithLaunchServices() {
        HTMLFileAssociation.registerCurrentBundle()
    }

    func offerDefaultHTMLViewerRegistrationIfNeeded() {
        registerBundleWithLaunchServices()

        guard !didOfferDefaultHTMLViewerRegistration,
              !UserDefaults.standard.bool(forKey: defaultHTMLViewerPromptKey),
              !HTMLFileAssociation.isAeroxyDefaultHTMLViewer
        else {
            return
        }

        didOfferDefaultHTMLViewerRegistration = true

        let alert = NSAlert()
        alert.messageText = "Use Aeroxy as the default app for local HTML files?"
        alert.informativeText = """
        Aeroxy can become the default viewer for .html, .htm, and .xhtml files so AI tools can hand local reports to it more reliably. Web links will still open in your system browser.
        """
        alert.addButton(withTitle: "Use Aeroxy")
        alert.addButton(withTitle: "Not Now")

        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        UserDefaults.standard.set(true, forKey: defaultHTMLViewerPromptKey)

        guard response == .alertFirstButtonReturn else {
            return
        }

        setAsDefaultHTMLViewer(showResultAlert: false)
    }

    func setAsDefaultHTMLViewer(showResultAlert: Bool = true) {
        registerBundleWithLaunchServices()

        do {
            try HTMLFileAssociation.setAeroxyAsDefaultHTMLViewer()

            if showResultAlert {
                showAssociationAlert(
                    message: "Aeroxy is now the default local HTML viewer.",
                    informativeText: "This only affects .html, .htm, and .xhtml files. Web links still open in your system browser."
                )
            }
        } catch {
            showAssociationAlert(
                message: "Aeroxy could not become the default local HTML viewer.",
                informativeText: error.localizedDescription
            )
        }
    }

    func offerClipboardHTMLIfAvailable() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount

        guard changeCount != lastPromptedClipboardChangeCount,
              let url = clipboardHTMLFileURL(from: pasteboard)
        else {
            return
        }

        lastPromptedClipboardChangeCount = changeCount

        let alert = NSAlert()
        alert.messageText = "Open HTML file from clipboard?"
        alert.informativeText = url.path
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")

        NSApplication.shared.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        openFileURL(url)
    }

    func openLocalHTMLPathText(_ text: String) throws {
        guard let url = URLPolicy.localHTMLFileURL(fromPathText: text) else {
            throw LocalHTMLPathError.invalidPath
        }

        openFileURL(url)
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
        NSApplication.shared.activate()

        if URLPolicy.isOpenableLocalHTML(url) {
            openFileURL(url)
            return
        }

        URLPolicy.openExternalURL(url)
    }

    func openFileURLs(_ urls: [URL]) {
        urls.forEach(openFileURL)
    }

    func openFileURL(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        let accessGranted = standardizedURL.startAccessingSecurityScopedResource()

        guard accessGranted || canReadFile(at: standardizedURL) else {
            requestReadPermission(for: standardizedURL)
            return
        }

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
        guard URLPolicy.isOpenableLocalHTML(url) else {
            URLPolicy.openExternalURL(url)
            return
        }

        openFileURL(url)
    }

    func printSelectedTab() {
        guard selectedTab != nil else {
            return
        }

        printRequestID = UUID()
    }

    func exportSelectedTabAsPDF() {
        guard let selectedTab else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.message = "Export the current HTML report as PDF"
        panel.nameFieldStringValue = selectedTab.fileURL
            .deletingPathExtension()
            .lastPathComponent + ".pdf"
        panel.prompt = "Export"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            Task { @MainActor in
                self?.pdfExportRequest = PDFExportRequest(destinationURL: url)
            }
        }
    }

    func clearPDFExportRequest(id: PDFExportRequest.ID) {
        guard pdfExportRequest?.id == id else {
            return
        }

        pdfExportRequest = nil
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

    private func showAssociationAlert(message: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.addButton(withTitle: "OK")
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func canReadFile(at url: URL) -> Bool {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            try? handle.close()
            return true
        } catch {
            return false
        }
    }

    private func requestReadPermission(for url: URL) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .html,
            UTType(filenameExtension: "htm"),
            UTType(filenameExtension: "xhtml")
        ].compactMap { $0 }
        panel.directoryURL = url.deletingLastPathComponent()
        panel.message = "Confirm access to open this local HTML file"
        panel.prompt = "Open"

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let selectedURL = panel.url else {
                return
            }

            Task { @MainActor in
                self?.openFileURL(selectedURL)
            }
        }
    }

    private func clipboardHTMLFileURL(from pasteboard: NSPasteboard) -> URL? {
        if let fileURLString = pasteboard.string(forType: .fileURL),
           let fileURL = URL(string: fileURLString),
           URLPolicy.isOpenableLocalHTML(fileURL),
           FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL.standardizedFileURL
        }

        guard let clipboardString = pasteboard.string(forType: .string) else {
            return nil
        }

        return URLPolicy.localHTMLFileURL(fromPathText: clipboardString)
    }
}

private enum LocalHTMLPathError: LocalizedError {
    case invalidPath

    var errorDescription: String? {
        "Paste a local .html, .htm, or .xhtml file path."
    }
}

private enum HTMLFileAssociation {
    private static let aeroxyBundleIdentifier = "dev.yixuanguo.aeroxy"
    private static let htmlContentTypeIdentifiers = [
        "public.html",
        "public.xhtml"
    ]

    static var isAeroxyDefaultHTMLViewer: Bool {
        htmlContentTypeIdentifiers.allSatisfy { identifier in
            let handler = LSCopyDefaultRoleHandlerForContentType(identifier as CFString, .viewer)?
                .takeRetainedValue() as String?
            return handler == Bundle.main.bundleIdentifier || handler == aeroxyBundleIdentifier
        }
    }

    static func registerCurrentBundle() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }

    static func setAeroxyAsDefaultHTMLViewer() throws {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? aeroxyBundleIdentifier
        let failures = htmlContentTypeIdentifiers.compactMap { identifier -> String? in
            let status = LSSetDefaultRoleHandlerForContentType(
                identifier as CFString,
                .viewer,
                bundleIdentifier as CFString
            )

            guard status != noErr else {
                return nil
            }

            return "\(identifier): OSStatus \(status)"
        }

        guard failures.isEmpty else {
            throw HTMLFileAssociationError(failures: failures)
        }
    }
}

private struct HTMLFileAssociationError: LocalizedError {
    let failures: [String]

    var errorDescription: String? {
        "Launch Services rejected the file association update: \(failures.joined(separator: ", "))"
    }
}
