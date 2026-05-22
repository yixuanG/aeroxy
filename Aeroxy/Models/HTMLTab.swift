import Foundation

private final class SecurityScopedFileAccess {
    let isGranted: Bool
    private let url: URL

    init(url: URL, isGranted: Bool) {
        self.url = url
        self.isGranted = isGranted
    }

    deinit {
        if isGranted {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

@MainActor
final class HTMLTab: ObservableObject, Identifiable {
    let id: UUID
    @Published private(set) var fileURL: URL
    @Published private(set) var readAccessURL: URL

    @Published var title: String
    @Published var loadError: String?

    private var securityScopedFileAccess: SecurityScopedFileAccess

    init(
        id: UUID = UUID(),
        fileURL: URL,
        securityScopeAccessGranted: Bool
    ) {
        let standardizedURL = fileURL.standardizedFileURL
        self.id = id
        self.fileURL = standardizedURL
        self.readAccessURL = Self.bestReadAccessURL(
            for: standardizedURL,
            securityScopeAccessGranted: securityScopeAccessGranted
        )
        self.securityScopedFileAccess = SecurityScopedFileAccess(
            url: standardizedURL,
            isGranted: securityScopeAccessGranted
        )
        self.title = standardizedURL.deletingPathExtension().lastPathComponent
    }

    func replaceFileURL(_ fileURL: URL, securityScopeAccessGranted: Bool) {
        let standardizedURL = fileURL.standardizedFileURL

        guard self.fileURL != standardizedURL else {
            if securityScopeAccessGranted {
                if securityScopedFileAccess.isGranted {
                    standardizedURL.stopAccessingSecurityScopedResource()
                } else {
                    securityScopedFileAccess = SecurityScopedFileAccess(
                        url: standardizedURL,
                        isGranted: true
                    )
                }
            }

            return
        }

        securityScopedFileAccess = SecurityScopedFileAccess(
            url: standardizedURL,
            isGranted: securityScopeAccessGranted
        )
        self.fileURL = standardizedURL
        readAccessURL = Self.bestReadAccessURL(
            for: standardizedURL,
            securityScopeAccessGranted: securityScopeAccessGranted
        )
        title = standardizedURL.deletingPathExtension().lastPathComponent
        loadError = nil
    }

    var displayName: String {
        fileURL.lastPathComponent
    }

    var subtitle: String {
        fileURL.deletingLastPathComponent().path
    }

    private static func bestReadAccessURL(
        for fileURL: URL,
        securityScopeAccessGranted: Bool
    ) -> URL {
        let directoryURL = fileURL.deletingLastPathComponent()

        guard securityScopeAccessGranted || FileManager.default.isReadableFile(atPath: directoryURL.path) else {
            return fileURL
        }

        return directoryURL
    }
}

extension HTMLTab: Equatable {
    nonisolated static func == (lhs: HTMLTab, rhs: HTMLTab) -> Bool {
        lhs.id == rhs.id
    }
}
