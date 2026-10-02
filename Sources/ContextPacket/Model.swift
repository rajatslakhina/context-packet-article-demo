// The inputs a context compiler reads: a modular repository, a diff, and the
// tools the agent harness can expose. Token counts are declared, not measured:
// the point of the library is the selection logic, so the sizes are data you
// replace with your own tokenizer's numbers.

/// A public declaration another module can see, e.g. `Networking.APIClient.send`.
public struct Symbol: Hashable, Sendable {
    public let id: String
    public let module: String
    /// Tokens needed to show this symbol's interface stub (signature + doc comment).
    public let interfaceTokens: Int
    public let deprecated: Bool

    public init(id: String, module: String, interfaceTokens: Int, deprecated: Bool = false) {
        self.id = id
        self.module = module
        self.interfaceTokens = interfaceTokens
        self.deprecated = deprecated
    }
}

public struct SourceFile: Hashable, Sendable {
    public let path: String
    public let module: String
    public let tokens: Int
    /// Symbol ids this file declares.
    public let declares: [String]
    /// Symbol ids this file uses from anywhere (its own module or others).
    public let references: [String]

    public init(path: String, module: String, tokens: Int, declares: [String] = [], references: [String] = []) {
        self.path = path
        self.module = module
        self.tokens = tokens
        self.declares = declares
        self.references = references
    }
}

/// An instruction file such as a CLAUDE.md. `covers` lists the scopes whose
/// rules it contains: a module name, or `RuleFile.rootScope` for repo-wide rules.
public struct RuleFile: Hashable, Sendable {
    public static let rootScope = "<root>"

    public let path: String
    public let tokens: Int
    public let covers: Set<String>

    public init(path: String, tokens: Int, covers: Set<String>) {
        self.path = path
        self.tokens = tokens
        self.covers = covers
    }
}

public enum ToolPurpose: String, Hashable, Sendable, CaseIterable {
    case read, search, review, build, write, deploy, tracker, chat
}

public struct Tool: Hashable, Sendable {
    public let name: String
    public let schemaTokens: Int
    public let purposes: Set<ToolPurpose>

    public init(name: String, schemaTokens: Int, purposes: Set<ToolPurpose>) {
        self.name = name
        self.schemaTokens = schemaTokens
        self.purposes = purposes
    }
}

public struct Repository: Sendable {
    public let files: [SourceFile]
    public let symbols: [Symbol]
    /// One big instruction file at the root that covers every scope.
    public let monolithicRules: RuleFile
    /// A slim root file plus one file per module.
    public let scopedRules: [RuleFile]

    public init(files: [SourceFile], symbols: [Symbol], monolithicRules: RuleFile, scopedRules: [RuleFile]) {
        self.files = files
        self.symbols = symbols
        self.monolithicRules = monolithicRules
        self.scopedRules = scopedRules
    }

    public func file(at path: String) -> SourceFile? {
        files.first { $0.path == path }
    }

    public func symbol(_ id: String) -> Symbol? {
        symbols.first { $0.id == id }
    }
}

public struct ChangedFile: Hashable, Sendable {
    public let path: String
    /// Tokens of the hunk text shown to the reviewer.
    public let hunkTokens: Int

    public init(path: String, hunkTokens: Int) {
        self.path = path
        self.hunkTokens = hunkTokens
    }
}

public struct Diff: Sendable {
    public let changedFiles: [ChangedFile]
    /// Public symbols whose signature or contract this diff changes.
    public let changedPublicSymbols: [String]

    public init(changedFiles: [ChangedFile], changedPublicSymbols: [String]) {
        self.changedFiles = changedFiles
        self.changedPublicSymbols = changedPublicSymbols
    }

    public var tokens: Int { changedFiles.reduce(0) { $0 + $1.hunkTokens } }
}
