import AppKit
import CoreServices
import Foundation

enum URLPolicy {
    private static let aeroxyBundleIdentifier = "dev.yixuanguo.aeroxy"

    static func isExternalMainFrameURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        switch scheme {
        case "file", "about", "data", "blob":
            return false
        default:
            return true
        }
    }

    static func isOpenableLocalHTML(_ url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        let fileExtension = url.pathExtension.lowercased()
        return ["html", "htm", "xhtml"].contains(fileExtension)
    }

    static func mimeType(forLocalHTML url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "xhtml":
            return "application/xhtml+xml"
        default:
            return "text/html"
        }
    }

    static func localHTMLFileURL(fromPathText text: String) -> URL? {
        pathCandidates(from: text).compactMap(resolveLocalHTMLFileURL).first
    }

    static func openExternalURL(_ url: URL) {
        guard !wouldReopenAeroxy(url) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static func wouldReopenAeroxy(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            return false
        }

        let handler = LSCopyDefaultHandlerForURLScheme(scheme as CFString)?
            .takeRetainedValue() as String?
        return handler == Bundle.main.bundleIdentifier || handler == aeroxyBundleIdentifier
    }

    private static func pathCandidates(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        var candidates = [trimmed]
        candidates.append(contentsOf: trimmed.components(separatedBy: .newlines))

        if let fileRange = trimmed.range(of: "file://") {
            candidates.append(String(trimmed[fileRange.lowerBound...]))
        }

        return candidates
    }

    private static func resolveLocalHTMLFileURL(_ candidate: String) -> URL? {
        let stripped = candidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .replacingOccurrences(of: "\\ ", with: " ")

        guard !stripped.isEmpty else {
            return nil
        }

        let url: URL
        if stripped.lowercased().hasPrefix("file://") {
            guard let fileURL = URL(string: stripped), fileURL.isFileURL else {
                return nil
            }
            url = fileURL
        } else {
            let expandedPath = ((stripped.removingPercentEncoding ?? stripped) as NSString).expandingTildeInPath
            url = URL(fileURLWithPath: expandedPath)
        }

        let standardizedURL = url.standardizedFileURL
        guard isOpenableLocalHTML(standardizedURL),
              FileManager.default.fileExists(atPath: standardizedURL.path)
        else {
            return nil
        }

        return standardizedURL
    }
}
