// A packet is a build artifact, so it gets a manifest you can diff in a PR,
// the same way a lockfile makes dependency resolution reviewable.

public extension Packet {
    /// A stable, line-oriented description of the packet. Same inputs, same text.
    var manifest: String {
        var lines = ["# context-packet v1",
                     "strategy: \(strategy.rawValue)",
                     "budget: \(budget)",
                     "used: \(usedTokens)"]
        for kind in ContextItem.Kind.allCases {
            let items = included.filter { $0.kind == kind }
            guard !items.isEmpty else { continue }
            lines.append("[\(kind.rawValue)] \(items.reduce(0) { $0 + $1.tokens })")
            for item in items {
                lines.append("  + \(item.id) \(item.tokens)")
            }
        }
        if !evicted.isEmpty {
            lines.append("[evicted] \(evicted.reduce(0) { $0 + $1.tokens })")
            for item in evicted {
                lines.append("  - \(item.kind.rawValue) \(item.id) \(item.tokens)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// FNV-1a over the manifest. Deliberately not `Hasher`, which is seeded per
    /// process, so the same packet would fingerprint differently on every run.
    var fingerprint: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in manifest.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}
