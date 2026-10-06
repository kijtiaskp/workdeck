import SwiftUI

struct ProjectRow<Details: View>: View {
    let project: Project
    let gitStatus: GitStatus?
    let remoteURL: URL?
    let runningAppCount: Int
    let hasDetails: Bool
    @Binding var isExpanded: Bool
    @ViewBuilder let details: Details

    private var iconName: String {
        switch project.workspace.kind {
        case .workspaceFile: "square.stack.3d.up"
        case .folder: "folder"
        }
    }

    private var subtitle: String {
        if project.repository != nil {
            return gitStatus?.branch ?? " "
        }
        return (project.url.path as NSString).abbreviatingWithTildeInPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                expandButton
                Image(systemName: iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(project.repository == nil ? .caption : .caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 0)
                if runningAppCount > 0 {
                    Label("\(runningAppCount)", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .help("\(runningAppCount) running")
                }
                if project.repository != nil {
                    if let gitStatus {
                        GitStatusBadges(status: gitStatus)
                    } else {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                if let remoteURL {
                    RemoteLinkButton(url: remoteURL)
                }
            }
            .contentShape(Rectangle())

            if hasDetails && isExpanded {
                details
            }
        }
    }

    @ViewBuilder
    private var expandButton: some View {
        if hasDetails {
            Button {
                withAnimation(.snappy(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Hide environments" : "Show environments")
        } else {
            Color.clear.frame(width: 10, height: 1)
        }
    }
}
