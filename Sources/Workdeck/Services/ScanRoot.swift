import Foundation

enum ScanRoot {
    static let defaultsKey = "ScanRoot"
    static let fallback = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer", isDirectory: true)

    static var configured: URL {
        guard let path = UserDefaults.standard.string(forKey: defaultsKey) else { return fallback }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }
}
