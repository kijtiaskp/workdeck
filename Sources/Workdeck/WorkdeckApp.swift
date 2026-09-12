import SwiftUI

@main
struct WorkdeckApp: App {
    var body: some Scene {
        MenuBarExtra {
            LauncherView()
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private static let menuBarIcon: NSImage = {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: "Workspaces")!
        image.isTemplate = true
        return image
    }()
}
