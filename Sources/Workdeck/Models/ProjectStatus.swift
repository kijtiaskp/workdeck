import Foundation

struct ProjectStatus: Hashable {
    let environments: [EnvironmentLinks]
    let apps: [AppStatus]
    let tailnetShares: [TailnetShare]
    let repositories: [EnvironmentLinks.Link]

    var isEmpty: Bool { environments.isEmpty && apps.isEmpty && tailnetShares.isEmpty }
    var runningAppCount: Int { apps.filter(\.isRunning).count }
}

struct AppStatus: Identifiable, Hashable {
    let name: String
    let url: URL?
    let database: DatabaseConnection?
    let launchableApp: LocalApp?
    let processID: Int32?

    var isRunning: Bool { processID != nil }

    var id: String { name }
}

struct TailnetShare: Identifiable, Hashable {
    let url: URL
    let appName: String
    let targetPort: Int
    let isRunning: Bool

    var id: URL { url }
}

struct DatabaseConnection: Hashable {
    let environment: String
    let host: String
}
