import Foundation

public struct AppUsage: Equatable, Sendable {
    public let name: String
    /// Outermost `.app` bundle, e.g. `/Applications/Spotify.app`; nil for bare executables.
    public let bundlePath: String?
    /// Sum of the processes' CPU, in percent of one core.
    public let cpu: Double
    /// Sorted by decreasing CPU.
    public let processes: [ProcessSample]

    public init(name: String, bundlePath: String?, cpu: Double, processes: [ProcessSample]) {
        self.name = name
        self.bundlePath = bundlePath
        self.cpu = cpu
        self.processes = processes
    }

    /// Stable identity used for durations, cooldowns and snoozes.
    public var key: String { bundlePath ?? name }

    public var topProcess: ProcessSample? { processes.first }
}

public enum AppGrouping {
    /// ".../Spotify.app/Contents/Frameworks/Spotify Helper (Renderer).app/Contents/MacOS/Spotify Helper (Renderer)" → "Spotify"
    /// "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer" → "WindowServer"
    public static func appName(forExecutablePath path: String) -> String {
        if let range = path.range(of: ".app/") {
            return (String(path[..<range.lowerBound]) as NSString).lastPathComponent
        }
        return (path as NSString).lastPathComponent
    }

    /// The first `.app/` in the path is the outermost bundle, the app the user knows.
    public static func bundlePath(forExecutablePath path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    public static func group(_ samples: [ProcessSample]) -> [AppUsage] {
        var buckets: [String: (name: String, bundle: String?, processes: [ProcessSample])] = [:]
        var order: [String] = []
        for sample in samples {
            let bundle = bundlePath(forExecutablePath: sample.executablePath)
            let name = appName(forExecutablePath: sample.executablePath)
            let key = bundle ?? name
            if buckets[key] == nil {
                buckets[key] = (name, bundle, [])
                order.append(key)
            }
            buckets[key]!.processes.append(sample)
        }
        return order.compactMap { key -> AppUsage? in
            guard let bucket = buckets[key] else { return nil }
            let processes = bucket.processes.sorted { $0.cpu > $1.cpu }
            return AppUsage(name: bucket.name, bundlePath: bucket.bundle,
                            cpu: processes.reduce(0) { $0 + $1.cpu }, processes: processes)
        }
        .sorted { $0.cpu > $1.cpu }
    }
}
