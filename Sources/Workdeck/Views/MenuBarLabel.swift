import SwiftUI

struct MenuBarLabel: View {
    private static let maximumNameLength = 28

    private static let icon: NSImage = {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: "Workspaces")!
        image.isTemplate = true
        return image
    }()

    let style: MenuBarLabelStyle
    let projectName: String?

    private var visibleName: String? {
        guard style.showsText, let projectName else { return nil }
        guard projectName.count > Self.maximumNameLength else { return projectName }
        return projectName.prefix(Self.maximumNameLength - 1) + "…"
    }

    var body: some View {
        HStack(spacing: 4) {
            if style != .text || visibleName == nil {
                Image(nsImage: Self.icon)
            }
            if let visibleName {
                Text(visibleName)
                    .contentTransition(.identity)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}
