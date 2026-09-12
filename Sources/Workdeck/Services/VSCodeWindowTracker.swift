import AppKit
import ApplicationServices

@MainActor
final class VSCodeWindowTracker: ObservableObject {
    private static let pollInterval: TimeInterval = 0.75
    private static let knownNamesLifetime: TimeInterval = 60

    @Published private(set) var activeProjectName: String?

    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var knownNames: Set<String> = []
    private var knownNamesUpdatedAt = Date.distantPast

    init() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }

        let notificationCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard application?.bundleIdentifier == VSCode.bundleIdentifier else { return }
                MainActor.assumeIsolated { self?.activeProjectName = nil }
            },
        ]
    }

    private func refresh() {
        guard MenuBarLabelStyle.current.showsText,
              AccessibilityPermission.isGranted,
              let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.bundleIdentifier == VSCode.bundleIdentifier,
              let title = focusedWindowTitle(of: frontmostApplication.processIdentifier)
        else { return }

        let projectName = VSCodeWindowTitle.projectName(from: title, knownNames: currentKnownNames())
        if projectName != activeProjectName {
            activeProjectName = projectName
        }
    }

    private func focusedWindowTitle(of processIdentifier: pid_t) -> String? {
        let application = AXUIElementCreateApplication(processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let focusedWindow
        else { return nil }

        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success
        else { return nil }
        return title as? String
    }

    private func currentKnownNames() -> Set<String> {
        guard Date().timeIntervalSince(knownNamesUpdatedAt) > Self.knownNamesLifetime else { return knownNames }

        let roots = ScanRoots.all
        let workspaceNames = roots.flatMap { WorkspaceScanner(root: $0).scan().map(\.name) }
        let repositoryNames = roots.flatMap { GitRepositoryScanner(root: $0).scan().map(\.name) }
        knownNames = Set(workspaceNames + repositoryNames)
        knownNamesUpdatedAt = Date()
        return knownNames
    }
}
