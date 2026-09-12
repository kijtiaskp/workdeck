import Foundation

struct GitStatus: Equatable {
    private static let branchLinePrefix = "## "
    private static let unbornBranchPrefix = "No commits yet on "
    private static let detachedHeadPrefix = "HEAD (no branch)"

    let branch: String
    let changedFileCount: Int
    let aheadCount: Int
    let behindCount: Int

    var isClean: Bool { changedFileCount == 0 }

    init(porcelainOutput: String) {
        let lines = porcelainOutput.split(separator: "\n").map(String.init)
        let branchLine = lines.first { $0.hasPrefix(Self.branchLinePrefix) }
            .map { String($0.dropFirst(Self.branchLinePrefix.count)) } ?? ""
        let trackingInfo = branchLine.range(of: " [").map { String(branchLine[$0.upperBound...]) } ?? ""

        branch = Self.branchName(from: branchLine)
        changedFileCount = lines.filter { !$0.hasPrefix(Self.branchLinePrefix) }.count
        aheadCount = Self.commitCount(labeled: "ahead", in: trackingInfo)
        behindCount = Self.commitCount(labeled: "behind", in: trackingInfo)
    }

    private static func branchName(from branchLine: String) -> String {
        if branchLine.hasPrefix(detachedHeadPrefix) {
            return "detached HEAD"
        }
        let line = branchLine.hasPrefix(unbornBranchPrefix)
            ? String(branchLine.dropFirst(unbornBranchPrefix.count))
            : branchLine
        let nameEnd = line.range(of: "...")?.lowerBound
            ?? line.range(of: " [")?.lowerBound
            ?? line.endIndex
        return String(line[..<nameEnd])
    }

    private static func commitCount(labeled label: String, in trackingInfo: String) -> Int {
        guard let labelRange = trackingInfo.range(of: "\(label) ") else { return 0 }
        return Int(trackingInfo[labelRange.upperBound...].prefix(while: \.isNumber)) ?? 0
    }
}
