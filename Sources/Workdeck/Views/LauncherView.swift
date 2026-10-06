import SwiftUI

struct LauncherView: View {
    private static let allRootsSelection = ""

    @Environment(\.dismiss) private var dismiss
    @AppStorage("SelectedScanRoot") private var selectedRootPath = allRootsSelection
    @AppStorage(MenuBarLabelStyle.defaultsKey) private var labelStyle: MenuBarLabelStyle = .icon
    @AppStorage(MenuBarNameLength.defaultsKey) private var nameLength: MenuBarNameLength = .full
    @State private var query = ""
    @State private var scanRoots: [URL] = []
    @State private var projects: [Project] = []
    @State private var expandedProjectIDs: Set<URL> = []
    @State private var openCounts: [String: Int] = [:]
    @State private var gitStatuses: [URL: GitStatus] = [:]
    @State private var gitRemoteURLs: [URL: URL] = [:]
    @State private var gitStatusTask: Task<Void, Never>?
    @State private var projectStatuses: [URL: ProjectStatus] = [:]
    @State private var projectStatusTask: Task<Void, Never>?
    @State private var pendingAppNames: Set<String> = []
    @State private var failedAppNames: Set<String> = []
    @State private var databaseServices: [DatabaseService] = []
    @State private var pendingDatabaseFormulas: Set<String> = []
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

