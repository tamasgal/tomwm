public struct ViewCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .view,
        help: view_help_generated,
        flags: [
            "--toggle": trueBoolFlag(\.toggle),
            "--all": trueBoolFlag(\.all),
            "--back-and-forth": trueBoolFlag(\.backAndForth),
            "--index": ArgParser(\.indices, parseTagIndices),
            "--monitor": monitorSubArgParser(),
        ],
        posArgs: [ArgParser(\.tags, parseTagNames)],
        conflictingOptions: [
            ["--all", "--toggle", "--back-and-forth"],
            ["--all", "--index", "--back-and-forth"],
        ],
    )

    public var tags: [String] = []
    /// 1-based positions in the `tags` config option. Lets a binding name a tag by position, so
    /// renaming a tag does not mean rewriting every binding that mentions it.
    public var indices: [Int] = []
    public var toggle: Bool = false
    public var all: Bool = false
    public var backAndForth: Bool = false

    public init(rawArgs: [String], tags: [String] = [], indices: [Int] = []) {
        self.commonState = .init(rawArgs.slice)
        self.tags = tags
        self.indices = indices
    }

    public var hasTargets: Bool { !tags.isEmpty || !indices.isEmpty }
}

func parseViewCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ViewCmdArgs> {
    parseSpecificCmdArgs(ViewCmdArgs(rawArgs: args), args)
        .filter("--all and --back-and-forth take no <tag> arguments") { ($0.all || $0.backAndForth).implies(!$0.hasTargets) }
        .filter("--toggle requires at least one <tag> or --index argument") { $0.toggle.implies($0.hasTargets) }
}

func parseTagIndices(input: SubArgParserInput) -> ParsedCliArgs<[Int]> {
    let args = input.nonFlagArgs()
    if args.isEmpty {
        return .fail("'--index' must be followed by at least one 1-based tag position", advanceBy: 0)
    }
    var result: [Int] = []
    var i = 0
    for raw in args {
        guard let value = Int(raw), value >= 1 else {
            return .fail("Can't parse '\(raw)' as a tag position. Positions are 1-based", advanceBy: i + 1)
        }
        result.append(value)
        i += 1
    }
    return .succ(result, advanceBy: args.count)
}

func parseTagNames(input: PosArgParserInput) -> ParsedCliArgs<[String]> {
    let args = input.nonFlagArgs()
    var result: [String] = []
    var i = 0
    for raw in args {
        switch parseTagName(raw) {
            case .success(let name): result.append(name)
            case .failure(let msg): return .fail(msg, advanceBy: i + 1)
        }
        i += 1
    }
    return .succ(result, advanceBy: args.count)
}
