import SwiftUI
import ContextPacket

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Launch arguments (used by CI to take screenshots):
///   -strategy wholeModules|diffOnly|contract|contractToolsFirst
///   -budget 32000
///   -compare YES   (opens the side-by-side comparison)
struct RootView: View {
    @State private var strategy: Strategy
    @State private var budget: Double
    @State private var showCompare: Bool

    init() {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: "strategy") ?? Strategy.contract.rawValue
        _strategy = State(initialValue: Strategy(rawValue: raw) ?? .contract)
        let argBudget = defaults.integer(forKey: "budget")
        let clamped = argBudget > 0 ? min(max(argBudget, 2_000), 200_000) : SampleMonorepo.defaultBudget
        _budget = State(initialValue: Double(clamped))
        _showCompare = State(initialValue: defaults.bool(forKey: "compare"))
    }

    var body: some View {
        NavigationStack {
            Group {
                if showCompare {
                    CompareView(budget: Int(budget))
                } else {
                    PacketView(strategy: strategy, budget: Int(budget))
                }
            }
            .safeAreaInset(edge: .top) { controls }
            .navigationTitle("Reviewer context")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("View", selection: $showCompare) {
                Text("One packet").tag(false)
                Text("Compare").tag(true)
            }
            .pickerStyle(.segmented)
            if !showCompare {
                Picker("Strategy", selection: $strategy) {
                    ForEach(Strategy.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
            }
            HStack {
                Text("Budget").font(.caption.weight(.semibold))
                Slider(value: $budget, in: 2_000...200_000, step: 1_000)
                Text(Int(budget).formatted()).font(.caption.monospacedDigit()).frame(width: 64, alignment: .trailing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - One packet

struct PacketView: View {
    let strategy: Strategy
    let budget: Int

    private var result: Result<Packet, CompileError> {
        do {
            return .success(try PacketCompiler().compile(strategy, repo: SampleMonorepo.repository,
                                                         diff: SampleMonorepo.diff,
                                                         tools: SampleMonorepo.tools, budget: budget))
        } catch let error as CompileError {
            return .failure(error)
        } catch {
            return .failure(.unknownFile("unexpected error"))
        }
    }

    var body: some View {
        List {
            switch result {
            case .failure(let error):
                Section { Text(message(for: error)).foregroundStyle(.red) }
            case .success(let packet):
                Section("Budget") { BudgetBar(packet: packet) }
                Section("Seeded findings: is the evidence in the window?") {
                    ForEach(packet.coverage(of: SampleMonorepo.findings)) { FindingRow(coverage: $0) }
                }
                Section("Manifest · \(packet.fingerprint)") {
                    Text(packet.manifest)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func message(for error: CompileError) -> String {
        switch error {
        case .diffExceedsBudget(let diffTokens, let budget):
            return "The diff alone is \(diffTokens) tokens, more than the \(budget)-token budget."
        case .unknownFile(let path):
            return "Unknown file in diff: \(path)"
        }
    }
}

struct BudgetBar: View {
    let packet: Packet

    static let kinds: [(ContextItem.Kind, Color)] = [
        (.diff, .orange), (.rules, .purple), (.interface, .teal),
        (.callSite, .green), (.file, .blue), (.tool, .gray)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(packet.usedTokens.formatted()) of \(packet.budget.formatted()) tokens")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("\(packet.coverableCount(of: SampleMonorepo.findings))/\(SampleMonorepo.findings.count) coverable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(packet.coverableCount(of: SampleMonorepo.findings) == SampleMonorepo.findings.count ? .green : .red)
            }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(Self.kinds, id: \.0) { entry in
                        let tokens = packet.tokens(of: entry.0)
                        if tokens > 0 {
                            entry.1.frame(width: geo.size.width * CGFloat(tokens) / CGFloat(max(packet.budget, 1)))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 14)
            FlowLegend(packet: packet)
            if !packet.evicted.isEmpty {
                Text("Evicted for budget: \(packet.evicted.count) items, \(packet.evicted.reduce(0) { $0 + $1.tokens }.formatted()) tokens")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FlowLegend: View {
    let packet: Packet

    var body: some View {
        let entries = BudgetBar.kinds.filter { packet.tokens(of: $0.0) > 0 }
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entries, id: \.0) { entry in
                HStack(spacing: 6) {
                    Circle().fill(entry.1).frame(width: 8, height: 8)
                    Text(entry.0.rawValue).font(.caption)
                    Spacer()
                    Text(packet.tokens(of: entry.0).formatted()).font(.caption.monospacedDigit())
                }
            }
        }
    }
}

struct FindingRow: View {
    let coverage: FindingCoverage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: coverage.isCoverable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(coverage.isCoverable ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(coverage.finding.id) · \(coverage.finding.title)").font(.subheadline)
                if !coverage.missing.isEmpty {
                    Text("missing: " + coverage.missing.map(\.description).joined(separator: ", "))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Comparison

struct CompareView: View {
    let budget: Int

    private var rows: [(Strategy, Packet?)] {
        Strategy.allCases.map { strategy in
            (strategy, try? PacketCompiler().compile(strategy, repo: SampleMonorepo.repository,
                                                    diff: SampleMonorepo.diff,
                                                    tools: SampleMonorepo.tools, budget: budget))
        }
    }

    var body: some View {
        List {
            Section("Same diff, same \(budget.formatted())-token budget") {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.0.title).font(.headline)
                        if let packet = row.1 {
                            BudgetBar(packet: packet)
                        } else {
                            Text("Diff does not fit the budget").foregroundStyle(.red)
                        }
                    }
                }
            }
            Section {
                Text("Coverage means the evidence a finding needs is in the window. It is a necessary condition for a reviewer agent to flag it, not proof that a model would.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }
}
