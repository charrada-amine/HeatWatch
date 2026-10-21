import AppKit
import HeatWatchCore

@MainActor
final class MonitorModel: ObservableObject {
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var activeAlert: HeatAlert?
    @Published private(set) var level: HeatLevel = .normal

    let config: HeatConfig
    private let analyzer: HeatAnalyzer
    private var timer: Timer?
    private var isSampling = false

    init(config: HeatConfig = .default) {
        self.config = config
        self.analyzer = HeatAnalyzer(config: config)
    }

    func start() {
        guard timer == nil else { return }
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
        // Wired to the Notifier in milestone 4.
    }

    func snooze(key: String) {
        analyzer.snooze(key, now: Date())
        activeAlert = analyzer.activeAlert
        if let snapshot { level = analyzer.level(for: snapshot) }
    }

    func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}
