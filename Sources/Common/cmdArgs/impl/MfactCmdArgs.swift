public struct MfactCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    /// `mfact -0.05` must reach the positional parser rather than be read as a flag
    public static let allowsNegativeNumericArgs: Bool = true
    public static let parser: CmdParser<Self> = .init(
        kind: .mfact,
        help: mfact_help_generated,
        flags: [
            "--monitor": monitorSubArgParser(),
        ],
        posArgs: [newMandatoryPosArgParser(\.value, parseDoubleDelta, placeholder: "<fraction>")],
    )

    public var value: Lateinit<DoubleDelta> = .uninitialized

    public init(rawArgs: [String], value: DoubleDelta) {
        self.commonState = .init(rawArgs.slice)
        self.value = .initialized(value)
    }
}

public enum DoubleDelta: Equatable, Sendable {
    case relative(Double)
    case absolute(Double)

    public func apply(to current: Double) -> Double {
        switch self {
            case .relative(let delta): current + delta
            case .absolute(let value): value
        }
    }
}

private func parseDoubleDelta(i: PosArgParserInput) -> ParsedCliArgs<DoubleDelta> {
    let raw = i.arg
    let signed = raw.starts(with: "+") || raw.starts(with: "-")
    guard let value = Double(raw) else {
        return .fail("Can't parse '\(raw)' as a number. Expected <fraction>, +<fraction> or -<fraction>", advanceBy: 1)
    }
    return .succ(signed ? .relative(value) : .absolute(value), advanceBy: 1)
}

func parseMfactCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MfactCmdArgs> {
    parseSpecificCmdArgs(MfactCmdArgs(rawArgs: args), args)
}
