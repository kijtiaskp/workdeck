import SwiftUI

struct MenuBarLabel: View {
    let style: MenuBarLabelStyle
    let projectName: String?
    let knownNames: Set<String>

    var body: some View {
        Image(nsImage: MenuBarLabelRenderer.image(style: style, projectName: projectName, knownNames: knownNames))
    }
}
