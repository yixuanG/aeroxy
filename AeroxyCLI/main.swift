import Foundation

private enum AeroxyCLI {
    static let version = "0.1.2"
    static let appName = "Aeroxy"
    static let appBundleIdentifier = "dev.yixuanguo.aeroxy"

    static func run() -> Int32 {
        var arguments = Array(CommandLine.arguments.dropFirst())
        let wantsJSON = arguments.contains("--json")
        arguments.removeAll { $0 == "--json" }

        if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
            printUsage()
            return arguments.isEmpty ? 64 : 0
        }

        if arguments.first == "doctor" {
            guard arguments.count == 1 else {
                printError("doctor does not accept arguments.", asJSON: wantsJSON)
                return 64
            }

            printDoctor(asJSON: wantsJSON)
            return 0
        }

        if arguments.contains("--version") {
            if wantsJSON {
                printJSON([
                    "ok": true,
                    "version": version
                ])
            } else {
                print("aeroxy \(version)")
            }

            return 0
        }

        do {
            let fileURLs = try parseFileURLs(from: arguments)
            return open(fileURLs, asJSON: wantsJSON)
        } catch {
            printError(error.localizedDescription, asJSON: wantsJSON)
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

    private static func open(_ fileURLs: [URL], asJSON: Bool) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        let appURL = locateAppURL()

        if let appURL {
            process.arguments = ["-a", appURL.path] + fileURLs.map(\.path)
        } else {
            process.arguments = ["-b", appBundleIdentifier] + fileURLs.map(\.path)
        }

        do {
            try process.run()
            process.waitUntilExit()

            if asJSON {
                if process.terminationStatus == 0 {
                    printJSON([
                        "ok": true,
                        "opened": fileURLs.map(\.path),
                        "appPath": appURL?.path as Any? ?? NSNull(),
                        "bundleIdentifier": appBundleIdentifier
                    ])
                } else {
                    printJSON([
                        "ok": false,
                        "error": "/usr/bin/open exited with status \(process.terminationStatus)"
                    ])
                }
            }

            return process.terminationStatus
        } catch {
            printError("Could not open \(appName): \(error.localizedDescription)", asJSON: asJSON)
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

    private static func printDoctor(asJSON: Bool) {
        let appURL = locateAppURL()
        let commandPath = findCommandOnPath("aeroxy")
        let openPath = "/usr/bin/open"
        let canRunOpen = FileManager.default.isExecutableFile(atPath: openPath)
        let payload: [String: Any] = [
            "ok": canRunOpen,
            "version": version,
            "commandPath": commandPath as Any? ?? NSNull(),
            "appPath": appURL?.path as Any? ?? NSNull(),
            "bundleIdentifier": appBundleIdentifier,
            "openToolPath": openPath,
            "canRunOpenTool": canRunOpen,
            "supportsNetworkURLs": false,
            "supportedExtensions": ["html", "htm", "xhtml"]
        ]

        if asJSON {
            printJSON(payload)
            return
        }

        print(
            """
            Aeroxy CLI \(version)
            command: \(commandPath ?? "not on PATH")
            app: \(appURL?.path ?? "\(appBundleIdentifier) through LaunchServices")
            open tool: \(canRunOpen ? openPath : "missing")
            supported files: .html, .htm, .xhtml
            network URLs: default browser only
            """
        )
    }

    private static func findCommandOnPath(_ name: String) -> String? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""

        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory))
                .appendingPathComponent(name)

            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
        }

        return nil
    }

    private static func printUsage() {
        print(
            """
            Usage:
              aeroxy [--json] <report.html> [report.html ...]
              aeroxy [--json] doctor
              aeroxy [--json] --version

            Opens local HTML reports in Aeroxy. If Aeroxy is already running, the
            existing window is brought forward and each new report opens as a tab.
            """
        )
    }

    private static func printError(_ message: String, asJSON: Bool = false) {
        if asJSON {
            printJSON([
                "ok": false,
                "error": message
            ])
            return
        }

        FileHandle.standardError.write(Data("aeroxy: \(message)\n".utf8))
    }

    private static func printJSON(_ payload: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("aeroxy: Could not encode JSON output.\n".utf8))
        }
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
