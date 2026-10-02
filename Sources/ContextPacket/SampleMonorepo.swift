// A constructed iOS monorepo, a constructed diff and five seeded review
// findings. Sizes are plausible, not measured from a real codebase. Swap in
// your own repository graph and tokenizer to get numbers that mean something
// for your team.

public enum SampleMonorepo {
    public static let defaultBudget = 32_000

    // MARK: Symbols

    public static let symbols: [Symbol] = [
        Symbol(id: "Networking.APIClient", module: "Networking", interfaceTokens: 260),
        Symbol(id: "Networking.APIClient.send", module: "Networking", interfaceTokens: 180),
        Symbol(id: "Networking.RetryPolicy", module: "Networking", interfaceTokens: 140),
        Symbol(id: "CoreModels.Money", module: "CoreModels", interfaceTokens: 220),
        Symbol(id: "CoreModels.Money.init(double:)", module: "CoreModels", interfaceTokens: 90, deprecated: true),
        Symbol(id: "CoreModels.Money.init(minorUnits:currency:)", module: "CoreModels", interfaceTokens: 90),
        Symbol(id: "CoreModels.Order", module: "CoreModels", interfaceTokens: 240),
        Symbol(id: "Analytics.Tracker.log(_:)", module: "Analytics", interfaceTokens: 110),
        Symbol(id: "Analytics.Tracker.log(raw:)", module: "Analytics", interfaceTokens: 120),
        Symbol(id: "Analytics.EventCatalog", module: "Analytics", interfaceTokens: 380),
        Symbol(id: "DesignSystem.PrimaryButton", module: "DesignSystem", interfaceTokens: 150),
        Symbol(id: "Persistence.Store", module: "Persistence", interfaceTokens: 200)
    ]

    // MARK: Files

    public static let files: [SourceFile] = [
        // Networking
        SourceFile(path: "Networking/APIClient.swift", module: "Networking", tokens: 3_800,
                   declares: ["Networking.APIClient", "Networking.APIClient.send"],
                   references: ["Networking.RetryPolicy"]),
        SourceFile(path: "Networking/RequestBuilder.swift", module: "Networking", tokens: 2_600),
        SourceFile(path: "Networking/RetryPolicy.swift", module: "Networking", tokens: 1_400,
                   declares: ["Networking.RetryPolicy"]),
        SourceFile(path: "Networking/Reachability.swift", module: "Networking", tokens: 1_900),
        SourceFile(path: "Networking/Endpoints.swift", module: "Networking", tokens: 4_200),
        SourceFile(path: "Networking/NetworkingMocks.swift", module: "Networking", tokens: 3_100,
                   references: ["Networking.APIClient.send"]),
        // FeatureCheckout
        SourceFile(path: "FeatureCheckout/CheckoutService.swift", module: "FeatureCheckout", tokens: 4_600,
                   references: ["Networking.APIClient.send", "CoreModels.Money.init(double:)",
                                "Analytics.Tracker.log(raw:)"]),
        SourceFile(path: "FeatureCheckout/CheckoutView.swift", module: "FeatureCheckout", tokens: 5_200,
                   references: ["DesignSystem.PrimaryButton"]),
        SourceFile(path: "FeatureCheckout/CheckoutViewModel.swift", module: "FeatureCheckout", tokens: 3_900,
                   references: ["CoreModels.Money"]),
        SourceFile(path: "FeatureCheckout/PaymentSheet.swift", module: "FeatureCheckout", tokens: 4_400),
        SourceFile(path: "FeatureCheckout/CheckoutStrings.swift", module: "FeatureCheckout", tokens: 2_200),
        SourceFile(path: "FeatureCheckout/CheckoutServiceTests.swift", module: "FeatureCheckout", tokens: 5_800,
                   references: ["Networking.APIClient.send"]),
        // CoreModels
        SourceFile(path: "CoreModels/Money.swift", module: "CoreModels", tokens: 1_500,
                   declares: ["CoreModels.Money", "CoreModels.Money.init(double:)",
                              "CoreModels.Money.init(minorUnits:currency:)"]),
        SourceFile(path: "CoreModels/Order.swift", module: "CoreModels", tokens: 1_800,
                   declares: ["CoreModels.Order"]),
        // Analytics
        SourceFile(path: "Analytics/Tracker.swift", module: "Analytics", tokens: 1_600,
                   declares: ["Analytics.Tracker.log(_:)", "Analytics.Tracker.log(raw:)"]),
        SourceFile(path: "Analytics/EventCatalog.swift", module: "Analytics", tokens: 2_400,
                   declares: ["Analytics.EventCatalog"]),
        // DesignSystem, Persistence
        SourceFile(path: "DesignSystem/PrimaryButton.swift", module: "DesignSystem", tokens: 1_200,
                   declares: ["DesignSystem.PrimaryButton"]),
        SourceFile(path: "Persistence/Store.swift", module: "Persistence", tokens: 2_500,
                   declares: ["Persistence.Store"]),
        // Callers in modules the diff never touches
        SourceFile(path: "FeatureProfile/ProfileLoader.swift", module: "FeatureProfile", tokens: 2_300,
                   references: ["Networking.APIClient.send", "Persistence.Store"]),
        SourceFile(path: "FeatureProfile/ProfileView.swift", module: "FeatureProfile", tokens: 3_000,
                   references: ["DesignSystem.PrimaryButton"]),
        SourceFile(path: "FeatureOrders/OrderHistoryService.swift", module: "FeatureOrders", tokens: 2_700,
                   references: ["Networking.APIClient.send", "CoreModels.Order"]),
        SourceFile(path: "FeatureOrders/OrderListView.swift", module: "FeatureOrders", tokens: 3_300,
                   references: ["CoreModels.Order"])
    ]

