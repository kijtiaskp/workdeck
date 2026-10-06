import Foundation

enum ProjectLinksFile {
    static let fileName = ".workdeck.json"

    private static let environmentOrder = ["prod", "production", "pre-prod", "staging", "uat", "dev", "development"]
    private static let template = """
    {
      "environments": {
        "prod": {
          "Web": "https://example.com",
          "API": "https://api.example.com"
        },
        "dev": {
          "Web": "https://dev.example.com",
          "API": "https://api.dev.example.com"
        }
      }
    }

    """

    static func url(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func load(from directory: URL) -> [EnvironmentLinks]? {
        struct Definition: Decodable {
            let environments: [String: [String: String]]
        }

        guard let data = try? Data(contentsOf: url(in: directory)) else { return nil }
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        guard let definition = try? decoder.decode(Definition.self, from: data) else { return nil }

        return definition.environments
            .map { environment, links in
                EnvironmentLinks(
                    environment: environment,
                    links: links
                        .compactMap { label, value in URL(string: value).map { EnvironmentLinks.Link(label: label, url: $0) } }
                        .sorted { $0.label.lowercased() < $1.label.lowercased() }
                )
            }
            .sorted { sortKey(of: $0.environment) < sortKey(of: $1.environment) }
    }

    struct TailnetConfig: Decodable {
        struct App: Decodable {
            let folder: String
            let path: String?
            let script: String?
        }

        let port: Int
        let apps: [String: App]
    }

    static func tailnetConfig(from directory: URL) -> TailnetConfig? {
        struct Definition: Decodable {
            let tailnet: TailnetConfig?
        }

        guard let data = try? Data(contentsOf: url(in: directory)) else { return nil }
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return (try? decoder.decode(Definition.self, from: data))?.tailnet
    }

    static func createIfMissing(in directory: URL) -> URL {
        let fileURL = url(in: directory)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? template.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return fileURL
    }

    private static func sortKey(of environment: String) -> (Int, String) {
        let name = environment.lowercased()
        return (environmentOrder.firstIndex(of: name) ?? environmentOrder.count, name)
    }
}
