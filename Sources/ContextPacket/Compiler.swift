// Compiles the context packet a reviewer agent sees, under a token budget.
//
// The compiler is deliberately boring: a strategy turns the repository and the
// diff into an ordered list of candidate items, and a first-fit packer walks
// that list. Everything interesting is in *which* candidates a strategy emits
// and in what order, which is exactly the decision a lead should own.

/// What a piece of context lets the reviewer check.
public enum Evidence: Hashable, Sendable, CustomStringConvertible {
    case diff
    /// The rules for a scope (a module name or `RuleFile.rootScope`).
    case rules(String)
    /// The interface of a symbol: its signature, doc comment and availability.
    case interface(String)
    /// A place outside the diff that uses a symbol.
    case callSite(symbol: String, path: String)

    public var description: String {
        switch self {
        case .diff: return "diff"
        case .rules(let scope): return "rules(\(scope))"
        case .interface(let id): return "interface(\(id))"
        case .callSite(let id, let path): return "callSite(\(id) @ \(path))"
        }
    }
}

public struct ContextItem: Hashable, Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case diff, rules, interface, callSite, file, tool
    }

    public let kind: Kind
    public let id: String
    public let tokens: Int
    public let provides: Set<Evidence>

    public init(kind: Kind, id: String, tokens: Int, provides: Set<Evidence>) {
        self.kind = kind
        self.id = id
        self.tokens = tokens
        self.provides = provides
    }
}

public enum Strategy: String, Sendable, CaseIterable, Identifiable {
    /// Every file in every module the diff touches, the one big root rule
    /// file, and every tool the harness has. The "just give it the code" default.
    case wholeModules
    /// The diff, the big root rule file and every tool. The "keep it small" default.
    case diffOnly
    /// The diff, the scoped rule files for the touched modules, interface stubs
    /// for what the diff uses, excerpts of every caller of a changed public
    /// symbol, and only the tools a reviewer needs.
    case contract
    /// Same items as `.contract`, but with the tool schemas packed before the
    /// evidence. This was my first draft. Kept so the difference is reproducible.
    case contractToolsFirst

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wholeModules: return "Whole modules"
        case .diffOnly: return "Diff only"
        case .contract: return "Review contract"
        case .contractToolsFirst: return "Contract, tools first"
        }
    }
}

public enum CompileError: Error, Equatable, Sendable {
    case diffExceedsBudget(diffTokens: Int, budget: Int)
    case unknownFile(String)
}

public struct Packet: Sendable {
    public let strategy: Strategy
    public let budget: Int
    public let included: [ContextItem]
    /// Candidates the strategy asked for that did not fit the budget.
    public let evicted: [ContextItem]

    public var usedTokens: Int { included.reduce(0) { $0 + $1.tokens } }

    public var evidence: Set<Evidence> {
        included.reduce(into: Set<Evidence>()) { $0.formUnion($1.provides) }
    }

    public func tokens(of kind: ContextItem.Kind) -> Int {
        included.filter { $0.kind == kind }.reduce(0) { $0 + $1.tokens }
    }
}

public struct PacketCompiler: Sendable {
    /// Tokens shown for one caller: the enclosing function, not the whole file.
    public var callSiteExcerptTokens: Int
    /// Purposes a reviewer is allowed tools for under `.contract`.
    public var reviewerPurposes: Set<ToolPurpose>

    public init(callSiteExcerptTokens: Int = 160,
                reviewerPurposes: Set<ToolPurpose> = [.read, .search, .review]) {
        self.callSiteExcerptTokens = callSiteExcerptTokens
        self.reviewerPurposes = reviewerPurposes
    }

    public func compile(_ strategy: Strategy, repo: Repository, diff: Diff,
                        tools: [Tool], budget: Int) throws -> Packet {
        guard diff.tokens <= budget else {
            throw CompileError.diffExceedsBudget(diffTokens: diff.tokens, budget: budget)
        }
        var changed: [SourceFile] = []
        for change in diff.changedFiles {
            guard let file = repo.file(at: change.path) else {
                throw CompileError.unknownFile(change.path)
            }
            changed.append(file)
        }

        let diffItem = ContextItem(kind: .diff, id: "diff", tokens: diff.tokens, provides: [.diff])
        let candidates = self.candidates(strategy, repo: repo, diff: diff, changed: changed, tools: tools)

        var included = [diffItem]
        var evicted: [ContextItem] = []
        var used = diffItem.tokens
        for item in candidates {
            if used + item.tokens <= budget {
                included.append(item)
                used += item.tokens
            } else {
                evicted.append(item)
            }
        }
        return Packet(strategy: strategy, budget: budget, included: included, evicted: evicted)
    }