    // MARK: Instruction files

    static let modules = ["Networking", "FeatureCheckout", "CoreModels", "Analytics",
                          "DesignSystem", "Persistence", "FeatureProfile", "FeatureOrders"]

    public static let monolithicRules = RuleFile(
        path: "CLAUDE.md", tokens: 9_000,
        covers: Set(modules + [RuleFile.rootScope]))

    public static let scopedRules: [RuleFile] = [
        RuleFile(path: "CLAUDE.md", tokens: 900, covers: [RuleFile.rootScope]),
        RuleFile(path: "Networking/CLAUDE.md", tokens: 420, covers: ["Networking"]),
        RuleFile(path: "FeatureCheckout/CLAUDE.md", tokens: 380, covers: ["FeatureCheckout"]),
        RuleFile(path: "CoreModels/CLAUDE.md", tokens: 300, covers: ["CoreModels"]),
        RuleFile(path: "Analytics/CLAUDE.md", tokens: 340, covers: ["Analytics"]),
        RuleFile(path: "DesignSystem/CLAUDE.md", tokens: 460, covers: ["DesignSystem"]),
        RuleFile(path: "Persistence/CLAUDE.md", tokens: 310, covers: ["Persistence"]),
        RuleFile(path: "FeatureProfile/CLAUDE.md", tokens: 280, covers: ["FeatureProfile"]),
        RuleFile(path: "FeatureOrders/CLAUDE.md", tokens: 290, covers: ["FeatureOrders"])
    ]

    public static let repository = Repository(files: files, symbols: symbols,
                                              monolithicRules: monolithicRules,
                                              scopedRules: scopedRules)

    // MARK: The diff under review

    /// Adds a required `retry:` parameter to `APIClient.send`, force-unwraps a
    /// URL in Networking, and updates checkout to the new call. Checkout also
    /// builds a `Money` from a `Double` and logs a raw analytics event.
    public static let diff = Diff(
        changedFiles: [ChangedFile(path: "Networking/APIClient.swift", hunkTokens: 900),
                       ChangedFile(path: "FeatureCheckout/CheckoutService.swift", hunkTokens: 1_100)],
        changedPublicSymbols: ["Networking.APIClient.send"])

    // MARK: Tools the harness exposes

