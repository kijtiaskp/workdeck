import Foundation

struct Workspace: Identifiable, Hashable {
    enum Kind {
        case workspaceFile
        case folder
    }

    let name: String
    let group: String
    let url: URL
    let kind: Kind

    var id: URL { url }

    var searchText: String { "\(group)/\(name)".lowercased() }
}
