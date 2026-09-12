import Foundation

struct GitRepositoryScanner {
    let root: URL
    let maxDepth: Int

    init(root: URL, maxDepth: Int = 3) {
        self.root = root.standardizedFileURL
        self.maxDepth = maxDepth
    }

    func scan() -> [GitRepository] {
        var repositories: [GitRepository] = []
        scanDirectory(root, depth: 0, repositories: &repositories)
        return repositories.sorted { ($0.group.lowercased(), $0.name.lowercased()) < ($1.group.lowercased(), $1.name.lowercased()) }
    }

    private func scanDirectory(_ directory: URL, depth: Int, repositories: inout [GitRepository]) {
        let entries = DirectoryScanning.contents(of: directory)

        if DirectoryScanning.containsGitRepository(entries) {
            repositories.append(GitRepository(
                name: directory.lastPathComponent,
                group: DirectoryScanning.group(for: directory, under: root),
                root: root,
                url: directory
            ))
        }

        guard depth < maxDepth else { return }

        for subdirectory in entries where DirectoryScanning.isScannableDirectory(subdirectory) {
            scanDirectory(subdirectory, depth: depth + 1, repositories: &repositories)
        }
    }
}
