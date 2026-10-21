import AppKit
import HeatWatchCore
@preconcurrency import UserNotifications

/// Shows heat alerts as notifications, or as an NSAlert when notifications are not allowed.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let category = "HEAT_ALERT"
    static let quitAction = "QUIT_APP"
    static let snoozeAction = "SNOOZE"

    var onQuit: ((_ bundlePath: String) -> Void)?
    var onSnooze: ((_ key: String) -> Void)?

    /// Nil when running outside an `.app` bundle (`swift run`), where UNUserNotificationCenter crashes.
    private let center: UNUserNotificationCenter?
    private var isShowingFallback = false

    override init() {
        center = Bundle.main.bundleIdentifier != nil ? UNUserNotificationCenter.current() : nil
        super.init()
    }

    func setUp() {
        guard let center else { return }
        center.delegate = self
        let quit = UNNotificationAction(identifier: Self.quitAction, title: "Quitter l'app", options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "Ignorer 1 h", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [quit, snooze], intentIdentifiers: []),
        ])
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            Log.alerts.notice("notification authorization granted=\(granted) error=\(String(describing: error), privacy: .public)")
        }
    }

    func show(_ alert: HeatAlert) {
        guard let center else { showFallback(alert); return }
        center.getNotificationSettings { settings in
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            Task { @MainActor in
                if allowed { self.post(alert, on: center) } else { self.showFallback(alert) }
            }
        }
    }

    private func post(_ alert: HeatAlert, on center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.subtitle = alert.subtitle
        content.body = alert.body
        content.sound = .default
        content.userInfo = ["appName": alert.culprit.name, "key": alert.culprit.key,
                            "bundlePath": alert.culprit.bundlePath ?? ""]
        // Only offer "Quitter" when quitting makes sense.
        if alert.explanation.canQuit { content.categoryIdentifier = Self.category }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            guard let error else { return }
            Log.alerts.error("notification failed: \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in self.showFallback(alert) }
        }
    }

    private func showFallback(_ alert: HeatAlert) {
        guard !isShowingFallback else { return }
        isShowingFallback = true
        defer { isShowingFallback = false }
        let panel = NSAlert()
        panel.alertStyle = .warning
        panel.messageText = alert.title
        panel.informativeText = ([alert.subtitle, alert.explanation.reason, alert.explanation.advice]
            + alert.explanation.context).joined(separator: "\n\n")
        let canQuit = alert.explanation.canQuit && alert.culprit.bundlePath != nil
        if canQuit { panel.addButton(withTitle: "Quitter \(alert.culprit.name)") }
        panel.addButton(withTitle: "Ignorer 1 h")
        panel.addButton(withTitle: "OK")
        NSApp.activate()
        let response = panel.runModal()
        let snoozeResponse: NSApplication.ModalResponse = canQuit ? .alertSecondButtonReturn : .alertFirstButtonReturn
        if canQuit, response == .alertFirstButtonReturn, let path = alert.culprit.bundlePath {
            onQuit?(path)
        } else if response == snoozeResponse {
            onSnooze?(alert.culprit.key)
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound]) // otherwise nothing shows while HeatWatch is frontmost
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        let key = info["key"] as? String ?? ""
        let path = info["bundlePath"] as? String ?? ""
        Task { @MainActor in
            switch action {
            case Self.quitAction where !path.isEmpty: self.onQuit?(path)
            case Self.snoozeAction: self.onSnooze?(key)
            default: break
            }
            completionHandler()
        }
    }
}
