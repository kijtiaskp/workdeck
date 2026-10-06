import AppKit

enum PortlessAppController {
    private static let logDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/Workdeck", isDirectory: true)

    private static let lockfilePackageManagers = [
        ("bun.lock", "bun"), ("bun.lockb", "bun"), ("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"), ("package-lock.json", "npm"),
    ]
    private static let lockfileSearchDepth = 4

    static func start(_ app: LocalApp) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
        process.arguments = ["-lc", shellCommand(for: app)]
        process.currentDirectoryURL = app.directory
        process.standardInput = FileHandle.nullDevice

        let logHandle = try openLog(forAppNamed: app.name)
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()
        return process
    }

    static func stop(processID: Int32) async {
        for descendant in await ProcessTree.withDescendants([processID]).reversed() {
            kill(descendant, SIGTERM)
        }
    }

    static func logURL(forAppNamed name: String) -> URL {
        logDirectory.appendingPathComponent("\(name).log")
    }

    static func hasLog(forAppNamed name: String) -> Bool {
        FileManager.default.fileExists(atPath: logURL(forAppNamed: name).path)
    }

    static func showLog(forAppNamed name: String) {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        guard let scriptURL = try? writeTailScript(forAppNamed: name) else { return }
        NSWorkspace.shared.open([scriptURL], withApplicationAt: terminalURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private static func writeTailScript(forAppNamed name: String) throws -> URL {
        let scriptURL = logDirectory.appendingPathComponent("\(name).command")
        let script = "#!/bin/sh\nexec tail -n 200 -f \(shellQuoted(logURL(forAppNamed: name).path))\n"
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    private static func shellCommand(for app: LocalApp) -> String {
        switch app.launchCommand {
        case .portless: "exec portless"
        case .packageScript(let scriptName):
            "exec \(packageManager(for: app.directory)) run \(shellQuoted(scriptName))"
        case .packageScriptOnPort(let scriptName, let port):
            scriptCommand(scriptName, packageManager: packageManager(for: app.directory), extraArguments: "--port \(port) --strictPort")
        }
    }

    private static func scriptCommand(_ scriptName: String, packageManager: String, extraArguments: String) -> String {
        let separator = packageManager == "npm" ? " --" : ""
        return "exec \(packageManager) run \(shellQuoted(scriptName))\(separator) \(extraArguments)"
    }

    static func freePort(_ port: Int) async {
        for processID in await ProcessTree.listeningProcessIDs(on: port) {
            await stop(processID: processID)
        }
        for _ in 0..<20 where !(await ProcessTree.listeningProcessIDs(on: port)).isEmpty {
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private static func packageManager(for directory: URL) -> String {
        var candidate = directory.standardizedFileURL
        for _ in 0...lockfileSearchDepth {
            let lockfileMatch = lockfilePackageManagers.first { lockfile, _ in
                FileManager.default.fileExists(atPath: candidate.appendingPathComponent(lockfile).path)
            }
            if let (_, packageManager) = lockfileMatch { return packageManager }

            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else { break }
            candidate = parent
        }
        return "npm"
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func openLog(forAppNamed name: String) throws -> FileHandle {
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let url = logURL(forAppNamed: name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try FileHandle(forWritingTo: url)
    }
}
