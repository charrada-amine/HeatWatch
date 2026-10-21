import HeatWatchCore

@main
enum EntryPoint {
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--probe") { Probe.run(); return }
        if let index = arguments.firstIndex(of: "--launch-at-login") {
            LoginItem.runCommand(arguments.dropFirst(index + 1).first)
            return
        }
        HeatWatchApp.main()
    }
}
