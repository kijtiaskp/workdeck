import Foundation

struct EnvironmentLinks: Identifiable, Hashable {
    struct Link: Identifiable, Hashable {
        let label: String
        let url: URL

        var id: String { label }
    }

    let environment: String
    let links: [Link]

    var id: String { environment }
}
