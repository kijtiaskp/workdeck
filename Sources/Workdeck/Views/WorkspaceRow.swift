import SwiftUI

struct WorkspaceRow: View {
    let workspace: Workspace

    private var iconName: String {
        switch workspace.kind {
        case .workspaceFile: "square.stack.3d.up"
        case .folder: "folder"
        }
    }

    private var abbreviatedPath: String {
        (workspace.url.path as NSString).abbreviatingWithTildeInPath
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .lineLimit(1)
                Text(abbreviatedPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
