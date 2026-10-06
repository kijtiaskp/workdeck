import Foundation

struct PortlessRoute: Decodable, Hashable {
    let hostname: String
    let port: Int
    let pid: Int32
}

struct RunningPortlessRoute: Hashable {
    let route: PortlessRoute
    let workingDirectory: URL?

    func isInside(_ directory: URL) -> Bool {
        guard let workingDirectory else { return false }
        let directoryPath = directory.standardizedFileURL.path
        return workingDirectory.path == directoryPath || workingDirectory.path.hasPrefix(directoryPath + "/")
    }
}

struct PortlessProxySettings: Hashable {
    let port: Int?
    let usesTLS: Bool
    let topLevelDomain: String

    func hostname(forAppNamed name: String) -> String {
        "\(name).\(topLevelDomain)"
    }

    func appName(forHostname hostname: String) -> String {
        let suffix = ".\(topLevelDomain)"
        return hostname.hasSuffix(suffix) ? String(hostname.dropLast(suffix.count)) : hostname
    }

    func url(forHostname hostname: String) -> URL? {
        var components = URLComponents()
        components.scheme = usesTLS ? "https" : "http"
        components.host = hostname
        if let port, port != (usesTLS ? 443 : 80) {
            components.port = port
        }
        return components.url
    }
}

struct PortlessSnapshot {
    let settings: PortlessProxySettings
    let routes: [RunningPortlessRoute]

    func routes(forAppNamed name: String) -> [RunningPortlessRoute] {
        let defaultHostname = settings.hostname(forAppNamed: name)
        let exactMatches = routes.filter { $0.route.hostname == name || $0.route.hostname == defaultHostname }
        if !exactMatches.isEmpty { return exactMatches }
        return routes.filter { $0.route.hostname.contains(".\(name).") }
    }
}

enum Portless {
    private static let userStateDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".portless")
    private static let legacyStateDirectory = URL(fileURLWithPath: "/tmp/portless")
    private static let defaultTopLevelDomain = "localhost"

    static func snapshot() async -> PortlessSnapshot {
        let stateDirectory = resolvedStateDirectory()
        let settings = proxySettings(in: stateDirectory)

        var runningRoutes: [RunningPortlessRoute] = []
        for route in routes(in: stateDirectory) where route.pid == 0 || isProcessAlive(route.pid) {
            let workingDirectory = route.pid == 0 ? nil : await ProcessTree.workingDirectory(ofProcess: route.pid)
            runningRoutes.append(RunningPortlessRoute(route: route, workingDirectory: workingDirectory))
        }
        return PortlessSnapshot(settings: settings, routes: runningRoutes)
    }

    private static func resolvedStateDirectory() -> URL {
        if let configuredPath = environmentValue("PORTLESS_STATE_DIR") {
            return URL(fileURLWithPath: (configuredPath as NSString).expandingTildeInPath)
        }
        let userProxyIsRunning = fileExists("proxy.port", in: userStateDirectory)
        let legacyProxyIsRunning = fileExists("proxy.port", in: legacyStateDirectory)
        return !userProxyIsRunning && legacyProxyIsRunning ? legacyStateDirectory : userStateDirectory
    }

    private static func routes(in stateDirectory: URL) -> [PortlessRoute] {
        struct LenientRoute: Decodable {
            let route: PortlessRoute?

            init(from decoder: Decoder) throws {
                route = try? PortlessRoute(from: decoder)
            }
        }

        guard let data = try? Data(contentsOf: stateDirectory.appendingPathComponent("routes.json")),
              let entries = try? JSONDecoder().decode([LenientRoute].self, from: data)
        else { return [] }
        return entries.compactMap(\.route)
    }

    private static func proxySettings(in stateDirectory: URL) -> PortlessProxySettings {
        let port = environmentValue("PORTLESS_PORT").flatMap(Int.init) ?? readValue("proxy.port", in: stateDirectory).flatMap(Int.init)
        let httpsDisabled = ["0", "false"].contains(environmentValue("PORTLESS_HTTPS")?.lowercased() ?? "")
        let usesTLS = fileExists("proxy.tls", in: stateDirectory) || port == 443 || (port == nil && !httpsDisabled)
        return PortlessProxySettings(port: port, usesTLS: usesTLS, topLevelDomain: topLevelDomain(in: stateDirectory))
    }

    private static func topLevelDomain(in stateDirectory: URL) -> String {
        let configured = environmentValue("PORTLESS_TLD")
            ?? readValue("proxy.tld", in: stateDirectory)
            ?? readValue("proxy.tlds", in: stateDirectory)
        let firstDomain = configured?
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .first
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")) }
        return firstDomain.flatMap { $0.isEmpty ? nil : $0 } ?? defaultTopLevelDomain
    }

    private static func environmentValue(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func readValue(_ fileName: String, in directory: URL) -> String? {
        guard let raw = try? String(contentsOf: directory.appendingPathComponent(fileName), encoding: .utf8) else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func fileExists(_ fileName: String, in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(fileName).path)
    }

    private static func isProcessAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
