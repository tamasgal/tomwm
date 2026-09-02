public struct ZoomCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .zoom,
        help: zoom_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
            "--monitor": monitorSubArgParser(),
        ],
        posArgs: [],
    )
}
