import Foundation

enum ProjectStatusReader {
    private struct TailnetSetup {
        let config: ProjectLinksFile.TailnetConfig
        let baseDirectory: URL

        func folder(of app: ProjectLinksFile.TailnetConfig.App) -> URL {
            baseDirectory.appendingPathComponent(app.folder).standardizedFileURL
        }
    }

    private struct PortOccupant {
        let processID: Int32
        let workingDirectory: URL?
    }

    static func status(of workspace: Workspace, portless: PortlessSnapshot, tailscaleServe: [TailscaleServeEntry]) async -> ProjectStatus {
        let environments = workspace.directories.lazy.compactMap(ProjectLinksFile.load(from:)).first ?? []
        let tailnet = workspace.directories.lazy
            .compactMap { directory in ProjectLinksFile.tailnetConfig(from: directory).map { TailnetSetup(config: $0, baseDirectory: directory) } }
            .first
        let tailnetFolders = tailnet.map { setup in setup.config.apps.values.map(setup.folder(of:)) } ?? []
        let configuredApps = PortlessAppScanner.apps(in: workspace.directories)
            .filter { app in !tailnetFolders.contains { isInside(app.directory, $0) } }

        var appStatuses: [AppStatus] = []
        var tailnetShares: [TailnetShare] = []
        if let tailnet {
            let occupant = await occupant(of: tailnet.config.port)
            let entry = tailscaleServe.first { $0.targetPort == tailnet.config.port }
            appStatuses += tailnetAppStatuses(tailnet, occupant: occupant, entry: entry)
            if let entry {
                tailnetShares.append(share(for: entry, tailnet: tailnet, occupant: occupant))
            }
        }

        var claimedHostnames: Set<String> = []
        for app in configuredApps {
            let matchingRoute = portless.routes(forAppNamed: app.name).first
            if let matchingRoute {
                claimedHostnames.insert(matchingRoute.route.hostname)
            }
            appStatuses.append(await status(
                ofAppNamed: app.name,
                directory: app.directory,
                launchableApp: app,
                route: matchingRoute,
                settings: portless.settings,
                environments: environments
            ))
        }

        let ownedDirectories = workspace.directories.filter { $0.path != workspace.root.path }
        let unconfiguredRoutes = portless.routes.filter { route in
            !claimedHostnames.contains(route.route.hostname) && ownedDirectories.contains(where: route.isInside)
        }
        for route in unconfiguredRoutes {
            appStatuses.append(await status(
                ofAppNamed: portless.settings.appName(forHostname: route.route.hostname),
                directory: route.workingDirectory ?? workspace.directories[0],
                launchableApp: nil,
                route: route,
                settings: portless.settings,
                environments: environments
            ))
        }

        let otherEntries = tailscaleServe.filter { $0.targetPort != tailnet?.config.port }
        tailnetShares += await ownedShares(of: otherEntries, ownedDirectories: ownedDirectories)

        return ProjectStatus(
            environments: environments,
            apps: appStatuses,
            tailnetShares: tailnetShares,
            repositories: await repositoryLinks(in: workspace.directories)
        )
    }

    private static func tailnetAppStatuses(_ tailnet: TailnetSetup, occupant: PortOccupant?, entry: TailscaleServeEntry?) -> [AppStatus] {
        let port = tailnet.config.port
        return tailnet.config.apps
            .sorted { $0.key < $1.key }
            .map { name, app in
                let folder = tailnet.folder(of: app)
                let isRunning = occupant?.workingDirectory.map { isInside($0, folder) } ?? false
                return AppStatus(
                    name: name,
                    url: link(base: entry?.url ?? URL(string: "https://localhost:\(port)/"), path: app.path),
                    database: nil,
                    launchableApp: LocalApp(name: name, directory: folder, launchCommand: .packageScriptOnPort(app.script ?? "dev", port: port)),
                    processID: isRunning ? occupant?.processID : nil
                )
            }
    }

    private static func share(for entry: TailscaleServeEntry, tailnet: TailnetSetup, occupant: PortOccupant?) -> TailnetShare {
        let runningApp = tailnet.config.apps.first { _, app in
            occupant?.workingDirectory.map { isInside($0, tailnet.folder(of: app)) } ?? false
        }
        return TailnetShare(
            url: link(base: entry.url, path: runningApp?.value.path) ?? entry.url,
            appName: runningApp?.key ?? "port \(tailnet.config.port)",
            targetPort: entry.targetPort,
            isRunning: occupant != nil
        )
    }

    private static func ownedShares(of entries: [TailscaleServeEntry], ownedDirectories: [URL]) async -> [TailnetShare] {
        var shares: [TailnetShare] = []
        for entry in entries {
            guard let occupant = await occupant(of: entry.targetPort),
                  let directory = occupant.workingDirectory,
                  ownedDirectories.contains(where: { isInside(directory, $0) })
            else { continue }
            shares.append(TailnetShare(url: entry.url, appName: directory.lastPathComponent, targetPort: entry.targetPort, isRunning: true))
        }
        return shares
    }

    private static func repositoryLinks(in directories: [URL]) async -> [EnvironmentLinks.Link] {
        var links: [EnvironmentLinks.Link] = []
        for directory in directories
        where FileManager.default.fileExists(atPath: directory.appendingPathComponent(DirectoryScanning.gitDirectoryName).path) {
            if let url = await GitStatusReader.remoteWebURL(of: directory) {
                links.append(EnvironmentLinks.Link(label: directory.lastPathComponent, url: url))
            }
        }
        return links
    }

    private static func occupant(of port: Int) async -> PortOccupant? {
        guard let processID = await ProcessTree.listeningProcessIDs(on: port).first else { return nil }
        return PortOccupant(processID: processID, workingDirectory: await ProcessTree.workingDirectory(ofProcess: processID))
    }

    private static func link(base: URL?, path: String?) -> URL? {
        guard let base else { return nil }
        guard let path else { return base }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    private static func isInside(_ directory: URL, _ parent: URL) -> Bool {
        directory.path == parent.path || directory.path.hasPrefix(parent.path + "/")
    }

    private static func status(
        ofAppNamed name: String,
        directory: URL,
        launchableApp: LocalApp?,
        route: RunningPortlessRoute?,
        settings: PortlessProxySettings,
        environments: [EnvironmentLinks]
    ) async -> AppStatus {
        guard let route else {
            return AppStatus(
                name: name,
                url: settings.url(forHostname: settings.hostname(forAppNamed: name)),
                database: nil,
                launchableApp: launchableApp,
                processID: nil
            )
        }

        let database = await DatabaseConnectionDetector.connection(
            ofServerListeningOn: route.route.port,
            projectDirectory: directory,
            environmentLinks: environments
        )
        return AppStatus(
            name: name,
            url: settings.url(forHostname: route.route.hostname),
            database: database,
            launchableApp: launchableApp,
            processID: route.route.pid == 0 ? nil : route.route.pid
        )
    }
}
