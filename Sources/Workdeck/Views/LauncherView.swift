import SwiftUI

struct LauncherView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case workspaces = "Workspaces"
        case gitRepositories = "Git Repos"

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .workspaces
    @State private var query = ""
    @State private var workspaces: [Workspace] = []
    @State private var gitRepositories: [GitRepository] = []
    @State private var gitStatuses: [URL: GitStatus] = [:]
    @State private var gitStatusTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var filteredWorkspaces: [Workspace] {
        normalizedQuery.isEmpty ? workspaces : workspaces.filter { $0.searchText.contains(normalizedQuery) }
    }

    private var filteredGitRepositories: [GitRepository] {
        normalizedQuery.isEmpty ? gitRepositories : gitRepositories.filter { $0.searchText.contains(normalizedQuery) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340, height: 480)
        .onAppear(perform: reload)
        .onChange(of: selectedTab) { refreshGitStatusesIfVisible() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Picker("View", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit(openFirstMatch)
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .workspaces:
            GroupedList(items: filteredWorkspaces, groupName: \.group, onSelect: { open($0.url) }) { workspace in
                WorkspaceRow(workspace: workspace)
            }
        case .gitRepositories:
            GroupedList(items: filteredGitRepositories, groupName: \.group, onSelect: { open($0.url) }) { repository in
                GitRepositoryRow(repository: repository, status: gitStatuses[repository.url])
            }
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
        workspaces = WorkspaceScanner().scan()
        gitRepositories = GitRepositoryScanner().scan()
        isSearchFocused = true
        refreshGitStatusesIfVisible()
    }

    private func refreshGitStatusesIfVisible() {
        guard selectedTab == .gitRepositories else { return }

        gitStatusTask?.cancel()
        let repositoryURLs = gitRepositories.map(\.url)
        gitStatusTask = Task {
            await withTaskGroup(of: (URL, GitStatus?).self) { group in
                for url in repositoryURLs {
                    group.addTask { (url, await GitStatusReader.status(of: url)) }
                }
                for await (url, status) in group where !Task.isCancelled {
                    gitStatuses[url] = status
                }
            }
        }
    }

    private func openFirstMatch() {
        let firstMatchURL = switch selectedTab {
        case .workspaces: filteredWorkspaces.first?.url
        case .gitRepositories: filteredGitRepositories.first?.url
        }
        guard let firstMatchURL else { return }
        open(firstMatchURL)
    }

    private func open(_ url: URL) {
        WorkspaceOpener.open(url)
        query = ""
        dismiss()
    }
}
