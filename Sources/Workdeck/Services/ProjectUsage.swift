import Foundation

enum ProjectUsage {
    private static let openCountsKey = "ProjectOpenCounts"

    static var openCounts: [String: Int] {
        UserDefaults.standard.dictionary(forKey: openCountsKey) as? [String: Int] ?? [:]
    }

    static func recordOpen(of url: URL) {
        var counts = openCounts
        counts[url.standardizedFileURL.path, default: 0] += 1
        UserDefaults.standard.set(counts, forKey: openCountsKey)
    }
}
