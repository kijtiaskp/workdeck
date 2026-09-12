import AppKit

enum WorkspaceOpener {
    static func open(_ url: URL) {
        let editorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: VSCode.bundleIdentifier) ?? VSCode.fallbackAppURL
        NSWorkspace.shared.open([url], withApplicationAt: editorURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
