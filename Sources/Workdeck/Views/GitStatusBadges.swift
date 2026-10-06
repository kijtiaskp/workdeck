import SwiftUI

struct GitStatusBadges: View {
    let status: GitStatus

    var body: some View {
        HStack(spacing: 6) {
            if status.aheadCount > 0 {
                Label("\(status.aheadCount)", systemImage: "arrow.up")
            }
            if status.behindCount > 0 {
                Label("\(status.behindCount)", systemImage: "arrow.down")
            }
            if status.isClean {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("\(status.changedFileCount)", systemImage: "pencil")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
    }
}

struct RemoteLinkButton: View {
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Open \(url.host() ?? "remote") repository")
    }
}
