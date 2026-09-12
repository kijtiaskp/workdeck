import SwiftUI

struct LauncherView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workspaces: [Workspace] = []
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private let scanner = WorkspaceScanner()

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var filteredWorkspaces: [Workspace] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedQuery.isEmpty else { return workspaces }
        return workspaces.filter { $0.searchText.contains(trimmedQuery) }
    }

    private var groupedWorkspaces: [(group: String, items: [Workspace])] {
        Dictionary(grouping: filteredWorkspaces, by: \.group)
            .map { (group: $0.key, items: $0.value) }
            .sorted { $0.group.lowercased() < $1.group.lowercased() }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            workspaceList
            Divider()
            footer
        }
        .frame(width: 340, height: 480)
        .onAppear(perform: reload)
    }

    private var searchField: some View {
        TextField("Search workspaces", text: $query)
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFocused)
            .onSubmit(openFirstMatch)
            .padding(10)
    }

    @ViewBuilder
    private var workspaceList: some View {
        if filteredWorkspaces.isEmpty {
            ContentUnavailableView("No workspaces", systemImage: "magnifyingglass")
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(groupedWorkspaces, id: \.group) { section in
                    Section(section.group) {
                        ForEach(section.items) { workspace in
                            WorkspaceRow(workspace: workspace)
                                .onTapGesture { open(workspace) }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var footer: some View {
        HStack {
            Button("Rescan", systemImage: "arrow.clockwise", action: reload)
            Spacer()
            Text("v\(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .padding(10)
    }

    private func reload() {
        workspaces = scanner.scan()
        isSearchFocused = true
    }

    private func openFirstMatch() {
        guard let firstMatch = filteredWorkspaces.first else { return }
        open(firstMatch)
    }

    private func open(_ workspace: Workspace) {
        WorkspaceOpener.open(workspace)
        query = ""
        dismiss()
    }
}
