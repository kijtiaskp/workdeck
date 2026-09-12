import SwiftUI

struct MenuBarLabel: View {
    let style: MenuBarLabelStyle
    let projectName: String?
    let nameLength: MenuBarNameLength

    var body: some View {
        Image(nsImage: MenuBarLabelRenderer.image(style: style, projectName: projectName, nameLength: nameLength))
    }
}
