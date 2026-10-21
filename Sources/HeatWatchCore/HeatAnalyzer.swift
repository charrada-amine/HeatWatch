import Foundation

public enum HeatLevel: Equatable {
    case normal, warm, hot

    public var label: String {
        switch self {
        case .normal: return "Normal"
        case .warm: return "Tiède"
        case .hot: return "Chaud"
        }
    }
}

public struct HeatAlert: Equatable, Sendable {
    public let culprit: AppUsage
    public let explanation: Explanation
    public let cpuTemperature: Double?
    public let minutesAbove: Int
    public let date: Date

    public init(culprit: AppUsage, explanation: Explanation, cpuTemperature: Double?, minutesAbove: Int, date: Date) {
        self.culprit = culprit
        self.explanation = explanation
        self.cpuTemperature = cpuTemperature
        self.minutesAbove = minutesAbove
        self.date = date
    }

    /// "Ton Mac chauffe (78 °C)"
    public var title: String {
        if let temp = cpuTemperature { return "Ton Mac chauffe (\(Int(temp.rounded())) °C)" }
        return "Ton Mac chauffe"
    }

    /// "Spotify : 130 % du processeur depuis 4 min"
    public var subtitle: String {
        "\(culprit.name) : \(Int(culprit.cpu.rounded())) % du processeur depuis \(minutesAbove) min"
    }

    public var body: String {
        "\(explanation.reason) \(explanation.advice)"
    }
}

/// Decides when to alert. Pure logic: time always comes from the snapshots.
public final class HeatAnalyzer {
    public var config: HeatConfig
    public private(set) var activeAlert: HeatAlert?

    private var appAboveSince: [String: Date] = [:]
    private var tempAboveSince: Date?
    private var lastAlert: [String: Date] = [:]
    private var snoozedUntil: [String: Date] = [:]

    public init(config: HeatConfig = .default) {
        self.config = config
    }

    public func level(for snapshot: Snapshot) -> HeatLevel {
        if activeAlert != nil { return .hot }
        guard let temp = snapshot.cpuTemperature else { return .normal }
        if temp >= config.tempHot { return .hot }
        if temp >= config.tempWarm { return .warm }
        return .normal
    }

    /// Feeds one snapshot. Returns an alert only when a new notification should be shown.
    @discardableResult
    public func process(_ snapshot: Snapshot) -> HeatAlert? {
        let now = snapshot.date

        // Track how long each app has been above the CPU threshold.
        var stillAbove: [String: Date] = [:]
        for app in snapshot.apps where app.cpu >= config.appCPUThreshold {
            stillAbove[app.key] = appAboveSince[app.key] ?? now
        }
        appAboveSince = stillAbove

        if let temp = snapshot.cpuTemperature, temp >= config.tempAlert {
            tempAboveSince = tempAboveSince ?? now
        } else {
            tempAboveSince = nil
        }

        guard let (culprit, minutes) = trigger(in: snapshot) else {
            activeAlert = nil
            return nil
        }

        let alert = HeatAlert(culprit: culprit,
                              explanation: Explainer.explain(culprit, minutes: minutes, snapshot: snapshot),
                              cpuTemperature: snapshot.cpuTemperature,
                              minutesAbove: minutes,
                              date: now)

        if let until = snoozedUntil[culprit.key], now < until {
            if activeAlert?.culprit.key == culprit.key { activeAlert = nil }
            return nil
        }
        if let last = lastAlert[culprit.key], now.timeIntervalSince(last) < config.alertCooldown {
            // Keep the menu up to date without notifying again.
            if activeAlert?.culprit.key == culprit.key { activeAlert = alert }
            return nil
        }
        lastAlert[culprit.key] = now
        activeAlert = alert
        return alert
    }

    /// "Ignorer 1 h": no alert for this app until `now + snoozeDuration`.
    public func snooze(_ key: String, now: Date) {
        snoozedUntil[key] = now.addingTimeInterval(config.snoozeDuration)
        if activeAlert?.culprit.key == key { activeAlert = nil }
    }

    public func clearActiveAlert() {
        activeAlert = nil
    }

    private func trigger(in snapshot: Snapshot) -> (AppUsage, Int)? {
        let now = snapshot.date
        let sustained = snapshot.apps.filter { app in
            guard let since = appAboveSince[app.key] else { return false }
            return now.timeIntervalSince(since) >= config.appSustained
        }
        if let app = sustained.max(by: { $0.cpu < $1.cpu }) {
            return (app, minutes(since: appAboveSince[app.key], now: now))
        }
        guard let top = snapshot.apps.first else { return nil }
        if let since = tempAboveSince, now.timeIntervalSince(since) >= config.tempSustained {
            return (top, minutes(since: since, now: now))
        }
        if snapshot.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            return (top, minutes(since: appAboveSince[top.key] ?? tempAboveSince, now: now))
        }
        return nil
    }

    private func minutes(since: Date?, now: Date) -> Int {
        guard let since else { return 0 }
        return Int(now.timeIntervalSince(since) / 60)
    }
}
