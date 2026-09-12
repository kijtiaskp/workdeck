import Foundation

enum MenuBarLabelStyle: String, CaseIterable, Identifiable {
    case icon
    case text
    case iconAndText

    static let defaultsKey = "MenuBarLabelStyle"

    static var current: MenuBarLabelStyle {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(MenuBarLabelStyle.init(rawValue:)) ?? .icon
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .icon: "Icon"
        case .text: "Text"
        case .iconAndText: "Icon and Text"
        }
    }

    var showsText: Bool { self != .icon }
}
