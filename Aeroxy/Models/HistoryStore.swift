import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []

    private let userDefaults: UserDefaults
    private let storageKey = "dev.yixuanguo.Aeroxy.history.v1"
    private let maximumItems = 60

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func remember(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        let bookmarkData = try? standardizedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        items.removeAll { $0.path == standardizedURL.path }
        items.insert(
            HistoryItem(
                id: UUID(),
                displayName: standardizedURL.lastPathComponent,
                path: standardizedURL.path,
                bookmarkData: bookmarkData,
                lastOpenedAt: Date()
            ),
            at: 0
        )

        if items.count > maximumItems {
            items.removeLast(items.count - maximumItems)
        }

        save()
    }

    func resolve(_ item: HistoryItem) throws -> ResolvedHistoryFile {
        if let bookmarkData = item.bookmarkData {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let accessGranted = resolvedURL.startAccessingSecurityScopedResource()

            if isStale {
                remember(resolvedURL)
            }

            return ResolvedHistoryFile(
                url: resolvedURL.standardizedFileURL,
                securityScopeAccessGranted: accessGranted
            )
        }

        let fallbackURL = item.fileURL.standardizedFileURL
        return ResolvedHistoryFile(
            url: fallbackURL,
            securityScopeAccessGranted: fallbackURL.startAccessingSecurityScopedResource()
        )
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            userDefaults.removeObject(forKey: storageKey)
        }
    }
}

