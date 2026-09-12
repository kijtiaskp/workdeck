import Foundation

struct Workspace: Identifiable, Hashable {
    enum Kind {
        case workspaceFile
        case folder
    }

    let name: String
    let group: String
    let root: URL
    let url: URL
    let kind: Kind

    var id: URL { url }

    var searchText: String { "\(root.lastPathComponent)/\(group)/\(name)".lowercased() }
}
