import Foundation

enum ProcessTree {
    private static let psExecutableURL = URL(fileURLWithPath: "/bin/ps")
    private static let lsofExecutableURL = URL(fileURLWithPath: "/usr/sbin/lsof")

    static func listeningProcessIDs(on port: Int) async -> [Int32] {
        let arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        guard let output = await ProcessRunner.output(of: lsofExecutableURL, arguments: arguments) else { return [] }
        return output.split(whereSeparator: \.isNewline).compactMap { Int32($0) }
    }

    static func executablePath(ofProcess pid: Int32) async -> String? {
        let output = await ProcessRunner.output(of: psExecutableURL, arguments: ["-o", "comm=", "-p", String(pid)])
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func workingDirectory(ofProcess pid: Int32) async -> URL? {
        let arguments = ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]
        guard let output = await ProcessRunner.output(of: lsofExecutableURL, arguments: arguments),
              let pathLine = output.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("n") })
        else { return nil }
        return URL(fileURLWithPath: String(pathLine.dropFirst())).standardizedFileURL
    }

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
