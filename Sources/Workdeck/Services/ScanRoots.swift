import Foundation

enum ScanRoots {
    private static let rootsKey = "ScanRoots"
    private static let legacyRootKey = "ScanRoot"
    private static let fallback = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer", isDirectory: true)

    static var all: [URL] {
        let defaults = UserDefaults.standard
        if let paths = defaults.stringArray(forKey: rootsKey) {
            return paths.map(directoryURL(fromPath:))
        }
        if let legacyPath = defaults.string(forKey: legacyRootKey) {
            return [directoryURL(fromPath: legacyPath)]
        }
        return [fallback]
    }

    static func add(_ roots: [URL]) {
        let newRoots = roots.map(\.standardizedFileURL).filter { !all.contains($0) }
        save(all + newRoots)
    }

    static func remove(_ root: URL) {
        save(all.filter { $0 != root })
    }

    private static func save(_ roots: [URL]) {
        UserDefaults.standard.set(roots.map(\.path), forKey: rootsKey)
    }

    private static func directoryURL(fromPath path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
    }
}
