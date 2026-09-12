import Foundation

struct WorkspaceScanner {
    static let scanRootDefaultsKey = "ScanRoot"
    static let fallbackRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer", isDirectory: true)

    static var configuredRoot: URL {
        guard let path = UserDefaults.standard.string(forKey: scanRootDefaultsKey) else { return fallbackRoot }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    private static let workspaceExtension = "code-workspace"
    private static let excludedDirectoryNames: Set<String> = ["node_modules", "dist", "build", "vendor", "Pods"]

    let root: URL
    let maxDepth: Int

    init(root: URL = configuredRoot, maxDepth: Int = 3) {
        self.root = root.standardizedFileURL
        self.maxDepth = maxDepth
    }

    func scan() -> [Workspace] {
        var workspaces: [Workspace] = []
        var coveredPaths: Set<String> = []
        scanDirectory(root, depth: 0, workspaces: &workspaces, coveredPaths: &coveredPaths)
        return workspaces.sorted { ($0.group.lowercased(), $0.name.lowercased()) < ($1.group.lowercased(), $1.name.lowercased()) }
    }

    private func scanDirectory(_ directory: URL, depth: Int, workspaces: inout [Workspace], coveredPaths: inout Set<String>) {
        let entries = contents(of: directory)
        let workspaceFiles = entries.filter { $0.pathExtension == Self.workspaceExtension }
        let isGitRepository = entries.contains { $0.lastPathComponent == ".git" }

        for file in workspaceFiles {
            workspaces.append(Workspace(
                name: file.deletingPathExtension().lastPathComponent,
                group: group(for: file),
                url: file,
                kind: .workspaceFile
            ))
            coveredPaths.formUnion(folderPaths(referencedBy: file))
        }

        if isGitRepository && workspaceFiles.isEmpty {
            if directory != root && !coveredPaths.contains(directory.path) {
                workspaces.append(Workspace(
                    name: directory.lastPathComponent,
                    group: group(for: directory),
                    url: directory,
                    kind: .folder
                ))
            }
            return
        }

        guard depth < maxDepth else { return }

        for subdirectory in entries where isScannableDirectory(subdirectory) && !coveredPaths.contains(subdirectory.path) {
            scanDirectory(subdirectory, depth: depth + 1, workspaces: &workspaces, coveredPaths: &coveredPaths)
        }
    }

    private func contents(of directory: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        return entries.map(\.standardizedFileURL)
    }

    private func isScannableDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix("."), !Self.excludedDirectoryNames.contains(name) else { return false }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func folderPaths(referencedBy workspaceFile: URL) -> [String] {
        struct WorkspaceDefinition: Decodable {
            struct Folder: Decodable { let path: String }
            let folders: [Folder]
        }

        guard let data = try? Data(contentsOf: workspaceFile) else { return [] }
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        guard let definition = try? decoder.decode(WorkspaceDefinition.self, from: data) else { return [] }

        let baseDirectory = workspaceFile.deletingLastPathComponent()
        return definition.folders.map { folder in
            let expandedPath = (folder.path as NSString).expandingTildeInPath
            let url = expandedPath.hasPrefix("/")
                ? URL(fileURLWithPath: expandedPath)
                : baseDirectory.appendingPathComponent(expandedPath)
            return url.standardizedFileURL.path
        }
    }

    private func group(for url: URL) -> String {
        let relativeComponents = url.pathComponents.dropFirst(root.pathComponents.count)
        guard relativeComponents.count > 1, let first = relativeComponents.first else { return "Other" }
        return first
    }
}
