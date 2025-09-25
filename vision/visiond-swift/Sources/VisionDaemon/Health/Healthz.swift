import Foundation

final class Healthz {
    struct StageSample {
        var count: Int = 0
        var latencies: [Int] = []
        var firstSeen: Date?
        var lastSeen: Date?

        mutating func append(latency: Int, timestamp: Date) {
            count += 1
            latencies.append(latency)
            if latencies.count > 500 { latencies.removeFirst(latencies.count - 500) }
            if firstSeen == nil { firstSeen = timestamp }
            lastSeen = timestamp
        }

        func summary() -> [String: Any] {
            guard !latencies.isEmpty else { return ["count": count] }
            let sorted = latencies.sorted()
            let mean = Double(sorted.reduce(0, +)) / Double(sorted.count)
            let p95Idx = Int(Double(sorted.count - 1) * 0.95)
            let p95 = sorted[p95Idx]
            var output: [String: Any] = [
                "count": count,
                "latency_ms_mean": Int(mean),
                "latency_ms_p95": p95
            ]
            if let first = firstSeen, let last = lastSeen, last > first, count > 1 {
                let duration = last.timeIntervalSince(first)
                let fps = Double(count - 1) / duration
                output["fps"] = fps
            }
            return output
        }
    }

    private var stages: [String: [String: StageSample]] = [:]
    private let lock = NSLock()

    func record(pane: String, stage: String, latencyMs: Int, count: Int = 1, timestamp: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        var paneStages = stages[pane, default: [:]]
        var sample = paneStages[stage, default: StageSample()]
        for _ in 0..<max(1, count) {
            sample.append(latency: latencyMs, timestamp: timestamp)
        }
        paneStages[stage] = sample
        stages[pane] = paneStages
    }

    func snapshot() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        var panes: [String: Any] = [:]
        for (pane, stageMap) in stages {
            var stageSummaries: [String: Any] = [:]
            for (stage, sample) in stageMap {
                stageSummaries[stage] = sample.summary()
            }
            panes[pane] = stageSummaries
        }
        return [
            "status": "ok",
            "panes": panes
        ]
    }
}

