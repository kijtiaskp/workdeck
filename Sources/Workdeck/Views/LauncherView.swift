import SwiftUI

struct LauncherView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case workspaces = "Workspaces"
        case gitRepositories = "Git Repos"
        case status = "Status"

        var id: Self { self }
    }

    private static let allRootsSelection = ""
    private static let statusEmptyDescription = """
        Right-click a project in Workspaces and choose Edit Environment Links… to add prod and dev URLs, \
        or add a portless.json to an app folder to run it from here.
        """

    @Environment(\.dismiss) private var dismiss
    @AppStorage("SelectedScanRoot") private var selectedRootPath = allRootsSelection
    @AppStorage(MenuBarLabelStyle.defaultsKey) private var labelStyle: MenuBarLabelStyle = .icon
    @AppStorage(MenuBarNameLength.defaultsKey) private var nameLength: MenuBarNameLength = .full
    @State private var selectedTab: Tab = .workspaces
    @State private var query = ""
    @State private var scanRoots: [URL] = []
    @State private var workspaces: [Workspace] = []
    @State private var gitRepositories: [GitRepository] = []
    @State private var gitStatuses: [URL: GitStatus] = [:]
    @State private var gitStatusTask: Task<Void, Never>?
    @State private var projectStatuses: [URL: ProjectStatus] = [:]
    @State private var projectStatusTask: Task<Void, Never>?
    @State private var pendingAppNames: Set<String> = []
    @State private var failedAppNames: Set<String> = []
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

    private var visibleProjectStatuses: [(workspace: Workspace, status: ProjectStatus)] {
        visibleWorkspaces.compactMap { workspace in
            guard let status = projectStatuses[workspace.url], !status.isEmpty else { return nil }
            return (workspace, status)
        }
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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in reload() }
        .onChange(of: selectedTab) {
            refreshGitStatusesIfVisible()
            refreshProjectStatusesIfVisible()
        }
        .onChange(of: labelStyle) {
            if labelStyle.showsText && !AccessibilityPermission.isGranted {
                AccessibilityPermission.request()
            }
        }
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
                    .contextMenu { editLinksButton(for: workspace) }
            }
        case .gitRepositories:
            GroupedList(
                items: visibleGitRepositories,
                groupName: { sectionName(group: $0.group, root: $0.root) },
                onSelect: { open($0.url) }
            ) { repository in
                GitRepositoryRow(repository: repository, status: gitStatuses[repository.url])
            }
        case .status:
            GroupedList(
                items: visibleProjectStatuses.map(\.workspace),
                groupName: { sectionName(group: $0.group, root: $0.root) },
                emptyTitle: normalizedQuery.isEmpty ? "No environments yet" : "Nothing found",
                emptySystemImage: normalizedQuery.isEmpty ? "server.rack" : "magnifyingglass",
                emptyDescription: normalizedQuery.isEmpty ? Self.statusEmptyDescription : nil
            ) { workspace in
                if let status = projectStatuses[workspace.url] {
                    ProjectStatusRow(
                        workspace: workspace,
                        status: status,
                        pendingAppNames: pendingAppNames,
                        failedAppNames: failedAppNames,
                        onStart: startApp,
                        onStop: stopApp
                    )
                        .contextMenu {
                            Button("Open in VS Code") { open(workspace.url) }
                            editLinksButton(for: workspace)
                        }
                }
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
            settingsMenu
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .padding(10)
    }

    private var settingsMenu: some View {
        Menu {
            Picker("Menu Bar", selection: $labelStyle) {
                ForEach(MenuBarLabelStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.inline)

            Picker("Name Length", selection: $nameLength) {
                ForEach(MenuBarNameLength.allCases) { length in
                    Text(length.title).tag(length)
                }
            }
            .pickerStyle(.inline)
            .disabled(!labelStyle.showsText)

            if labelStyle.showsText && !AccessibilityPermission.isGranted {
                Divider()
                Button("Allow Accessibility Access…", action: AccessibilityPermission.request)
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuIndicator(.hidden)
        .fixedSize()
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
        refreshProjectStatusesIfVisible()
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

    private func refreshProjectStatusesIfVisible() {
        guard selectedTab == .status else { return }

        projectStatusTask?.cancel()
        projectStatusTask = Task { await loadProjectStatuses() }
    }

    private func loadProjectStatuses() async {
        let workspaces = self.workspaces
        let portless = await Portless.snapshot()
        await withTaskGroup(of: (URL, ProjectStatus).self) { group in
            for workspace in workspaces {
                group.addTask { (workspace.url, await ProjectStatusReader.status(of: workspace, portless: portless)) }
            }
            for await (url, status) in group where !Task.isCancelled {
                projectStatuses[url] = status
            }
        }
    }

    private func startApp(_ app: PortlessApp) {
        failedAppNames.remove(app.name)
        guard let process = try? PortlessAppController.start(app) else {
            failedAppNames.insert(app.name)
            return
        }
        pendingAppNames.insert(app.name)
        refreshUntil(appNamed: app.name, isRunning: true, startedProcess: process)
    }

    private func stopApp(_ app: AppStatus) {
        guard let processID = app.processID else { return }
        pendingAppNames.insert(app.name)
        Task {
            await PortlessAppController.stop(processID: processID)
            refreshUntil(appNamed: app.name, isRunning: false)
        }
    }

    private func refreshUntil(appNamed name: String, isRunning expectedState: Bool, startedProcess: Process? = nil) {
        Task {
            var reachedExpectedState = false
            for _ in 0..<15 {
                try? await Task.sleep(for: .seconds(2))
                await loadProjectStatuses()
                reachedExpectedState = projectStatuses.values.contains { status in
                    status.apps.contains { $0.name == name && $0.isRunning == expectedState }
                }
                let startedProcessExited = startedProcess.map { !$0.isRunning } ?? false
                if reachedExpectedState || startedProcessExited { break }
            }
            if startedProcess != nil && !reachedExpectedState {
                failedAppNames.insert(name)
            }
            pendingAppNames.remove(name)
        }
    }

    private func editLinksButton(for workspace: Workspace) -> some View {
        Button("Edit Environment Links…") {
            guard let projectDirectory = workspace.directories.first else { return }
            NSWorkspace.shared.open(ProjectLinksFile.createIfMissing(in: projectDirectory))
            dismiss()
        }
    }

    private func openFirstMatch() {
        let firstMatchURL = switch selectedTab {
        case .workspaces: visibleWorkspaces.first?.url
        case .gitRepositories: visibleGitRepositories.first?.url
        case .status: visibleProjectStatuses.first?.workspace.url
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
