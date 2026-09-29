import Foundation

enum GitStatusReader {
    private static let gitExecutableURL = URL(fileURLWithPath: "/usr/bin/git")

    static func status(of repository: URL) async -> GitStatus? {
        let arguments = ["-C", repository.path, "status", "--porcelain", "--branch"]
        guard let output = await ProcessRunner.output(of: gitExecutableURL, arguments: arguments) else { return nil }
        return GitStatus(porcelainOutput: output)
    }
}
