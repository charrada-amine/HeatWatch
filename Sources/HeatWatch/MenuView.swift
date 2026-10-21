import SwiftUI
import HeatWatchCore

struct MenuView: View {
    @ObservedObject var model: MonitorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let alert = model.activeAlert {
                AlertBox(alert: alert, model: model)
            }
            topApps
            context
            Divider()
            actions
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Processeur : \(celsius(model.snapshot?.cpuTemperature)) · \(model.level.label)")
                .font(.headline)
            Text("Batterie : \(celsius(model.snapshot?.batteryTemperature))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var topApps: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ce qui consomme le plus")
                .font(.subheadline.weight(.semibold))
            if let apps = model.snapshot?.apps.prefix(5), !apps.isEmpty {
                ForEach(Array(apps), id: \.key) { app in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(app.name).lineLimit(1)
                            Spacer()
                            Text("\(Int(app.cpu.rounded())) %").monospacedDigit()
                        }
                        .font(.callout)
                        ProgressView(value: min(app.cpu, 200), total: 200)
                            .progressViewStyle(.linear)
                    }
                }
            } else {
                Text("Mesure en cours…").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var context: some View {
        if let snapshot = model.snapshot {
            let lines = Explainer.contextLines(for: snapshot)
            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines, id: \.self) { line in
                        Text(line).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Ouvrir le Moniteur d'activité") { model.openActivityMonitor() }
            Button("Quitter HeatWatch") { NSApp.terminate(nil) }
        }
        .buttonStyle(.link)
    }

    private func celsius(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded())) °C" } ?? "-- °C"
    }
}

struct AlertBox: View {
    let alert: HeatAlert
    @ObservedObject var model: MonitorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Ton Mac chauffe", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(alert.subtitle).font(.callout.weight(.medium))
            Text(alert.explanation.reason).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(alert.explanation.advice).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Ignorer 1 h") { model.snooze(key: alert.culprit.key) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
