import Foundation

struct PortlessApp: Hashable {
    enum LaunchCommand: Hashable {
        case portless
        case packageScript(String)
    }

    let name: String
    let directory: URL
    let launchCommand: LaunchCommand
}

enum PortlessAppScanner {
    private static let subcommands: Set<String> = [
        "run", "get", "list", "proxy", "alias", "service", "trust", "clean", "hosts", "share", "help", "version",
    ]

    static func apps(in directories: [URL], maxDepth: Int = 2) -> [PortlessApp] {
        var apps: [PortlessApp] = []
        var visitedPaths: Set<String> = []
        for directory in directories {
            scan(directory, depth: 0, maxDepth: maxDepth, apps: &apps, visitedPaths: &visitedPaths)
        }
        return apps
    }

    private static func scan(_ directory: URL, depth: Int, maxDepth: Int, apps: inout [PortlessApp], visitedPaths: inout Set<String>) {
        guard visitedPaths.insert(directory.path).inserted else { return }

        if let app = app(in: directory) {
            apps.append(app)
        }

        guard depth < maxDepth else { return }
        for subdirectory in DirectoryScanning.contents(of: directory) where DirectoryScanning.isScannableDirectory(subdirectory) {
            scan(subdirectory, depth: depth + 1, maxDepth: maxDepth, apps: &apps, visitedPaths: &visitedPaths)
        }
    }

    private static func app(in directory: URL) -> PortlessApp? {
        if let name = nameFromConfigFile(in: directory) {
            return PortlessApp(name: name, directory: directory, launchCommand: .portless)
        }
        if let (name, scriptName) = nameFromPackageScripts(in: directory) {
            return PortlessApp(name: name, directory: directory, launchCommand: .packageScript(scriptName))
        }
        return nil
    }

    private static func nameFromConfigFile(in directory: URL) -> String? {
        struct Config: Decodable { let name: String? }

        guard let data = try? Data(contentsOf: directory.appendingPathComponent("portless.json")),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return nil }
        return config.name
    }

    private static func nameFromPackageScripts(in directory: URL) -> (name: String, scriptName: String)? {
        struct Package: Decodable {
            let name: String?
            let scripts: [String: String]?
        }

        guard let data = try? Data(contentsOf: directory.appendingPathComponent("package.json")),
              let package = try? JSONDecoder().decode(Package.self, from: data)
        else { return nil }

        let packageName = package.name.map { $0.split(separator: "/").last.map(String.init) ?? $0 }
        for (scriptName, script) in (package.scripts ?? [:]).sorted(by: { $0.key < $1.key }) {
            if let name = appName(inScript: script, packageName: packageName) {
                return (name, scriptName)
            }
        }
        return nil
    }

    private static func appName(inScript script: String, packageName: String?) -> String? {
        let tokens = script.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let portlessIndex = tokens.firstIndex(of: "portless"), portlessIndex + 1 < tokens.count else { return nil }

        let arguments = tokens[(portlessIndex + 1)...]
        guard let first = arguments.first else { return nil }

        if first == "run" {
            if let nameFlagIndex = arguments.firstIndex(of: "--name"), nameFlagIndex + 1 < arguments.endIndex {
                return arguments[nameFlagIndex + 1]
            }
            return packageName
        }
        guard !first.hasPrefix("-"), !subcommands.contains(first) else { return nil }
        return first
    }
}
