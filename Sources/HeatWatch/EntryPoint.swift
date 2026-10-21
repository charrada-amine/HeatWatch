import HeatWatchCore

@main
enum EntryPoint {
    static func main() {
        if CommandLine.arguments.contains("--probe") { Probe.run(); return }
    }
}
