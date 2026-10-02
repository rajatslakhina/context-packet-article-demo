import XCTest
@testable import ContextPacket

final class CompilerTests: XCTestCase {
    let compiler = PacketCompiler()
    let repo = SampleMonorepo.repository
    let diff = SampleMonorepo.diff
    let tools = SampleMonorepo.tools
    let findings = SampleMonorepo.findings

    func packet(_ strategy: Strategy, _ budget: Int) throws -> Packet {
        try compiler.compile(strategy, repo: repo, diff: diff, tools: tools, budget: budget)
    }

    func testNoStrategyEverExceedsTheBudget() throws {
        for strategy in Strategy.allCases {
            for budget in stride(from: diff.tokens, through: 120_000, by: 1_337) {
                let p = try packet(strategy, budget)
                XCTAssertLessThanOrEqual(p.usedTokens, budget, "\(strategy) at \(budget)")
                XCTAssertEqual(p.included.first?.kind, .diff, "the diff is always first")
            }
        }
    }

    func testDiffLargerThanBudgetThrows() {
        XCTAssertThrowsError(try packet(.contract, diff.tokens - 1)) { error in
            XCTAssertEqual(error as? CompileError,
                           .diffExceedsBudget(diffTokens: diff.tokens, budget: diff.tokens - 1))
        }
    }

    func testUnknownChangedFileThrows() {
        let bad = Diff(changedFiles: [ChangedFile(path: "Nope/Missing.swift", hunkTokens: 10)],
                       changedPublicSymbols: [])
        XCTAssertThrowsError(try compiler.compile(.contract, repo: repo, diff: bad, tools: tools, budget: 10_000)) {
            XCTAssertEqual($0 as? CompileError, .unknownFile("Nope/Missing.swift"))
        }
    }

    func testEmptyDiffStillCompiles() throws {
        let empty = Diff(changedFiles: [], changedPublicSymbols: [])
        let p = try compiler.compile(.contract, repo: repo, diff: empty, tools: tools, budget: 5_000)
        XCTAssertEqual(p.included.first?.tokens, 0)
        // Only the root rules apply when no module is touched.
        XCTAssertEqual(p.included.filter { $0.kind == .rules }.map(\.id), ["CLAUDE.md"])
        XCTAssertTrue(p.included.filter { $0.kind == .callSite }.isEmpty)
    }

    func testContractIncludesCallersOutsideTouchedModules() throws {
        let p = try packet(.contract, SampleMonorepo.defaultBudget)
        let callers = p.included.filter { $0.kind == .callSite }.map(\.id)
        XCTAssertTrue(callers.contains("Networking.APIClient.send @ FeatureProfile/ProfileLoader.swift"))
        XCTAssertTrue(callers.contains("Networking.APIClient.send @ FeatureOrders/OrderHistoryService.swift"))
        // Files in the diff are never repeated as call sites.
        XCTAssertFalse(callers.contains { $0.hasSuffix("FeatureCheckout/CheckoutService.swift") })
    }

    func testContractInterfacesAreCrossModuleOnly() throws {
        let p = try packet(.contract, SampleMonorepo.defaultBudget)
        let ids = Set(p.included.filter { $0.kind == .interface }.map(\.id))
        XCTAssertEqual(ids, ["Analytics.Tracker.log(raw:)", "CoreModels.Money.init(double:)",
                             "Networking.APIClient.send"])
        // APIClient.swift uses RetryPolicy from its own module: not stubbed.
        XCTAssertFalse(ids.contains("Networking.RetryPolicy"))
    }

    func testContractDropsWriteAndDeployTools() throws {
        let p = try packet(.contract, SampleMonorepo.defaultBudget)
        let names = p.included.filter { $0.kind == .tool }.map(\.id)
        XCTAssertTrue(names.contains("Read"))
        XCTAssertFalse(names.contains("Edit"))
        XCTAssertFalse(names.contains("github.create_review_comment"), "review + write is still write")
        XCTAssertFalse(names.contains("github.merge_pull_request"))
    }

    func testCallSiteExcerptIsCappedByFileSize() {
        let tiny = SourceFile(path: "X/Tiny.swift", module: "X", tokens: 40, references: ["Networking.APIClient.send"])
        let small = Repository(files: repo.files + [tiny], symbols: repo.symbols,
                               monolithicRules: repo.monolithicRules, scopedRules: repo.scopedRules)
        let items = compiler.callSiteItems(repo: small, diff: diff)
        XCTAssertEqual(items.first { $0.id.hasSuffix("X/Tiny.swift") }?.tokens, 40)
    }
}

