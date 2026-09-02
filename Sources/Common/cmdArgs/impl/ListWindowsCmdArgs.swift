import OrderedCollections

private let tag = "<tag>"
private let tags = "\(tag)..."

public struct ListWindowsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = .init(
        kind: .listWindows,
        help: list_windows_help_generated,
        flags: [
            "--all": trueBoolFlag(\.allAlias),

            // Filtering flags
            "--focused": trueBoolFlag(\.filteringOptions.focused),
            "--monitor": ArgParser(\.filteringOptions.monitors, parseMonitorIds),
            "--tag": ArgParser(\.filteringOptions.tags, parseTagFilters),
            "--pid": singleValueSubArgParser(\.filteringOptions.pidFilter, "<pid>") { Int32($0).toResult("Can't convert to Int32") },
            "--app-bundle-id": singleValueSubArgParser(\.filteringOptions.appIdFilter, "<app-bundle-id>", Result.success),

            // Formatting flags
            "--format": formatParser(\._format, for: .window),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--all", "--focused", "--tag"],
            ["--all", "--focused", "--monitor"],
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    fileprivate var allAlias: Bool = false

    public var filteringOptions = FilteringOptions()
    public var _format: [InterToken<InterVar>] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false

    public struct FilteringOptions: ConvenienceMutable, Equatable, Sendable {
        public var monitors: [MonitorId] = []
        public var focused: Bool = false
        public var tags: [TagFilter] = []
        public var pidFilter: Int32?
        public var appIdFilter: String?
    }
}

extension ListWindowsCmdArgs {
    public var format: [InterToken<InterVar>] {
        _format.isEmpty
            ? [
                .interVar(.formatVar(.window(.windowId))), .interVar(.plainInterVar(.rightPadding)), .literal(" | "),
                .interVar(.formatVar(.app(.appName))), .interVar(.plainInterVar(.rightPadding)), .literal(" | "),
                .interVar(.formatVar(.window(.windowTitle))),
            ]
            : _format
    }
}

func parseListWindowsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListWindowsCmdArgs> {
    let args = args.map { $0 == "--app-id" ? "--app-bundle-id" : $0 }.slice // Compatibility
    return parseSpecificCmdArgs(ListWindowsCmdArgs(commonState: .init(args)), args)
        .filter("Mandatory option is not specified (--focused|--all|--monitor|--tag)") { raw in
            raw.filteringOptions.focused || raw.allAlias || !raw.filteringOptions.monitors.isEmpty || !raw.filteringOptions.tags.isEmpty
        }
        .filter("--all conflicts with \"filtering\" flags. Please use '--monitor all' instead of '--all' alias") { raw in
            raw.allAlias.implies(raw.filteringOptions == ListWindowsCmdArgs.FilteringOptions())
        }
        .filter("--focused conflicts with other \"filtering\" flags") { raw in
            raw.filteringOptions.focused.implies(raw.filteringOptions.copy(\.focused, false) == ListWindowsCmdArgs.FilteringOptions())
        }
        .map { raw in
            raw.allAlias ? raw.copy(\.filteringOptions.monitors, [.all]).copy(\.allAlias, false) : raw // Normalize alias
        }
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}

func formatParser<Root>(
    _ keyPath: SendableWritableKeyPath<Root, [InterToken<InterVar>]>,
    for kind: TomObjKind,
) -> SubArgParser<Root, [InterToken<InterVar>]> {
    return ArgParser(keyPath) { input in
        if let arg = input.nonFlagArgOrNil() {
            return switch arg.interpolationTokens(interpolationChar: "%", ofInterVarType: InterVar.self) {
                case .success(let tokens): .succ(tokens, advanceBy: 1)
                case .failure(let err): .fail("Failed to parse <output-format>. \(err)", advanceBy: 1)
            }
        } else {
            let values = getAvailableInterVars(for: kind).joined(separator: "\n").prependLines("  ")
            return .fail("<output-format> is mandatory. Possible values:\n\(values)", advanceBy: 0)
        }
    }
}

func parseTagFilters(input: SubArgParserInput) -> ParsedCliArgs<[TagFilter]> {
    let args = input.nonFlagArgs()
    let possibleValues = "\(tag) possible values: (<tag-name>|selected)"
    if args.isEmpty {
        return .fail("\(tags) is mandatory. \(possibleValues)", advanceBy: args.count)
    }
    var result: [TagFilter] = []
    var i = 0
    for raw in args {
        switch raw {
            case "selected": result.append(.selected)
            default:
                switch parseTagName(raw) {
                    case .success(let name): result.append(.name(name))
                    case .failure(let msg): return .fail(msg, advanceBy: i + 1)
                }
        }
        i += 1
    }
    return .succ(result, advanceBy: result.count)
}

public enum TagFilter: Equatable, Sendable {
    case selected
    case name(String)
}

/// Tag names are declared in the config, so the CLI can only reject spellings that would clash with
/// the command line itself. Whether the tag exists is decided by the server.
public func parseTagName(_ raw: String) -> ResOrStr<String> {
    if raw.isEmpty { return .failure("Empty tag name is forbidden") }
    if raw == "selected" || raw == "all" { return .failure("'\(raw)' is a reserved tag name") }
    if raw.contains(",") { return .failure("Tag names are not allowed to contain comma") }
    if raw.starts(with: "-") { return .failure("Tag names starting with dash are disallowed") }
    if raw.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
        return .failure("Whitespace characters are forbidden in tag names")
    }
    return .success(raw)
}

