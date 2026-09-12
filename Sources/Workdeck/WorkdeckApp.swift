import SwiftUI

@main
struct WorkdeckApp: App {
    @AppStorage(MenuBarLabelStyle.defaultsKey) private var labelStyle: MenuBarLabelStyle = .icon
    @StateObject private var windowTracker = VSCodeWindowTracker()

    var body: some Scene {
        MenuBarExtra {
            LauncherView()
        } label: {
            MenuBarLabel(style: labelStyle, projectName: windowTracker.activeProjectName)
        }
        .menuBarExtraStyle(.window)
    }
}