final class CoverageTests: XCTestCase {
    let compiler = PacketCompiler()
    let S = SampleMonorepo.self

    func covered(_ strategy: Strategy, _ budget: Int) throws -> [String] {
        try compiler.compile(strategy, repo: S.repository, diff: S.diff, tools: S.tools, budget: budget)
            .coverage(of: S.findings).filter(\.isCoverable).map(\.id)
    }

    func testHeadlineNumbersAtDefaultBudget() throws {
        let contract = try compiler.compile(.contract, repo: S.repository, diff: S.diff, tools: S.tools, budget: 32_000)
        XCTAssertEqual(contract.usedTokens, 10_870)
        XCTAssertEqual(try covered(.contract, 32_000), ["F1", "F2", "F3", "F4", "F5"])

        let whole = try compiler.compile(.wholeModules, repo: S.repository, diff: S.diff, tools: S.tools, budget: 32_000)
        XCTAssertEqual(whole.tokens(of: .file), 0, "tool schemas and the big CLAUDE.md fill the budget first")
        XCTAssertEqual(whole.tokens(of: .tool), 20_700)
        XCTAssertEqual(try covered(.wholeModules, 32_000), ["F2"])
        XCTAssertEqual(try covered(.diffOnly, 32_000), ["F2"])
    }

    func testMoreBudgetDoesNotFixSelection() throws {
        let whole = try compiler.compile(.wholeModules, repo: S.repository, diff: S.diff, tools: S.tools, budget: 200_000)
        XCTAssertEqual(whole.usedTokens, 77_460)
        XCTAssertTrue(whole.evicted.isEmpty)
        // Callers in FeatureProfile and FeatureOrders are never selected, at any budget.
        XCTAssertEqual(try covered(.wholeModules, 200_000), ["F2", "F5"])
        XCTAssertEqual(try covered(.wholeModules, 1_000_000), ["F2", "F5"])
    }

    func testEvictionOrderDecidesTightBudgets() throws {
        XCTAssertEqual(try covered(.contract, 8_000), ["F1", "F2", "F3", "F4", "F5"])
        XCTAssertEqual(try covered(.contractToolsFirst, 8_000), ["F2", "F4"])
        XCTAssertEqual(try covered(.contract, 6_000), ["F1", "F2", "F3", "F4", "F5"])
    }

    func testMissingEvidenceIsReported() throws {
        let p = try compiler.compile(.diffOnly, repo: S.repository, diff: S.diff, tools: S.tools, budget: 32_000)
        let f1 = try XCTUnwrap(p.coverage(of: S.findings).first { $0.id == "F1" })
        XCTAssertFalse(f1.isCoverable)
        XCTAssertEqual(f1.missing.count, 2)
    }

    func testSweepReportsNilBelowDiffSize() {
        let points = compiler.sweep(.contract, repo: S.repository, diff: S.diff, tools: S.tools,
                                    findings: S.findings, budgets: [1_000, 32_000])
        XCTAssertNil(points.first?.packet)
        XCTAssertEqual(points.first?.coverable, 0)
        XCTAssertEqual(points.last?.coverable, 5)
    }
}

final class ManifestTests: XCTestCase {
    func testManifestAndFingerprintAreDeterministic() throws {
        let c = PacketCompiler()
        let S = SampleMonorepo.self
        let a = try c.compile(.contract, repo: S.repository, diff: S.diff, tools: S.tools, budget: 32_000)
        let b = try c.compile(.contract, repo: S.repository, diff: S.diff, tools: S.tools, budget: 32_000)
        XCTAssertEqual(a.manifest, b.manifest)
        XCTAssertEqual(a.fingerprint, b.fingerprint)
        XCTAssertEqual(a.fingerprint.count, 16)
        XCTAssertTrue(a.manifest.hasPrefix("# context-packet v1\nstrategy: contract\nbudget: 32000\nused: 10870"))

        let tight = try c.compile(.contract, repo: S.repository, diff: S.diff, tools: S.tools, budget: 6_000)
        XCTAssertNotEqual(a.fingerprint, tight.fingerprint)
        XCTAssertTrue(tight.manifest.contains("[evicted]"))
    }
}
