import AppKit

enum MenuBarLabelRenderer {
    private static let iconSide: CGFloat = 18
    private static let iconTextSpacing: CGFloat = 4
    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.menuBarFont(ofSize: 0),
        .foregroundColor: NSColor.black,
    ]

    private static let icon: NSImage = NSImage(named: "MenuBarIcon")
        ?? NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: "Workspaces")!

    static func image(style: MenuBarLabelStyle, projectName: String?, nameLength: MenuBarNameLength) -> NSImage {
        let name = style.showsText ? projectName.map { shortened($0, to: nameLength) } : nil
        let showsIcon = style != .text || name == nil
        let textSize = name?.size(withAttributes: textAttributes) ?? .zero
        let iconWidth = showsIcon ? iconSide : 0
        let spacing = showsIcon && name != nil ? iconTextSpacing : 0
        let height = NSStatusBar.system.thickness
        let size = NSSize(width: ceil(iconWidth + spacing + textSize.width), height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            if showsIcon {
                icon.draw(in: NSRect(x: 0, y: (height - iconSide) / 2, width: iconSide, height: iconSide))
            }
            name?.draw(at: NSPoint(x: iconWidth + spacing, y: (height - textSize.height) / 2), withAttributes: textAttributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func shortened(_ name: String, to nameLength: MenuBarNameLength) -> String {
        guard let maximumCharacters = nameLength.maximumCharacters, name.count > maximumCharacters else { return name }
        return name.prefix(maximumCharacters - 1) + "…"
    }
}
