import Foundation

enum GitStatusReader {
    private static let gitExecutableURL = URL(fileURLWithPath: "/usr/bin/git")

    static func status(of repository: URL) async -> GitStatus? {
        let arguments = ["-C", repository.path, "status", "--porcelain", "--branch"]
        guard let output = await runGit(arguments: arguments) else { return nil }
        return GitStatus(porcelainOutput: output)
    }

    private static func runGit(arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let outputPipe = Pipe()
                process.executableURL = gitExecutableURL
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let succeeded = process.terminationStatus == 0
                continuation.resume(returning: succeeded ? String(decoding: output, as: UTF8.self) : nil)
            }
        }
    }
}
