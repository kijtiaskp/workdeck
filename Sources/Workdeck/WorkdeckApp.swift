import SwiftUI

@main
struct WorkdeckApp: App {
    @AppStorage(MenuBarLabelStyle.defaultsKey) private var labelStyle: MenuBarLabelStyle = .icon
    @AppStorage(MenuBarNameLength.defaultsKey) private var nameLength: MenuBarNameLength = .full
    @StateObject private var windowTracker = VSCodeWindowTracker()

    var body: some Scene {
        MenuBarExtra {
            LauncherView()
        } label: {
            MenuBarLabel(style: labelStyle, projectName: windowTracker.activeProjectName, nameLength: nameLength)
        }
        .menuBarExtraStyle(.window)
    }
}
