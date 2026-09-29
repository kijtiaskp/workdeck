import Foundation

enum ProcessTree {
    private static let psExecutableURL = URL(fileURLWithPath: "/bin/ps")

    static func withDescendants(_ rootProcessIDs: [Int32]) async -> [Int32] {
        guard let output = await ProcessRunner.output(of: psExecutableURL, arguments: ["-Ao", "pid=,ppid="]) else {
            return rootProcessIDs
        }

        var childrenByParent: [Int32: [Int32]] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace).compactMap { Int32($0) }
            guard fields.count == 2 else { continue }
            childrenByParent[fields[1], default: []].append(fields[0])
        }

        var result: [Int32] = []
        var pending = rootProcessIDs
        while let processID = pending.popLast() {
            guard !result.contains(processID) else { continue }
            result.append(processID)
            pending.append(contentsOf: childrenByParent[processID] ?? [])
        }
        return result
    }
}