    public static let tools: [Tool] = [
        Tool(name: "Read", schemaTokens: 700, purposes: [.read]),
        Tool(name: "Grep", schemaTokens: 520, purposes: [.search]),
        Tool(name: "Glob", schemaTokens: 380, purposes: [.search]),
        Tool(name: "Edit", schemaTokens: 900, purposes: [.write]),
        Tool(name: "MultiEdit", schemaTokens: 820, purposes: [.write]),
        Tool(name: "Write", schemaTokens: 650, purposes: [.write]),
        Tool(name: "Bash", schemaTokens: 1_900, purposes: [.build, .write]),
        Tool(name: "WebFetch", schemaTokens: 600, purposes: [.read]),
        Tool(name: "WebSearch", schemaTokens: 540, purposes: [.search]),
        Tool(name: "TodoWrite", schemaTokens: 1_100, purposes: [.tracker]),
        Tool(name: "Task", schemaTokens: 1_400, purposes: [.chat]),
        Tool(name: "NotebookEdit", schemaTokens: 480, purposes: [.write]),
        Tool(name: "github.get_pull_request_diff", schemaTokens: 420, purposes: [.review]),
        Tool(name: "github.list_review_comments", schemaTokens: 460, purposes: [.review]),
        Tool(name: "github.create_review_comment", schemaTokens: 610, purposes: [.review, .write]),
        Tool(name: "github.merge_pull_request", schemaTokens: 520, purposes: [.deploy, .write]),
        Tool(name: "github.create_branch", schemaTokens: 380, purposes: [.write]),
        Tool(name: "github.push_files", schemaTokens: 640, purposes: [.write]),
        Tool(name: "github.create_issue", schemaTokens: 560, purposes: [.tracker, .write]),
        Tool(name: "github.search_code", schemaTokens: 480, purposes: [.search]),
        Tool(name: "xcode.build_project", schemaTokens: 540, purposes: [.build]),
        Tool(name: "xcode.run_tests", schemaTokens: 600, purposes: [.build]),
        Tool(name: "xcode.list_simulators", schemaTokens: 300, purposes: [.build]),
        Tool(name: "xcode.boot_simulator", schemaTokens: 320, purposes: [.build]),
        Tool(name: "xcode.get_build_log", schemaTokens: 380, purposes: [.read]),
        Tool(name: "xcode.preview_snapshot", schemaTokens: 520, purposes: [.build]),
        Tool(name: "jira.create_ticket", schemaTokens: 700, purposes: [.tracker, .write]),
        Tool(name: "jira.search", schemaTokens: 640, purposes: [.tracker]),
        Tool(name: "jira.transition", schemaTokens: 560, purposes: [.tracker, .write]),
        Tool(name: "slack.post_message", schemaTokens: 520, purposes: [.chat, .write]),
        Tool(name: "slack.search", schemaTokens: 480, purposes: [.chat]),
        Tool(name: "sentry.get_issue", schemaTokens: 520, purposes: [.read]),
        Tool(name: "sentry.list_issues", schemaTokens: 560, purposes: [.read]),
        Tool(name: "testflight.upload_build", schemaTokens: 620, purposes: [.deploy, .write]),
        Tool(name: "testflight.list_builds", schemaTokens: 440, purposes: [.deploy]),
        Tool(name: "figma.get_frame", schemaTokens: 580, purposes: [.read]),
        Tool(name: "figma.export_assets", schemaTokens: 520, purposes: [.write]),
        Tool(name: "localization.sync", schemaTokens: 500, purposes: [.write])
    ]

    // MARK: Seeded findings

    public static let findings: [Finding] = [
        Finding(id: "F1",
                title: "Breaking change: two callers outside the diff still use the old send(_:)",
                requires: [.diff,
                           .callSite(symbol: "Networking.APIClient.send", path: "FeatureProfile/ProfileLoader.swift"),
                           .callSite(symbol: "Networking.APIClient.send", path: "FeatureOrders/OrderHistoryService.swift")]),
        Finding(id: "F2",
                title: "Force unwrap in Networking, which its rules forbid",
                requires: [.diff, .rules("Networking")]),
        Finding(id: "F3",
                title: "Checkout builds Money from a Double via a deprecated initializer",
                requires: [.diff, .interface("CoreModels.Money.init(double:)")]),
        Finding(id: "F4",
                title: "Raw analytics event logged, which the repo-wide rules forbid",
                requires: [.diff, .rules(RuleFile.rootScope), .interface("Analytics.Tracker.log(raw:)")]),
        Finding(id: "F5",
                title: "The Networking test double still implements the old signature",
                requires: [.diff,
                           .callSite(symbol: "Networking.APIClient.send", path: "Networking/NetworkingMocks.swift")])
    ]
}
