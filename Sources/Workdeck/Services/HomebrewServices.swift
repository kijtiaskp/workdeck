import Foundation

enum HomebrewServices {
    private static let brewCandidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    private static let postgresFormulaPrefix = "postgresql"
    private static let defaultPostgresPort = 5432

    private static var brewExecutableURL: URL? {
        brewCandidates.first(where: FileManager.default.isExecutableFile(atPath:)).map { URL(fileURLWithPath: $0) }
    }

    private static var homebrewPrefix: URL? {
        brewExecutableURL?.deletingLastPathComponent().deletingLastPathComponent()
    }

    static func postgresServices() async -> [DatabaseService] {
        struct ServiceEntry: Decodable {
            let name: String
            let status: String
        }

        guard let brewExecutableURL,
              let output = await ProcessRunner.output(of: brewExecutableURL, arguments: ["services", "list", "--json"]),
              let entries = try? JSONDecoder().decode([ServiceEntry].self, from: Data(output.utf8))
        else { return [] }

        var services: [DatabaseService] = []
        for entry in entries where entry.name.hasPrefix(postgresFormulaPrefix) {
            let port = postgresPort(of: entry.name)
            let state: DatabaseService.State
            if entry.status == "error" {
                state = .failed
            } else if entry.status == "started" {
                state = .running
            } else {
                state = await isServing(formula: entry.name, on: port) ? .running : .stopped
            }
            services.append(DatabaseService(formula: entry.name, port: port, state: state))
        }
        return services.sorted { $0.formula > $1.formula }
    }

    static func start(_ service: DatabaseService) async -> Bool {
        await run(["services", "start", service.formula])
    }

    static func stop(_ service: DatabaseService) async -> Bool {
        await run(["services", "stop", service.formula])
    }

    private static func run(_ arguments: [String]) async -> Bool {
        guard let brewExecutableURL else { return false }
        return await ProcessRunner.output(of: brewExecutableURL, arguments: arguments) != nil
    }

    private static func isServing(formula: String, on port: Int) async -> Bool {
        for processID in await ProcessTree.listeningProcessIDs(on: port) {
            if let path = await ProcessTree.executablePath(ofProcess: processID), path.contains(formula) {
                return true
            }
        }
        return false
    }

    private static func postgresPort(of formula: String) -> Int {
        guard let configURL = homebrewPrefix?.appendingPathComponent("var/\(formula)/postgresql.conf"),
              let contents = try? String(contentsOf: configURL, encoding: .utf8)
        else { return defaultPostgresPort }

        let portLine = contents.split(whereSeparator: \.isNewline).first { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("port")
        }
        let value = portLine?
            .split(separator: "=").dropFirst().first?
            .split(separator: "#").first?
            .trimmingCharacters(in: .whitespaces)
        return value.flatMap(Int.init) ?? defaultPostgresPort
    }
}
