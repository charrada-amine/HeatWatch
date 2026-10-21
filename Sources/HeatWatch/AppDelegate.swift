import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The MenuBarExtra content is only built when the menu opens, so monitoring starts here.
    @MainActor let model = MonitorModel()

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }
}
