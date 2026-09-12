import Foundation

struct GitRepository: Identifiable, Hashable {
    let name: String
    let group: String
    let url: URL

    var id: URL { url }

    var searchText: String { "\(group)/\(name)".lowercased() }
}
