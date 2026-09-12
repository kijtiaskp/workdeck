import Foundation

enum MenuBarNameLength: String, CaseIterable, Identifiable {
    case full
    case long
    case medium
    case short

    static let defaultsKey = "MenuBarNameLength"

    var id: Self { self }

    var maximumCharacters: Int? {
        switch self {
        case .full: nil
        case .long: 24
        case .medium: 16
        case .short: 12
        }
    }

    var title: String {
        maximumCharacters.map { "\($0) Characters" } ?? "Full Name"
    }
}
