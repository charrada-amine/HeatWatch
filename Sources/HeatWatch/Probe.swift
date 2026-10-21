import Foundation
import HeatWatchCore

/// Text-only mode (`HeatWatch --probe`) used to check each milestone without clicking.
enum Probe {
    static func run() {
        let snapshot = Snapshot.capture()
        print("Processeur : \(format(snapshot.cpuTemperature))")
        print("Batterie   : \(format(snapshot.batteryTemperature))")
        print("Capteurs   : \(snapshot.sensorCount)")
        print("Processus  : \(snapshot.processCount)")
        print("Apps les plus gourmandes :")
        for app in snapshot.apps.prefix(5) {
            let top = app.topProcess.map { "\($0.processName) \(String(format: "%.1f", $0.cpu)) %" } ?? "-"
            print(String(format: "  %6.1f %%  ", app.cpu) + "\(app.name)  [\(app.processes.count) proc., max : \(top)]"
                  + (app.bundlePath.map { "  \($0)" } ?? ""))
        }
        if let battery = snapshot.battery {
            print("Batterie   : \(battery.percent) %, en charge : \(battery.isCharging ? "oui" : "non"), secteur : \(battery.onAC ? "oui" : "non")")
        } else {
            print("Batterie   : inconnue")
        }
        if let days = snapshot.daysSinceBoot {
            print(String(format: "Démarrage  : il y a %.1f jours", days))
        }
        print("thermalState : \(describe(snapshot.thermalState))")
        if let top = snapshot.apps.first {
            let explanation = Explainer.explain(top, minutes: 0, snapshot: snapshot)
            print("Explication pour \(top.name) :")
            print("  Raison  : \(explanation.reason)")
            print("  Conseil : \(explanation.advice)")
            print("  Quitter possible : \(explanation.canQuit ? "oui" : "non")")
            explanation.context.forEach { print("  Contexte : \($0)") }
        }
    }

    static func format(_ celsius: Double?) -> String {
        celsius.map { String(format: "%.1f °C", $0) } ?? "inconnue"
    }

    static func describe(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "inconnu"
        }
    }
}
