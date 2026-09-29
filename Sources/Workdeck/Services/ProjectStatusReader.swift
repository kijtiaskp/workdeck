import Foundation

enum ProjectStatusReader {
    static func status(of workspace: Workspace, portless: PortlessSnapshot) async -> ProjectStatus {
        let environments = workspace.directories.lazy.compactMap(ProjectLinksFile.load(from:)).first ?? []
        let configuredApps = PortlessAppScanner.apps(in: workspace.directories)

        var appStatuses: [AppStatus] = []
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

        return ProjectStatus(environments: environments, apps: appStatuses)
    }

    private static func status(
        ofAppNamed name: String,
        directory: URL,
        launchableApp: PortlessApp?,
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
