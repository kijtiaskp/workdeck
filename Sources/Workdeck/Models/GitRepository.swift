import Foundation

struct GitRepository: Identifiable, Hashable {
    let name: String
    let group: String
    let root: URL
    let url: URL

    var id: URL { url }

    var searchText: String { "\(root.lastPathComponent)/\(group)/\(name)".lowercased() }
}
