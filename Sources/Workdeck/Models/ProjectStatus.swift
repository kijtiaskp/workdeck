import Foundation

struct ProjectStatus: Hashable {
    let environments: [EnvironmentLinks]
    let apps: [AppStatus]

    var isEmpty: Bool { environments.isEmpty && apps.isEmpty }
    var runningAppCount: Int { apps.filter(\.isRunning).count }
}

struct AppStatus: Identifiable, Hashable {
    let name: String
    let url: URL?
    let database: DatabaseConnection?
    let launchableApp: PortlessApp?
    let processID: Int32?

    var isRunning: Bool { processID != nil }

    var id: String { name }
}

struct DatabaseConnection: Hashable {
    let environment: String
    let host: String
}
