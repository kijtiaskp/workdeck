import AppKit

enum WorkspaceOpener {
    private static let vscodeBundleIdentifier = "com.microsoft.VSCode"
    private static let vscodeFallbackURL = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")

    static func open(_ workspace: Workspace) {
        let editorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: vscodeBundleIdentifier) ?? vscodeFallbackURL
        NSWorkspace.shared.open([workspace.url], withApplicationAt: editorURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
