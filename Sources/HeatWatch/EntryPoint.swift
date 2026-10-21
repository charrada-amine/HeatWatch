import HeatWatchCore

@main
enum EntryPoint {
    static func main() {
        print(HeatConfig.default.sampleInterval)
    }
}
