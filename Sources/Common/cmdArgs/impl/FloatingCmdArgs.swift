public struct FloatingCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .floating,
        help: floating_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [ArgParser(\.toggle, parseToggleEnum)],
    )

    public var toggle: ToggleEnum = .toggle
    public var failIfNoop: Bool = false
}

func parseFloatingCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FloatingCmdArgs> {
    parseSpecificCmdArgs(FloatingCmdArgs(rawArgs: args), args)
        .filter("--fail-if-noop requires 'on' or 'off' argument") { $0.failIfNoop.implies($0.toggle == .on || $0.toggle == .off) }
}
