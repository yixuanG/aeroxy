import Foundation

private enum AeroxyCLI {
    static let version = "0.1.0"
    static let appName = "Aeroxy"
    static let appBundleIdentifier = "dev.yixuanguo.aeroxy"

    static func run() -> Int32 {
        let arguments = Array(CommandLine.arguments.dropFirst())

        if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
            printUsage()
            return arguments.isEmpty ? 64 : 0
        }

        if arguments.contains("--version") {
            print("aeroxy \(version)")
            return 0
        }

        do {
            let fileURLs = try parseFileURLs(from: arguments)
            return open(fileURLs)
        } catch {
            printError(error.localizedDescription)
            return 64
        }
    }

    private static func parseFileURLs(from arguments: [String]) throws -> [URL] {
        var paths: [String] = []
        var shouldTreatAsPath = false

        for argument in arguments {
            if shouldTreatAsPath {
                paths.append(argument)
                continue
            }

            if argument == "--" {
                shouldTreatAsPath = true
                continue
            }

            if argument.hasPrefix("-") {
                throw CLIError.unknownOption(argument)
            }

            paths.append(argument)
        }

        guard !paths.isEmpty else {
            throw CLIError.noInput
        }

        return try paths.map(resolveFileURL)
    }

    private static func resolveFileURL(_ path: String) throws -> URL {
        let url: URL

        if path.hasPrefix("file://") {
            guard let fileURL = URL(string: path), fileURL.isFileURL else {
                throw CLIError.invalidFileURL(path)
            }

            url = fileURL
        } else if path.contains("://") {
            throw CLIError.networkURL(path)
        } else if path.hasPrefix("/") || path.hasPrefix("~") {
            url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        } else {
            let currentDirectory = URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath,
                isDirectory: true
            )
            url = URL(fileURLWithPath: path, relativeTo: currentDirectory)
        }

        let standardizedURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory) else {
            throw CLIError.fileDoesNotExist(standardizedURL.path)
        }

        guard !isDirectory.boolValue else {
            throw CLIError.directory(standardizedURL.path)
        }

        guard isHTMLFile(standardizedURL) else {
            throw CLIError.unsupportedFileType(standardizedURL.path)
        }

        return standardizedURL
    }

    private static func isHTMLFile(_ url: URL) -> Bool {
        ["html", "htm", "xhtml"].contains(url.pathExtension.lowercased())
    }

    private static func open(_ fileURLs: [URL]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")

        if let appURL = locateAppURL() {
            process.arguments = ["-a", appURL.path] + fileURLs.map(\.path)
        } else {
            process.arguments = ["-b", appBundleIdentifier] + fileURLs.map(\.path)
        }

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            printError("Could not open \(appName): \(error.localizedDescription)")
            return 69
        }
    }

    private static func locateAppURL() -> URL? {
        if let explicitPath = ProcessInfo.processInfo.environment["AEROXY_APP_PATH"] {
            let explicitURL = URL(fileURLWithPath: (explicitPath as NSString).expandingTildeInPath)

            if isApplicationBundle(explicitURL) {
                return explicitURL
            }
        }

        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        var directory = executableURL.deletingLastPathComponent()

        while directory.path != "/" {
            if isApplicationBundle(directory) {
                return directory
            }

            let siblingAppURL = directory.appendingPathComponent("\(appName).app")

            if isApplicationBundle(siblingAppURL) {
                return siblingAppURL
            }

            directory.deleteLastPathComponent()
        }

        return nil
    }

    private static func isApplicationBundle(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false

        return url.pathExtension == "app"
            && FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func printUsage() {
        print(
            """
            Usage: aeroxy [--version] <report.html> [report.html ...]

            Opens local HTML reports in Aeroxy. If Aeroxy is already running, the
            existing window is brought forward and each new report opens as a tab.
            """
        )
    }

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data("aeroxy: \(message)\n".utf8))
    }
}

private enum CLIError: LocalizedError {
    case directory(String)
    case fileDoesNotExist(String)
    case invalidFileURL(String)
    case networkURL(String)
    case noInput
    case unknownOption(String)
    case unsupportedFileType(String)

    var errorDescription: String? {
        switch self {
        case let .directory(path):
            "'\(path)' is a directory. Pass an HTML file."
        case let .fileDoesNotExist(path):
            "'\(path)' does not exist."
        case let .invalidFileURL(path):
            "'\(path)' is not a valid file URL."
        case let .networkURL(url):
            "'\(url)' is not a local file. Aeroxy opens local HTML reports."
        case .noInput:
            "Pass at least one local HTML file."
        case let .unknownOption(option):
            "Unknown option '\(option)'. Use --help for usage."
        case let .unsupportedFileType(path):
            "'\(path)' is not an HTML file. Supported extensions: .html, .htm, .xhtml."
        }
    }
}

exit(AeroxyCLI.run())
