import Foundation

struct TailscaleServeEntry: Hashable {
    let url: URL
    let targetPort: Int
}

enum TailscaleServe {
    private static let executableCandidates = [
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
    ]

    static func entries() async -> [TailscaleServeEntry] {
        guard let executablePath = executableCandidates.first(where: FileManager.default.isExecutableFile(atPath:)),
              let output = await ProcessRunner.output(of: URL(fileURLWithPath: executablePath), arguments: ["serve", "status", "--json"]),
              let data = output.data(using: .utf8)
        else { return [] }
        return entries(fromStatusJSON: data)
    }

    private static func entries(fromStatusJSON data: Data) -> [TailscaleServeEntry] {
        struct Status: Decodable {
            struct Site: Decodable {
                struct Handler: Decodable {
                    let proxy: String?

                    enum CodingKeys: String, CodingKey { case proxy = "Proxy" }
                }

                let handlers: [String: Handler]?

                enum CodingKeys: String, CodingKey { case handlers = "Handlers" }
            }

            let web: [String: Site]?

            enum CodingKeys: String, CodingKey { case web = "Web" }
        }

        guard let status = try? JSONDecoder().decode(Status.self, from: data) else { return [] }
        return (status.web ?? [:])
            .compactMap { hostAndPort, site in
                guard let proxy = site.handlers?["/"]?.proxy,
                      let targetPort = URLComponents(string: proxy)?.port,
                      let url = publicURL(forHostAndPort: hostAndPort)
                else { return nil }
                return TailscaleServeEntry(url: url, targetPort: targetPort)
            }
            .sorted { $0.url.absoluteString < $1.url.absoluteString }
    }

    private static func publicURL(forHostAndPort hostAndPort: String) -> URL? {
        guard let separatorIndex = hostAndPort.lastIndex(of: ":"),
              let port = Int(hostAndPort[hostAndPort.index(after: separatorIndex)...])
        else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = String(hostAndPort[..<separatorIndex])
        if port != 443 {
            components.port = port
        }
        components.path = "/"
        return components.url
    }
}
