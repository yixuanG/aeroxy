import Foundation

enum URLPolicy {
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
}

