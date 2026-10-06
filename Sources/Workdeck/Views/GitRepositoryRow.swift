import SwiftUI

struct GitRepositoryRow: View {
    let repository: GitRepository
    let status: GitStatus?
    let remoteURL: URL?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(repository.name)
                    .lineLimit(1)
                Text(status?.branch ?? " ")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let status {
                StatusBadges(status: status)
            } else {
                ProgressView()
                    .controlSize(.mini)
            }
            if let remoteURL {
                RemoteLinkButton(url: remoteURL)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct StatusBadges: View {
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
