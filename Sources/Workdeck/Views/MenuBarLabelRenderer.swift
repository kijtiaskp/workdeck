import AppKit

enum MenuBarLabelRenderer {
    private static let maximumNameLength = 12
    private static let iconSide: CGFloat = 18
    private static let iconTextSpacing: CGFloat = 4
    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.menuBarFont(ofSize: 0),
        .foregroundColor: NSColor.black,
    ]

    private static let icon: NSImage = NSImage(named: "MenuBarIcon")
        ?? NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: "Workspaces")!

    static func image(style: MenuBarLabelStyle, projectName: String?, knownNames: Set<String>) -> NSImage {
        let name = style.showsText ? projectName.map(truncated) : nil
        let showsIcon = style != .text || name == nil
        let textWidth = name.map { reservedTextWidth(for: knownNames.map(truncated) + [$0]) } ?? 0
        let iconWidth = showsIcon ? iconSide : 0
        let spacing = showsIcon && name != nil ? iconTextSpacing : 0
        let height = NSStatusBar.system.thickness
        let size = NSSize(width: ceil(iconWidth + spacing + textWidth), height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            if showsIcon {
                icon.draw(in: NSRect(x: 0, y: (height - iconSide) / 2, width: iconSide, height: iconSide))
            }
            if let name {
                let textHeight = name.size(withAttributes: textAttributes).height
                name.draw(at: NSPoint(x: iconWidth + spacing, y: (height - textHeight) / 2), withAttributes: textAttributes)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func truncated(_ name: String) -> String {
        guard name.count > maximumNameLength else { return name }
        return name.prefix(maximumNameLength - 1) + "…"
    }

    private static func reservedTextWidth(for names: [String]) -> CGFloat {
        ceil(names.map { $0.size(withAttributes: textAttributes).width }.max() ?? 0)
    }
}
