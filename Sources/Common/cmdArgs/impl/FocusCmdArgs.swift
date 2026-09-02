public struct FocusCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focus,
        help: focus_help_generated,
        flags: [
            "--ignore-floating": falseBoolFlag(\.includeFloating),
            "--window-id": windowIdSubArgParser(),
            "--boundaries": ArgParser(\.rawBoundaries, upcastArgParserFun(parseBoundaries)),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [ArgParser(\.direction, upcastArgParserFun(parseFocusDirection))],
    )

    public var direction: FocusDirection? = nil
    public var rawBoundaries: Boundaries? = nil
    public var failIfNoop: Bool = false
    public var includeFloating: Bool = true

    public init(rawArgs: StrArrSlice, direction: FocusDirection) {
        self.commonState = .init(rawArgs)
        self.direction = direction
    }

    public init(rawArgs: StrArrSlice, windowId: UInt32) {
        self.commonState = .init(rawArgs)
        self.windowId = windowId
    }

    /// Where directional focus is allowed to look
    public enum Boundaries: String, CaseIterable, Equatable, Sendable {
        case monitor
        case allMonitors = "all-monitors"
    }
}

/// dwm's focusstack walks the client list; the cardinal directions are the macOS-friendly addition
public enum FocusDirection: Equatable, Sendable {
    case stack(NextPrev)
    case cardinal(CardinalDirection)

    public static let unionLiteral = "left|down|up|right|next|prev"
}

extension FocusCmdArgs {
    public var boundaries: Boundaries { rawBoundaries ?? .allMonitors }
}

func parseFocusDirection(i: PosArgParserInput) -> ParsedCliArgs<FocusDirection> {
    switch i.arg {
        case "next": return .succ(.stack(.next), advanceBy: 1)
        case "prev": return .succ(.stack(.prev), advanceBy: 1)
        default:
            return switch parseEnum(i.arg, CardinalDirection.self) {
                case .success(let dir): .succ(.cardinal(dir), advanceBy: 1)
                case .failure: .fail("Can't parse '\(i.arg)'\nPossible values: \(FocusDirection.unionLiteral)", advanceBy: 1)
            }
    }
}

func parseFocusCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusCmdArgs> {
    parseSpecificCmdArgs(FocusCmdArgs(rawArgs: args), args)
        .filter("Mandatory argument is missing. \(FocusDirection.unionLiteral) or --window-id is required") {
            $0.direction != nil || $0.windowId != nil
        }
        .filter("--window-id is incompatible with other options") {
            $0.windowId == nil || $0 == FocusCmdArgs(rawArgs: args, windowId: $0.windowId.orDie())
        }
}

private func parseBoundaries(i: SubArgParserInput) -> ParsedCliArgs<FocusCmdArgs.Boundaries> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, FocusCmdArgs.Boundaries.self), advanceBy: 1)
    } else {
        return .fail("<boundary> is mandatory", advanceBy: 0)
    }
}
