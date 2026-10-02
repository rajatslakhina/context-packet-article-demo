// Coverage is a necessary condition, not a model benchmark: a reviewer cannot
// flag a broken caller it never saw. This file checks whether the evidence a
// finding needs is in the packet at all. It says nothing about whether a given
// model would notice it once it is there.

public struct Finding: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let requires: Set<Evidence>

    public init(id: String, title: String, requires: Set<Evidence>) {
        self.id = id
        self.title = title
        self.requires = requires
    }
}

public struct FindingCoverage: Sendable, Identifiable {
    public let finding: Finding
    public let missing: [Evidence]

    public var id: String { finding.id }
    public var isCoverable: Bool { missing.isEmpty }
}

public extension Packet {
    func coverage(of findings: [Finding]) -> [FindingCoverage] {
        let have = evidence
        return findings.map { finding in
            let missing = finding.requires.subtracting(have).sorted { $0.description < $1.description }
            return FindingCoverage(finding: finding, missing: missing)
        }
    }

    func coverableCount(of findings: [Finding]) -> Int {
        coverage(of: findings).filter(\.isCoverable).count
    }
}

/// One row of a budget sweep. `packet` is nil when the diff alone exceeds the budget.
public struct SweepPoint: Sendable, Identifiable {
    public let budget: Int
    public let packet: Packet?
    public let coverable: Int

    public var id: Int { budget }
}

public extension PacketCompiler {
    func sweep(_ strategy: Strategy, repo: Repository, diff: Diff, tools: [Tool],
               findings: [Finding], budgets: [Int]) -> [SweepPoint] {
        budgets.map { budget in
            guard let packet = try? compile(strategy, repo: repo, diff: diff, tools: tools, budget: budget) else {
                return SweepPoint(budget: budget, packet: nil, coverable: 0)
            }
            return SweepPoint(budget: budget, packet: packet, coverable: packet.coverableCount(of: findings))
        }
    }
}
