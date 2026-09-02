public struct TagCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .tag,
        help: tag_help_generated,
        flags: [
            "--toggle": trueBoolFlag(\.toggle),
            "--all": trueBoolFlag(\.all),
            "--index": ArgParser(\.indices, parseTagIndices),
            "--window-id": windowIdSubArgParser(),
        ],
        posArgs: [ArgParser(\.tags, parseTagNames)],
        conflictingOptions: [
            ["--all", "--toggle"],
            ["--all", "--index"],
        ],
    )

    public var tags: [String] = []
    /// 1-based positions in the `tags` config option. See ``ViewCmdArgs/indices``.
    public var indices: [Int] = []
    public var toggle: Bool = false
    public var all: Bool = false

    public init(rawArgs: [String], tags: [String] = [], indices: [Int] = []) {
        self.commonState = .init(rawArgs.slice)
        self.tags = tags
        self.indices = indices
    }

    public var hasTargets: Bool { !tags.isEmpty || !indices.isEmpty }
}

func parseTagCmdArgs(_ args: StrArrSlice) -> ParsedCmd<TagCmdArgs> {
    parseSpecificCmdArgs(TagCmdArgs(rawArgs: args), args)
        .filter("--all takes no <tag> arguments") { $0.all.implies(!$0.hasTargets) }
        .filter("At least one <tag> or --index argument is required") { $0.all || $0.hasTargets }
}
