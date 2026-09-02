public struct ListTagsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .listTags,
        help: list_tags_help_generated,
        flags: [
            "--monitor": ArgParser(\.monitors, parseMonitorIds),
            "--selected": boolFlag(\.selected),
            "--occupied": boolFlag(\.occupied),

            // Formatting flags
            "--format": formatParser(\._format, for: .tag),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    public var monitors: [MonitorId] = []
    public var selected: Bool?
    public var occupied: Bool?
    public var _format: [InterToken<InterVar>] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
}

extension ListTagsCmdArgs {
    public var format: [InterToken<InterVar>] {
        _format.isEmpty ? [.interVar(.formatVar(.tag(.tagName)))] : _format
    }
}

func parseListTagsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListTagsCmdArgs> {
    parseSpecificCmdArgs(ListTagsCmdArgs(rawArgs: args), args)
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}
