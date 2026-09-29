import Foundation

enum ProcessRunner {
    static func output(of executableURL: URL, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let outputPipe = Pipe()
                process.executableURL = executableURL
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
