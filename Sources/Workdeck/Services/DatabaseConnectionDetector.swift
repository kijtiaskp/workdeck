import Foundation

enum DatabaseConnectionDetector {
    private struct Endpoint: Hashable {
        let host: String
        let port: Int
    }

    private struct ConfiguredHost {
        let host: String
        let environment: String
    }

    private static let lsofExecutableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    private static let databasePorts: Set<Int> = [1433, 3306, 5432, 6379, 26257, 27017]
    private static let databaseURLSchemes: Set<String> = [
        "postgres", "postgresql", "mysql", "mariadb", "mongodb", "mongodb+srv", "redis", "rediss", "sqlserver",
    ]
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]
    private static let ignoredEnvFileSuffixes: Set<String> = ["example", "sample", "template"]
    private static let hostKeywordEnvironments = [("prod", "prod"), ("staging", "staging"), ("stg", "staging"), ("uat", "uat"), ("dev", "dev")]

    static func connection(
        ofServerListeningOn port: Int,
        projectDirectory: URL,
        environmentLinks: [EnvironmentLinks]
    ) async -> DatabaseConnection? {
        let serverProcessIDs = await listeningProcessIDs(on: port)
        guard !serverProcessIDs.isEmpty else { return nil }

        let processIDs = await ProcessTree.withDescendants(serverProcessIDs)
        guard let endpoint = await databaseEndpoints(of: processIDs).first else { return nil }

        return classify(endpoint, environmentLinks: environmentLinks, configuredHosts: configuredHosts(in: projectDirectory))
    }

    private static func listeningProcessIDs(on port: Int) async -> [Int32] {
        let arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        guard let output = await ProcessRunner.output(of: lsofExecutableURL, arguments: arguments) else { return [] }
        return output.split(whereSeparator: \.isNewline).compactMap { Int32($0) }
    }

    private static func databaseEndpoints(of processIDs: [Int32]) async -> [Endpoint] {
        let processList = processIDs.map(String.init).joined(separator: ",")
        let arguments = ["-nP", "-a", "-p", processList, "-iTCP", "-sTCP:ESTABLISHED", "-Fn"]
        guard let output = await ProcessRunner.output(of: lsofExecutableURL, arguments: arguments) else { return [] }

        let endpoints = output
            .split(whereSeparator: \.isNewline)
            .filter { $0.hasPrefix("n") }
            .compactMap { line in line.components(separatedBy: "->").last.flatMap(endpoint(from:)) }
            .filter { databasePorts.contains($0.port) }
        return Array(Set(endpoints))
    }

    private static func endpoint(from address: String) -> Endpoint? {
        guard let separatorIndex = address.lastIndex(of: ":"),
              let port = Int(address[address.index(after: separatorIndex)...])
        else { return nil }
        let host = address[..<separatorIndex].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return Endpoint(host: host, port: port)
    }

    private static func classify(
        _ endpoint: Endpoint,
        environmentLinks: [EnvironmentLinks],
        configuredHosts: [ConfiguredHost]
    ) -> DatabaseConnection {
        if loopbackHosts.contains(endpoint.host) {
            return DatabaseConnection(environment: "local", host: "localhost:\(endpoint.port)")
        }

        if let linkedEnvironment = environment(servedAt: endpoint.host, in: environmentLinks) {
            return DatabaseConnection(environment: linkedEnvironment, host: "\(endpoint.host):\(endpoint.port)")
        }

        let match = configuredHosts.first { configured in
            !loopbackHosts.contains(configured.host) && resolveAddresses(of: configured.host).contains(endpoint.host)
        }
        guard let match else {
            return DatabaseConnection(environment: "unknown", host: "\(endpoint.host):\(endpoint.port)")
        }
        return DatabaseConnection(environment: environment(ofHost: match.host) ?? match.environment, host: match.host)
    }

    private static func environment(servedAt address: String, in environmentLinks: [EnvironmentLinks]) -> String? {
        environmentLinks.first { environment in
            environment.links.contains { link in
                guard let host = link.url.host() else { return false }
                return host == address || resolveAddresses(of: host).contains(address)
            }
        }?.environment
    }

    private static func environment(ofHost host: String) -> String? {
        let lowercasedHost = host.lowercased()
        return hostKeywordEnvironments.first { lowercasedHost.contains($0.0) }?.1
    }

    private static func configuredHosts(in directory: URL) -> [ConfiguredHost] {
        DirectoryScanning.contents(of: directory)
            .compactMap { file -> (URL, String)? in
                guard let environment = environment(ofEnvFile: file.lastPathComponent) else { return nil }
                return (file, environment)
            }
            .flatMap { file, environment in
                databaseHosts(inEnvFile: file).map { ConfiguredHost(host: $0, environment: environment) }
            }
    }

    private static func environment(ofEnvFile fileName: String) -> String? {
        if fileName == ".env" { return "default" }
        guard fileName.hasPrefix(".env.") else { return nil }
        let suffix = String(fileName.dropFirst(".env.".count))
        return ignoredEnvFileSuffixes.contains(suffix) ? nil : suffix
    }

    private static func databaseHosts(inEnvFile file: URL) -> [String] {
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return contents.split(whereSeparator: \.isNewline).compactMap { line in
            guard let separatorIndex = line.firstIndex(of: "=") else { return nil }
            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            guard !key.hasPrefix("#"), !value.isEmpty else { return nil }
            return isDatabaseHostKey(key) ? value : host(inDatabaseURL: value)
        }
    }

    private static func isDatabaseHostKey(_ key: String) -> Bool {
        let uppercasedKey = key.uppercased()
        return uppercasedKey.hasSuffix("_HOST") && (uppercasedKey.contains("DB") || uppercasedKey.contains("DATABASE"))
    }

    private static func host(inDatabaseURL value: String) -> String? {
        guard let schemeRange = value.range(of: "://"),
              databaseURLSchemes.contains(value[..<schemeRange.lowerBound].lowercased())
        else { return nil }

        let authority = value[schemeRange.upperBound...].prefix { !"/?".contains($0) }
        let hostAndPort = authority.split(separator: "@").last.map(String.init) ?? String(authority)
        let firstHost = hostAndPort.split(separator: ",").first.map(String.init) ?? hostAndPort
        let host = firstHost.split(separator: ":").first.map(String.init) ?? firstHost
        return host.isEmpty ? nil : host
    }

    private static func resolveAddresses(of host: String) -> Set<String> {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: 0,
                             ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var resultPointer: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &resultPointer) == 0, let firstResult = resultPointer else { return [] }
        defer { freeaddrinfo(firstResult) }

        var addresses: Set<String> = []
        var current: UnsafeMutablePointer<addrinfo>? = firstResult
        while let info = current?.pointee {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(info.ai_addr, info.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                addresses.insert(String(cString: buffer))
            }
            current = info.ai_next
        }
        return addresses
    }
}
