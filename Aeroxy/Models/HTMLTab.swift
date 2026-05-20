import Foundation

@MainActor
final class HTMLTab: ObservableObject, Identifiable {
    let id: UUID
    let fileURL: URL
    let readAccessURL: URL
    let securityScopeAccessGranted: Bool

    @Published var title: String
    @Published var loadError: String?

    init(
        id: UUID = UUID(),
        fileURL: URL,
        securityScopeAccessGranted: Bool
    ) {
        let standardizedURL = fileURL.standardizedFileURL
        self.id = id
        self.fileURL = standardizedURL
        self.readAccessURL = standardizedURL.deletingLastPathComponent()
        self.securityScopeAccessGranted = securityScopeAccessGranted
        self.title = standardizedURL.deletingPathExtension().lastPathComponent
    }

    var displayName: String {
        fileURL.lastPathComponent
    }

    var subtitle: String {
        fileURL.deletingLastPathComponent().path
    }

    deinit {
        if securityScopeAccessGranted {
            fileURL.stopAccessingSecurityScopedResource()
        }
    }
}

extension HTMLTab: Equatable {
    nonisolated static func == (lhs: HTMLTab, rhs: HTMLTab) -> Bool {
        lhs.id == rhs.id
    }
}

