import SwiftUI

struct LauncherView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case workspaces = "Workspaces"
        case gitRepositories = "Git Repos"

        var id: Self { self }
    }

    private static let allRootsSelection = ""

    @Environment(\.dismiss) private var dismiss
    @AppStorage("SelectedScanRoot") private var selectedRootPath = allRootsSelection
    @State private var selectedTab: Tab = .workspaces
    @State private var query = ""
    @State private var scanRoots: [URL] = []
    @State private var workspaces: [Workspace] = []
    @State private var gitRepositories: [GitRepository] = []
    @State private var gitStatuses: [URL: GitStatus] = [:]
    @State private var gitStatusTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var isShowingAllRoots: Bool { selectedRootPath == Self.allRootsSelection }

    private var selectedRootTitle: String {
        isShowingAllRoots ? "All" : URL(fileURLWithPath: selectedRootPath).lastPathComponent
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var visibleWorkspaces: [Workspace] {
        workspaces.filter { isVisible(root: $0.root, searchText: $0.searchText) }
    }

    private var visibleGitRepositories: [GitRepository] {
        gitRepositories.filter { isVisible(root: $0.root, searchText: $0.searchText) }
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

            HStack(spacing: 6) {
                rootMenu
                TextField("Search", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .onSubmit(openFirstMatch)
            }
        }
        .padding(10)
    }

    private var rootMenu: some View {
        Menu {
            Picker("Show", selection: $selectedRootPath) {
                Text("All Folders").tag(Self.allRootsSelection)
                ForEach(scanRoots, id: \.self) { root in
                    Text(root.lastPathComponent).tag(root.path)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button("Add Folder…", action: addScanRoots)
            Menu("Remove Folder") {
                ForEach(scanRoots, id: \.self) { root in
                    Button((root.path as NSString).abbreviatingWithTildeInPath) { removeScanRoot(root) }
                }
            }
            .disabled(scanRoots.isEmpty)
        } label: {
            Label(selectedRootTitle, systemImage: "folder")
        }
        .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .workspaces:
            GroupedList(
                items: visibleWorkspaces,
                groupName: { sectionName(group: $0.group, root: $0.root) },
                onSelect: { open($0.url) }
            ) { workspace in
                WorkspaceRow(workspace: workspace)
            }
        case .gitRepositories:
            GroupedList(
                items: visibleGitRepositories,
                groupName: { sectionName(group: $0.group, root: $0.root) },
                onSelect: { open($0.url) }
            ) { repository in
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

    private func isVisible(root: URL, searchText: String) -> Bool {
        let matchesRoot = isShowingAllRoots || root.path == selectedRootPath
        let matchesQuery = normalizedQuery.isEmpty || searchText.contains(normalizedQuery)
        return matchesRoot && matchesQuery
    }

    private func sectionName(group: String, root: URL) -> String {
        isShowingAllRoots && scanRoots.count > 1 ? "\(root.lastPathComponent) › \(group)" : group
    }

    private func reload() {
        scanRoots = ScanRoots.all
        if !scanRoots.contains(where: { $0.path == selectedRootPath }) {
            selectedRootPath = Self.allRootsSelection
        }
        workspaces = scanRoots.flatMap { WorkspaceScanner(root: $0).scan() }
        gitRepositories = scanRoots.flatMap { GitRepositoryScanner(root: $0).scan() }
        isSearchFocused = true
        refreshGitStatusesIfVisible()
    }

    private func addScanRoots() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose folders that contain your projects"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        ScanRoots.add(panel.urls)
        reload()
    }

    private func removeScanRoot(_ root: URL) {
        ScanRoots.remove(root)
        reload()
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
        case .workspaces: visibleWorkspaces.first?.url
        case .gitRepositories: visibleGitRepositories.first?.url
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
