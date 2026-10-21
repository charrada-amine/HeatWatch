import AppKit

enum AppTerminator {
    /// Politely asks every running instance of the bundle to quit (never force-terminates).
    /// Returns false when the target is refused or not running.
    @discardableResult
    static func quit(bundlePath: String) -> Bool {
        guard isAllowed(bundlePath) else { return false }
        let target = URL(fileURLWithPath: bundlePath).standardizedFileURL
        let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.standardizedFileURL == target }
        apps.forEach { $0.terminate() } // never forceTerminate automatically
        return !apps.isEmpty
    }

    static func isAllowed(_ bundlePath: String) -> Bool {
        if bundlePath.hasPrefix("/System/") { return false }
        let target = URL(fileURLWithPath: bundlePath).standardizedFileURL
        if target == Bundle.main.bundleURL.standardizedFileURL { return false }
        if target.lastPathComponent == "HeatWatch.app" { return false }
        return true
    }
}
