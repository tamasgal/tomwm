public struct MoveCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .move,
        help: move_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newMandatoryPosArgParser(\.direction, parseNextPrevArg, placeholder: "next|prev")],
    )

    /// Where to move the window in the client list, which is the tiling order
    public var direction: Lateinit<NextPrev> = .uninitialized
    public var failIfNoop: Bool = false

    public init(rawArgs: [String], direction: NextPrev) {
        self.commonState = .init(rawArgs.slice)
        self.direction = .initialized(direction)
    }
}

func parseNextPrevArg(i: PosArgParserInput) -> ParsedCliArgs<NextPrev> {
    switch i.arg {
        case "next": .succ(.next, advanceBy: 1)
        case "prev": .succ(.prev, advanceBy: 1)
        default: .fail("Can't parse '\(i.arg)'. Possible values: next|prev", advanceBy: 1)
    }
}

func parseMoveCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveCmdArgs> {
    parseSpecificCmdArgs(MoveCmdArgs(rawArgs: args), args)
}
