import Foundation

struct WorkspaceScanner {
    private static let workspaceExtension = "code-workspace"

    let root: URL
    let maxDepth: Int

    init(root: URL, maxDepth: Int = 3) {
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
        let entries = DirectoryScanning.contents(of: directory)
        let workspaceFiles = entries.filter { $0.pathExtension == Self.workspaceExtension }

        for file in workspaceFiles {
            let referencedFolderPaths = folderPaths(referencedBy: file)
            workspaces.append(Workspace(
                name: file.deletingPathExtension().lastPathComponent,
                group: DirectoryScanning.group(for: file, under: root),
                root: root,
                url: file,
                kind: .workspaceFile,
                directories: projectDirectories(of: file, referencedFolderPaths: referencedFolderPaths)
            ))
            coveredPaths.formUnion(referencedFolderPaths)
        }

        if DirectoryScanning.containsGitRepository(entries) && workspaceFiles.isEmpty {
            if directory != root && !coveredPaths.contains(directory.path) {
                workspaces.append(Workspace(
                    name: directory.lastPathComponent,
                    group: DirectoryScanning.group(for: directory, under: root),
                    root: root,
                    url: directory,
                    kind: .folder,
                    directories: [directory]
                ))
            }
            return
        }

        guard depth < maxDepth else { return }

        for subdirectory in entries where DirectoryScanning.isScannableDirectory(subdirectory) && !coveredPaths.contains(subdirectory.path) {
            scanDirectory(subdirectory, depth: depth + 1, workspaces: &workspaces, coveredPaths: &coveredPaths)
        }
    }

    private func projectDirectories(of workspaceFile: URL, referencedFolderPaths: [String]) -> [URL] {
        let baseDirectory = workspaceFile.deletingLastPathComponent().standardizedFileURL
        let folders = referencedFolderPaths
            .filter { $0 != baseDirectory.path }
            .map { URL(fileURLWithPath: $0) }
        return [baseDirectory] + folders
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
}
