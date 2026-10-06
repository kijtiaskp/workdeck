import AppKit
import SwiftUI

struct ProjectStatusDetails: View {
    let status: ProjectStatus
    let pendingAppNames: Set<String>
    let failedAppNames: Set<String>
    let onStart: (LocalApp) -> Void
    let onStop: (AppStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(status.environments) { environment in
                EnvironmentSection(name: environment.environment) {
                    ForEach(environment.links) { link in
                        LinkButton(label: link.label, url: link.url)
                    }
                }
            }

            if !status.tailnetShares.isEmpty {
                EnvironmentSection(name: "tailnet") {
                    ForEach(status.tailnetShares) { share in
                        TailnetShareView(share: share)
                    }
                }
            }

            if !status.repositories.isEmpty {
                EnvironmentSection(name: "repo") {
                    ForEach(status.repositories) { repository in
                        LinkButton(label: repository.label, url: repository.url)
                    }
                }
            }

            if !status.apps.isEmpty {
                EnvironmentSection(name: "local") {
                    ForEach(status.apps) { app in
                        AppStatusView(
                            app: app,
                            isPending: pendingAppNames.contains(app.name),
                            hasFailed: failedAppNames.contains(app.name),
                            onStart: onStart,
                            onStop: onStop
                        )
                    }
                }
            }
        }
        .padding(.bottom, 2)
    }
}

private struct EnvironmentSection<Content: View>: View {
    let name: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            EnvironmentBadge(name: name)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                content
            }
        }
        .padding(.leading, 44)
    }
}

private struct EnvironmentBadge: View {
    let name: String

    private var color: Color {
        switch name.lowercased() {
        case "prod", "production": .red
        case "pre-prod", "staging", "uat": .orange
        case "dev", "development": .blue
        case "local": .green
        case "tailnet": .purple
        default: .secondary
        }
    }

    var body: some View {
        Text(name.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

private struct AppStatusView: View {
    let app: AppStatus
    let isPending: Bool
    let hasFailed: Bool
    let onStart: (LocalApp) -> Void
    let onStop: (AppStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                controlButton
                Circle()
                    .fill(app.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                if let url = app.url {
                    LinkButton(label: app.name, url: url)
                        .opacity(app.isRunning ? 1 : 0.5)
                } else {
                    Text(app.name)
                        .font(.caption)
                }
                if hasFailed {
                    Button { PortlessAppController.showLog(forAppNamed: app.name) } label: {
                        Label("Failed", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.borderless)
                    .help("\(app.name) did not start. Show its log.")
                } else if PortlessAppController.hasLog(forAppNamed: app.name) {
                    Button { PortlessAppController.showLog(forAppNamed: app.name) } label: {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Show \(app.name) log")
                }
            }
            .contextMenu {
                Button("Show Log") { PortlessAppController.showLog(forAppNamed: app.name) }
                    .disabled(!PortlessAppController.hasLog(forAppNamed: app.name))
            }
            if let database = app.database {
                Text("DB \(database.environment.uppercased()) · \(database.host)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 30)
                    .help(database.host)
            }
        }
    }

    @ViewBuilder
    private var controlButton: some View {
        if isPending {
            ProgressView()
                .controlSize(.mini)
                .frame(width: 16)
        } else if app.isRunning {
            Button { onStop(app) } label: {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .frame(width: 16)
            .help("Stop \(app.name)")
        } else if let launchableApp = app.launchableApp {
            Button { onStart(launchableApp) } label: {
                Image(systemName: "play.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.borderless)
            .frame(width: 16)
            .help("Run \(app.name) with portless")
        } else {
            Color.clear.frame(width: 16, height: 1)
        }
    }
}

private struct TailnetShareView: View {
    let share: TailnetShare

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Circle()
                    .fill(share.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                LinkButton(label: share.appName, url: share.url)
                    .opacity(share.isRunning ? 1 : 0.5)
            }
            if !share.isRunning {
                Text("not running")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
            }
        }
    }
}

private struct LinkButton: View {
    let label: String
    let url: URL

    private var displayText: String {
        (url.host() ?? url.absoluteString) + url.path()
    }

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .foregroundStyle(.secondary)
                Text(displayText)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.caption)
        }
        .buttonStyle(.plain)
        .help(url.absoluteString)
        .contextMenu {
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
        }
    }
}
