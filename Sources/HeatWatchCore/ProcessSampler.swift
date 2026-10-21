import Foundation

public struct ProcessSample: Equatable, Sendable {
    public let pid: Int32
    public let cpu: Double
    public let executablePath: String
    /// Last path component of the executable.
    public let processName: String

    public init(pid: Int32, cpu: Double, executablePath: String) {
        self.pid = pid
        self.cpu = cpu
        self.executablePath = executablePath
        self.processName = (executablePath as NSString).lastPathComponent
    }
}

public enum ProcessSampler {
    /// Runs `ps` (setuid root, so it sees every process) and parses its output.
    public static func sample() -> [ProcessSample] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Ao", "pid=,pcpu=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile() // read BEFORE waitUntilExit, or it can block
        process.waitUntilExit()
        return parse(String(decoding: data, as: UTF8.self))
    }

    public static func parse(_ output: String) -> [ProcessSample] {
        var samples: [ProcessSample] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = Int32(parts[0]), let cpu = Double(parts[1]) else { continue }
            let path = parts[2].trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else { continue }
            samples.append(ProcessSample(pid: pid, cpu: cpu, executablePath: path))
        }
        return samples
    }
}
