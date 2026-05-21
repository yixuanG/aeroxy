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
}