    // MARK: - Candidate selection (the part that matters)

    func candidates(_ strategy: Strategy, repo: Repository, diff: Diff,
                    changed: [SourceFile], tools: [Tool]) -> [ContextItem] {
        let touchedModules = Set(changed.map(\.module))
        switch strategy {
        case .wholeModules:
            let files = repo.files
                .filter { touchedModules.contains($0.module) }
                .sorted { $0.path < $1.path }
                .map { fileItem($0, repo: repo) }
            return [rulesItem(repo.monolithicRules)] + tools.map(toolItem) + files

        case .diffOnly:
            return [rulesItem(repo.monolithicRules)] + tools.map(toolItem)

        case .contract, .contractToolsFirst:
            let rules = repo.scopedRules
                .filter { !$0.covers.isDisjoint(with: touchedModules.union([RuleFile.rootScope])) }
                .sorted { $0.path < $1.path }
                .map(rulesItem)
            let reviewTools = tools
                .filter { !$0.purposes.isDisjoint(with: reviewerPurposes) && !$0.purposes.contains(.write) && !$0.purposes.contains(.deploy) }
                .map(toolItem)
            // Evidence before tools. Tool schemas are the easiest tokens to
            // spend and the least useful to a reviewer that is short on room:
            // with tools packed first, a tight budget evicts the callers.
            let evidence = interfaceItems(repo: repo, changed: changed)
                + callSiteItems(repo: repo, diff: diff)
            return strategy == .contract
                ? rules + evidence + reviewTools
                : rules + reviewTools + evidence
        }
    }

    /// Interface stubs for symbols the changed files use from *other* modules.
    /// Same-module symbols are cheap to read with a tool; cross-module
    /// contracts are what a reviewer misjudges without seeing them.
    func interfaceItems(repo: Repository, changed: [SourceFile]) -> [ContextItem] {
        var ids = Set<String>()
        for file in changed {
            for ref in file.references {
                guard let symbol = repo.symbol(ref), symbol.module != file.module else { continue }
                ids.insert(symbol.id)
            }
        }
        return ids.sorted().compactMap { id in
            guard let symbol = repo.symbol(id) else { return nil }
            return ContextItem(kind: .interface, id: id, tokens: symbol.interfaceTokens,
                               provides: [.interface(id)])
        }
    }

    /// One excerpt per (changed public symbol, file outside the diff that uses it).
    /// These are reverse edges: not what the diff depends on, but what depends on it.
    func callSiteItems(repo: Repository, diff: Diff) -> [ContextItem] {
        let inDiff = Set(diff.changedFiles.map(\.path))
        var items: [ContextItem] = []
        for symbol in diff.changedPublicSymbols.sorted() {
            let callers = repo.files
                .filter { !inDiff.contains($0.path) && $0.references.contains(symbol) }
                .sorted { $0.path < $1.path }
            for caller in callers {
                items.append(ContextItem(kind: .callSite, id: "\(symbol) @ \(caller.path)",
                                         tokens: min(callSiteExcerptTokens, caller.tokens),
                                         provides: [.callSite(symbol: symbol, path: caller.path)]))
            }
        }
        return items
    }

    func fileItem(_ file: SourceFile, repo: Repository) -> ContextItem {
        var provides = Set<Evidence>()
        for id in file.declares { provides.insert(.interface(id)) }
        for id in file.references { provides.insert(.callSite(symbol: id, path: file.path)) }
        return ContextItem(kind: .file, id: file.path, tokens: file.tokens, provides: provides)
    }

    func rulesItem(_ rules: RuleFile) -> ContextItem {
        ContextItem(kind: .rules, id: rules.path, tokens: rules.tokens,
                    provides: Set(rules.covers.map { Evidence.rules($0) }))
    }

    func toolItem(_ tool: Tool) -> ContextItem {
        ContextItem(kind: .tool, id: tool.name, tokens: tool.schemaTokens, provides: [])
    }
}
