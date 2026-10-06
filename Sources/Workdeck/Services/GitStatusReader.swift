import Foundation

enum GitStatusReader {
    private static let gitExecutableURL = URL(fileURLWithPath: "/usr/bin/git")

    static func status(of repository: URL) async -> GitStatus? {
        let arguments = ["-C", repository.path, "status", "--porcelain", "--branch"]
        guard let output = await ProcessRunner.output(of: gitExecutableURL, arguments: arguments) else { return nil }
        return GitStatus(porcelainOutput: output)
    }

    static func remoteWebURL(of repository: URL) async -> URL? {
        let arguments = ["-C", repository.path, "remote", "get-url", "origin"]
        guard let output = await ProcessRunner.output(of: gitExecutableURL, arguments: arguments) else { return nil }
        return webURL(fromRemote: output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func webURL(fromRemote remote: String) -> URL? {
        var address = remote
        if address.hasSuffix(".git") {
            address.removeLast(4)
        }

        if let components = URLComponents(string: address), let scheme = components.scheme, let host = components.host {
            guard ["https", "http", "ssh", "git"].contains(scheme) else { return nil }
            return URL(string: "https://\(host)\(components.path)")
        }

        guard let atIndex = address.firstIndex(of: "@"), let colonIndex = address.firstIndex(of: ":"), atIndex < colonIndex else {
            return nil
        }
        let host = address[address.index(after: atIndex)..<colonIndex]
        let path = address[address.index(after: colonIndex)...]
        return URL(string: "https://\(host)/\(path)")
    }
}
