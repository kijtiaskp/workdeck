import Foundation

struct DatabaseService: Identifiable, Hashable {
    enum State: Hashable {
        case running
        case stopped
        case failed
    }

    let formula: String
    let port: Int
    let state: State

    var id: String { formula }

    var displayName: String {
        guard let version = formula.split(separator: "@").dropFirst().first else { return "PostgreSQL" }
        return "PostgreSQL \(version)"
    }
}
