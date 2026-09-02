public struct NmasterCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    /// `nmaster -1` must reach the positional parser rather than be read as a flag
    public static let allowsNegativeNumericArgs: Bool = true
    public static let parser: CmdParser<Self> = .init(
        kind: .nmaster,
        help: nmaster_help_generated,
        flags: [
            "--monitor": monitorSubArgParser(),
        ],
        posArgs: [newMandatoryPosArgParser(\.value, parseIntDelta, placeholder: "<n>")],
    )

    public var value: Lateinit<IntDelta> = .uninitialized

    public init(rawArgs: [String], value: IntDelta) {
        self.commonState = .init(rawArgs.slice)
        self.value = .initialized(value)
    }
}

/// A number that is relative when it carries an explicit sign, absolute otherwise
public enum IntDelta: Equatable, Sendable {
    case relative(Int)
    case absolute(Int)

    public func apply(to current: Int) -> Int {
        switch self {
            case .relative(let delta): current + delta
            case .absolute(let value): value
        }
    }
}

private func parseIntDelta(i: PosArgParserInput) -> ParsedCliArgs<IntDelta> {
    let raw = i.arg
    let signed = raw.starts(with: "+") || raw.starts(with: "-")
    guard let value = Int(raw) else {
        return .fail("Can't parse '\(raw)' as a number. Expected <n>, +<n> or -<n>", advanceBy: 1)
    }
    return .succ(signed ? .relative(value) : .absolute(value), advanceBy: 1)
}

func parseNmasterCmdArgs(_ args: StrArrSlice) -> ParsedCmd<NmasterCmdArgs> {
    parseSpecificCmdArgs(NmasterCmdArgs(rawArgs: args), args)
}
