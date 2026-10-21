import AppKit
import HeatWatchCore
import ServiceManagement

@MainActor
final class MonitorModel: ObservableObject {
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var activeAlert: HeatAlert?
    @Published private(set) var level: HeatLevel = .normal
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var launchAtLoginError: String?

    let config: HeatConfig
    private let analyzer: HeatAnalyzer
    private var timer: Timer?
    private var isSampling = false
    private let notifier = Notifier()

    init(config: HeatConfig = .default) {
        self.config = config
        self.analyzer = HeatAnalyzer(config: config)
    }

    func start() {
        guard timer == nil else { return }
        notifier.onQuit = { [weak self] path in self?.quitApp(bundlePath: path) }
        notifier.onSnooze = { [weak self] key in self?.snooze(key: key) }
        notifier.setUp()
        let timer = Timer(timeInterval: config.sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common) // keep sampling while the menu is open
        self.timer = timer
        sample()
    }

    /// Measures off the main thread; skips a tick if the previous measurement is still running.
    func sample() {
        guard !isSampling else { return }
        isSampling = true
        Task {
            let snapshot = await Task.detached(priority: .utility) { Snapshot.capture() }.value
            self.apply(snapshot)
            self.isSampling = false
        }
    }

    private func apply(_ snapshot: Snapshot) {
        self.snapshot = snapshot
        let newAlert = analyzer.process(snapshot)
        activeAlert = analyzer.activeAlert
        level = analyzer.level(for: snapshot)
        if let newAlert { notify(newAlert) }
    }

    func notify(_ alert: HeatAlert) {
        Log.alerts.notice("alert culprit=\(alert.culprit.name, privacy: .public) cpu=\(Int(alert.culprit.cpu)) min=\(alert.minutesAbove) canQuit=\(alert.explanation.canQuit) reason=\(alert.explanation.reason, privacy: .public)")
        notifier.show(alert)
    }

    /// Same path as a real alert, with a fake culprit that has no bundle (so no "Quitter" button).
    func sendTestAlert() {
        let culprit = AppUsage(name: "Test", bundlePath: nil, cpu: 130, processes: [])
        let alert = HeatAlert(culprit: culprit,
                              explanation: Explainer.explain(culprit, minutes: 4, snapshot: snapshot),
                              cpuTemperature: snapshot?.cpuTemperature, minutesAbove: 4, date: Date())
        notify(alert)
    }

    func snooze(key: String) {
        analyzer.snooze(key, now: Date())
        activeAlert = analyzer.activeAlert
        if let snapshot { level = analyzer.level(for: snapshot) }
    }

    func quitApp(bundlePath: String) {
        let quit = AppTerminator.quit(bundlePath: bundlePath)
        Log.alerts.notice("quit \(bundlePath, privacy: .public) sent=\(quit)")
        if quit, activeAlert?.culprit.bundlePath == bundlePath {
            analyzer.clearActiveAlert()
            activeAlert = nil
            if let snapshot { level = analyzer.level(for: snapshot) }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            // Can fail with an ad hoc signature: the README explains the manual setup.
            launchAtLoginError = "Impossible de modifier l'ouverture au démarrage : \(error.localizedDescription) "
                + "Ajoute HeatWatch à la main dans Réglages Système › Général › Ouverture."
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        if status == .requiresApproval {
            launchAtLoginError = "Autorise HeatWatch dans Réglages Système › Général › Ouverture."
            SMAppService.openSystemSettingsLoginItems()
        }
        Log.alerts.notice("launch at login requested=\(enabled) status=\(status.rawValue)")
    }

    func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}
