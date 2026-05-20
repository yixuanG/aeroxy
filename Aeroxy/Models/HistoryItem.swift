import Foundation

struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var path: String
    var bookmarkData: Data?
    var lastOpenedAt: Date

    var fileURL: URL {
        URL(fileURLWithPath: path)
    }
}

struct ResolvedHistoryFile {
    let url: URL
    let securityScopeAccessGranted: Bool
}

