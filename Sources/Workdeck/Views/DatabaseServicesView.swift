import SwiftUI

struct DatabaseServicesView: View {
    let services: [DatabaseService]
    let pendingFormulas: Set<String>
    let onStart: (DatabaseService) -> Void
    let onStop: (DatabaseService) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(services) { service in
                HStack(spacing: 8) {
                    Image(systemName: "cylinder.split.1x2")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Circle()
                        .fill(color(for: service.state))
                        .frame(width: 6, height: 6)
                    Text(service.displayName)
                    Text(statusText(for: service))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    controlButton(for: service)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func controlButton(for service: DatabaseService) -> some View {
        if pendingFormulas.contains(service.formula) {
            ProgressView()
                .controlSize(.mini)
        } else if service.state == .running {
            Button("Stop", systemImage: "stop.fill") { onStop(service) }
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .help("Stop \(service.displayName)")
        } else {
            Button("Start", systemImage: "play.fill") { onStart(service) }
                .labelStyle(.iconOnly)
                .foregroundStyle(.green)
                .help("Start \(service.displayName) with brew services")
        }
    }

    private func color(for state: DatabaseService.State) -> Color {
        switch state {
        case .running: .green
        case .stopped: .secondary.opacity(0.4)
        case .failed: .orange
        }
    }

    private func statusText(for service: DatabaseService) -> String {
        switch service.state {
        case .running: "running · :\(service.port)"
        case .stopped: "stopped"
        case .failed: "failed to start"
        }
    }
}