    private var visibleProjects: [Project] {
        rankedByUsage(projects.filter { isVisible(root: $0.root, searchText: $0.searchText) })
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
        .onChange(of: labelStyle) {
            if labelStyle.showsText && !AccessibilityPermission.isGranted {
                AccessibilityPermission.request()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            rootMenu
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit(openFirstMatch)
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
            Menu("Move Folder to Top") {
                ForEach(scanRoots.dropFirst(), id: \.self) { root in
                    Button((root.path as NSString).abbreviatingWithTildeInPath) { moveScanRootToTop(root) }
                }
            }
            .disabled(scanRoots.count < 2)
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

    private var content: some View {
        VStack(spacing: 0) {
            if !databaseServices.isEmpty {
                DatabaseServicesView(
                    services: databaseServices,
                    pendingFormulas: pendingDatabaseFormulas,
                    onStart: startDatabase,
                    onStop: stopDatabase
                )
                Divider()
            }
            projectList
        }
    }

    private var projectList: some View {
        GroupedList(
            items: visibleProjects,
            groupName: { sectionName(group: $0.group, root: $0.root) },
            onSelect: { open($0.url) },
            emptyTitle: normalizedQuery.isEmpty ? "No projects yet" : "Nothing found",
            emptySystemImage: normalizedQuery.isEmpty ? "folder.badge.plus" : "magnifyingglass",
            emptyDescription: normalizedQuery.isEmpty ? "Choose Add Folder… from the folder menu." : nil
        ) { project in
            projectRow(for: project)
        }
    }

    private func projectRow(for project: Project) -> some View {
        let status = projectStatuses[project.url]
        let repositoryURL = project.repository?.url
        return ProjectRow(
            project: project,
            gitStatus: repositoryURL.flatMap { gitStatuses[$0] },
            remoteURL: repositoryURL.flatMap { gitRemoteURLs[$0] },
            runningAppCount: status?.runningAppCount ?? 0,
            hasDetails: !(status?.isEmpty ?? true),
            isExpanded: expansionBinding(for: project)
        ) {
            if let status {
                ProjectStatusDetails(
                    status: status,
                    pendingAppNames: pendingAppNames,
                    failedAppNames: failedAppNames,
                    onStart: startApp,
                    onStop: stopApp
                )
            }
        }
        .contextMenu { editLinksButton(for: project.workspace) }
    }

    private func expansionBinding(for project: Project) -> Binding<Bool> {
        Binding(
            get: { expandedProjectIDs.contains(project.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedProjectIDs.insert(project.id)
                } else {
                    expandedProjectIDs.remove(project.id)
                }
            }
        )
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

    private func rankedByUsage(_ projects: [Project]) -> [Project] {
        let rootOrder = Dictionary(uniqueKeysWithValues: scanRoots.enumerated().map { ($1.path, $0) })
        let openCount = { (project: Project) in openCounts[project.url.standardizedFileURL.path] ?? 0 }
        let groupKey = { (project: Project) in "\(project.root.path)/\(project.group)" }
        let groupOpenCounts = Dictionary(grouping: projects, by: groupKey)
            .mapValues { $0.reduce(0) { $0 + openCount($1) } }

        return projects.sorted { lhs, rhs in
            let lhsRootIndex = rootOrder[lhs.root.path] ?? .max
            let rhsRootIndex = rootOrder[rhs.root.path] ?? .max
            if lhsRootIndex != rhsRootIndex { return lhsRootIndex < rhsRootIndex }

            let lhsGroupCount = groupOpenCounts[groupKey(lhs)] ?? 0
            let rhsGroupCount = groupOpenCounts[groupKey(rhs)] ?? 0
            if lhsGroupCount != rhsGroupCount { return lhsGroupCount > rhsGroupCount }
            if lhs.group != rhs.group { return lhs.group.lowercased() < rhs.group.lowercased() }

            let lhsCount = openCount(lhs)
            let rhsCount = openCount(rhs)
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return lhs.name.lowercased() < rhs.name.lowercased()
        }
    }

    private func sectionName(group: String, root: URL) -> String {
        isShowingAllRoots && scanRoots.count > 1 ? "\(root.lastPathComponent) › \(group)" : group
    }

    private func reload() {
        scanRoots = ScanRoots.all
        openCounts = ProjectUsage.openCounts
        if !scanRoots.contains(where: { $0.path == selectedRootPath }) {
            selectedRootPath = Self.allRootsSelection
        }
        projects = Project.merge(
            workspaces: scanRoots.flatMap { WorkspaceScanner(root: $0).scan() },
            repositories: scanRoots.flatMap { GitRepositoryScanner(root: $0).scan() }
        )
        isSearchFocused = true
        refreshGitStatuses()
        refreshProjectStatuses()
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

    private func moveScanRootToTop(_ root: URL) {
        ScanRoots.moveToTop(root)
        reload()
    }

    private func removeScanRoot(_ root: URL) {
        ScanRoots.remove(root)
        reload()
    }

    private func refreshGitStatuses() {
        gitStatusTask?.cancel()
        let repositoryURLs = projects.compactMap(\.repository?.url)
        gitStatusTask = Task {
            await withTaskGroup(of: (URL, GitStatus?, URL?).self) { group in
                for url in repositoryURLs {
                    group.addTask {
                        async let status = GitStatusReader.status(of: url)
                        async let remoteURL = GitStatusReader.remoteWebURL(of: url)
                        return (url, await status, await remoteURL)
                    }
                }
                for await (url, status, remoteURL) in group where !Task.isCancelled {
                    gitStatuses[url] = status
                    gitRemoteURLs[url] = remoteURL
                }
            }
        }
    }

    private func refreshProjectStatuses() {
        projectStatusTask?.cancel()
        projectStatusTask = Task { await loadProjectStatuses() }
    }

    private func loadProjectStatuses() async {
        let workspaces = projects.map(\.workspace)
        async let portlessSnapshot = Portless.snapshot()
        async let tailscaleEntries = TailscaleServe.entries()
        async let postgresServices = HomebrewServices.postgresServices()
        let portless = await portlessSnapshot
        let tailscaleServe = await tailscaleEntries
        databaseServices = await postgresServices
        await withTaskGroup(of: (URL, ProjectStatus).self) { group in
            for workspace in workspaces {
                group.addTask {
                    (workspace.url, await ProjectStatusReader.status(of: workspace, portless: portless, tailscaleServe: tailscaleServe))
                }
            }
            for await (url, status) in group where !Task.isCancelled {
                projectStatuses[url] = status
            }
        }
    }

    private func startApp(_ app: LocalApp) {
        failedAppNames.remove(app.name)
        pendingAppNames.insert(app.name)
        Task {
            if case .packageScriptOnPort(_, let port) = app.launchCommand {
                await PortlessAppController.freePort(port)
            }
            guard let process = try? PortlessAppController.start(app) else {
                failedAppNames.insert(app.name)
                pendingAppNames.remove(app.name)
                return
            }
            refreshUntil(appNamed: app.name, isRunning: true, startedProcess: process)
        }
    }

    private func stopApp(_ app: AppStatus) {
        guard let processID = app.processID else { return }
        pendingAppNames.insert(app.name)
        Task {
            await PortlessAppController.stop(processID: processID)
            refreshUntil(appNamed: app.name, isRunning: false)
        }
    }

    private func startDatabase(_ service: DatabaseService) {
        changeDatabase(service, expectedState: .running) { await HomebrewServices.start(service) }
    }

    private func stopDatabase(_ service: DatabaseService) {
        changeDatabase(service, expectedState: .stopped) { await HomebrewServices.stop(service) }
    }

    private func changeDatabase(_ service: DatabaseService, expectedState: DatabaseService.State, action: @escaping () async -> Bool) {
        pendingDatabaseFormulas.insert(service.formula)
        Task {
            _ = await action()
            for _ in 0..<10 {
                databaseServices = await HomebrewServices.postgresServices()
                let current = databaseServices.first { $0.formula == service.formula }?.state
                if current == expectedState || current == .failed { break }
                try? await Task.sleep(for: .seconds(1))
            }
            pendingDatabaseFormulas.remove(service.formula)
            await loadProjectStatuses()
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
        guard let firstMatchURL = visibleProjects.first?.url else { return }
        open(firstMatchURL)
    }

    private func open(_ url: URL) {
        WorkspaceOpener.open(url)
        ProjectUsage.recordOpen(of: url)
        query = ""
        dismiss()
    }
}
