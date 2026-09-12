import Foundation

enum VSCodeWindowTitle {
    private static let separator = " — "
    private static let workspaceSuffix = " (Workspace)"
    private static let dirtyMarker = "● "
    private static let appName = "Visual Studio Code"

    static func projectName(from title: String, knownNames: Set<String>) -> String? {
        let parts = title.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix(dirtyMarker) ? String($0.dropFirst(dirtyMarker.count)) : $0 }
            .filter { !$0.isEmpty && $0 != appName }

        if let workspacePart = parts.last(where: { $0.hasSuffix(workspaceSuffix) }) {
            return String(workspacePart.dropLast(workspaceSuffix.count))
        }
        return parts.last(where: knownNames.contains) ?? parts.last
    }
}