public enum FormatVar: RawRepresentable, Equatable, CaseIterable, Sendable {
    case window(WindowFormatVar)
    case tag(TagFormatVar)
    case app(AppFormatVar)
    case monitor(MonitorFormatVar)

    // periphery:ignore
    private var kind: TomObjKind {
        switch self {
            case .app: .app
            case .monitor: .monitor
            case .window: .window
            case .tag: .tag
        }
    }

    public static var allCases: [FormatVar] {
        TomObjKind.allCases.flatMap {
            switch $0 {
                case .app: AppFormatVar.allCases.map(FormatVar.app)
                case .monitor: MonitorFormatVar.allCases.map(FormatVar.monitor)
                case .window: WindowFormatVar.allCases.map(FormatVar.window)
                case .tag: TagFormatVar.allCases.map(FormatVar.tag)
            }
        }
    }

    public init?(rawValue: String) {
        let value = TomObjKind.allCases.map { kind in
            switch kind {
                case .app: AppFormatVar(rawValue: rawValue).map(FormatVar.app)
                case .monitor: MonitorFormatVar(rawValue: rawValue).map(FormatVar.monitor)
                case .window: WindowFormatVar(rawValue: rawValue).map(FormatVar.window)
                case .tag: TagFormatVar(rawValue: rawValue).map(FormatVar.tag)
            }
        }.filterNotNil()
        switch value.sequencePattern {
            case .empty: return nil
            case .one(let it): self = it
            default: die("FormatVar clash: \(value)")
        }
    }

    public var rawValue: String {
        switch self {
            case .app(let it): it.rawValue
            case .monitor(let it): it.rawValue
            case .window(let it): it.rawValue
            case .tag(let it): it.rawValue
        }
    }

    public enum WindowFormatVar: String, Equatable, CaseIterable, Sendable {
        case windowId = "window-id"
        case windowIsFullscreen = "window-is-fullscreen"
        case windowIsFloating = "window-is-floating"
        case windowIsDialog = "window-is-dialog"
        case windowIsVisible = "window-is-visible"
        case windowTags = "window-tags"
        case windowTitle = "window-title"
    }

    public enum TagFormatVar: String, Equatable, CaseIterable, Sendable {
        case tagName = "tag"
        case tagIsSelected = "tag-is-selected"
        case tagIsOccupied = "tag-is-occupied"
    }

    public enum AppFormatVar: String, Equatable, CaseIterable, Sendable {
        case appBundleId = "app-bundle-id"
        case appName = "app-name"
        case appPid = "app-pid"
        case appExecPath = "app-exec-path"
        case appBundlePath = "app-bundle-path"
    }

    public enum MonitorFormatVar: String, Equatable, CaseIterable, Sendable {
        case monitorId_oneBased = "monitor-id"
        case monitorAppKitNsScreenScreensId = "monitor-appkit-nsscreen-screens-id"
        case monitorName = "monitor-name"
        case monitorIsMain = "monitor-is-main"
        case monitorLayout = "monitor-layout"
        case monitorLayoutSymbol = "monitor-layout-symbol"
        case monitorTags = "monitor-tags"
        case monitorNmaster = "monitor-nmaster"
        case monitorMfact = "monitor-mfact"
    }
}

public enum PlainInterVar: String, CaseIterable, Sendable, Equatable {
    case rightPadding = "right-padding"
    case newline = "newline"
    case tab = "tab"
}

public enum InterVar: RawRepresentable, Equatable, CaseIterable, Sendable {
    case formatVar(FormatVar)
    case plainInterVar(PlainInterVar)

    private enum Kind: CaseIterable, Equatable, Sendable {
        case formatVar
        case plainInterVar
    }

    // periphery:ignore
    private var kind: Kind {
        switch self {
            case .formatVar: .formatVar
            case .plainInterVar: .plainInterVar
        }
    }

    public static var allCases: [InterVar] {
        Kind.allCases.flatMap { kind in
            switch kind {
                case .formatVar: FormatVar.allCases.map(InterVar.formatVar)
                case .plainInterVar: PlainInterVar.allCases.map(InterVar.plainInterVar)
            }
        }
    }

    public init?(rawValue: String) {
        let this: [Self] = Kind.allCases.map { kind in
            switch kind {
                case .formatVar: FormatVar(rawValue: rawValue).map(InterVar.formatVar)
                case .plainInterVar: PlainInterVar(rawValue: rawValue).map(InterVar.plainInterVar)
            }
        }.filterNotNil()
        switch this.sequencePattern {
            case .empty: return nil
            case .one(let it): self = it
            default: die("Clashed cases: \(this)")
        }
    }

    public var rawValue: String {
        switch self {
            case .formatVar(let it): it.rawValue
            case .plainInterVar(let it): it.rawValue
        }
    }
}

public enum TomObjKind: CaseIterable, Sendable {
    case window, tag, app, monitor
}

public func getAvailableInterVars(for kind: TomObjKind) -> [String] {
    _getAvailableInterVars(for: kind) + PlainInterVar.allCases.map(\.rawValue)
}

private func _getAvailableInterVars(for kind: TomObjKind) -> [String] {
    switch kind {
        case .app: FormatVar.AppFormatVar.allCases.map(\.rawValue)
        case .monitor: FormatVar.MonitorFormatVar.allCases.map(\.rawValue)
        case .tag:
            FormatVar.TagFormatVar.allCases.map(\.rawValue) +
                _getAvailableInterVars(for: .monitor)
        case .window:
            FormatVar.WindowFormatVar.allCases.map(\.rawValue) +
                _getAvailableInterVars(for: .monitor) +
                _getAvailableInterVars(for: .app)
    }
}
