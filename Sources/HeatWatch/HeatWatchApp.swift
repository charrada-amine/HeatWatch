import SwiftUI
import HeatWatchCore

struct HeatWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: appDelegate.model)
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: MonitorModel

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
            if model.activeAlert != nil {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            Text(model.snapshot?.cpuTemperature.map { "\(Int($0.rounded()))°" } ?? "--°")
        }
    }

    private var symbol: String {
        switch model.level {
        case .normal: return "thermometer.low"
        case .warm: return "thermometer.medium"
        case .hot: return "thermometer.high"
        }
    }
}
