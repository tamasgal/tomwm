public struct LayoutCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .layout,
        help: layout_help_generated,
        flags: [
            "--monitor": monitorSubArgParser(),
            "--toggle": trueBoolFlag(\.toggleWithPrevious),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [ArgParser(\.toggleBetween, parseToggleBetween)],
    )

    /// The layouts to cycle through. dwm's setlayout with a single value, cyclelayouts with more.
    public var toggleBetween: [TomLayout] = []
    /// dwm's `setlayout` with a NULL argument: go back to the previously used layout
    public var toggleWithPrevious: Bool = false
    public var failIfNoop: Bool = false

    public init(rawArgs: [String], toggleBetween: [TomLayout]) {
        self.commonState = .init(rawArgs.slice)
        self.toggleBetween = toggleBetween
    }
}

private func parseToggleBetween(input: PosArgParserInput) -> ParsedCliArgs<[TomLayout]> {
    let args = input.nonFlagArgs()
    var result: [TomLayout] = []
    var i = 0
    for arg in args {
        guard let layout = TomLayout(rawValue: arg) else {
            return .fail("Can't parse '\(arg)'\nPossible values: \(TomLayout.unionLiteral)", advanceBy: i + 1)
        }
        result.append(layout)
        i += 1
    }
    return .succ(result, advanceBy: args.count)
}

func parseLayoutCmdArgs(_ args: StrArrSlice) -> ParsedCmd<LayoutCmdArgs> {
    parseSpecificCmdArgs(LayoutCmdArgs(rawArgs: args), args)
        .filter("Either --toggle or at least one \(TomLayout.unionLiteral) argument is required") {
            $0.toggleWithPrevious != !$0.toggleBetween.isEmpty
        }
        .filter("--fail-if-noop allows only one <target-layout> argument") {
            $0.failIfNoop.implies($0.toggleBetween.count == 1)
        }
}
