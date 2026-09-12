import Foundation

enum DirectoryScanning {
    static let gitDirectoryName = ".git"
    private static let excludedDirectoryNames: Set<String> = ["node_modules", "dist", "build", "vendor", "Pods"]

    static func contents(of directory: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        return entries.map(\.standardizedFileURL)
    }

    static func isScannableDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix("."), !excludedDirectoryNames.contains(name) else { return false }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    static func containsGitRepository(_ entries: [URL]) -> Bool {
        entries.contains { $0.lastPathComponent == gitDirectoryName }
    }

    static func group(for url: URL, under root: URL) -> String {
        let relativeComponents = url.pathComponents.dropFirst(root.pathComponents.count)
        guard relativeComponents.count > 1, let first = relativeComponents.first else { return "Other" }
        return first
    }
}
