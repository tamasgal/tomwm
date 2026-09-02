import Common
import Foundation

struct WindowWithPrefetchedTitle {
    let window: Window
    let title: String?

    private init(window: Window, title: String?) {
        self.window = window
        self.title = title
    }

    static func resolveWindow(_ window: Window, for formatVar: FormatVar, _ cm: CancellationMode) async throws -> Self {
        try await resolveWindow(window, needsTitle: formatVar == .window(.windowTitle), cm)
    }

    static func resolveWindow(_ window: Window, for format: [InterToken<InterVar>], _ cm: CancellationMode) async throws -> Self {
        let needsTitle = format.contains { $0 == .interVar(.formatVar(.window(.windowTitle))) }
        return try await resolveWindow(window, needsTitle: needsTitle, cm)
    }

    private static func resolveWindow(_ window: Window, needsTitle: Bool, _ cm: CancellationMode) async throws -> Self {
        let title = needsTitle ? try await window.getTitle(cm) : nil
        return .init(window: window, title: title)
    }

    static func forTest(window: Window, title: String?) -> Self {
        .init(window: window, title: title)
    }
}

/// One tag as seen from one monitor. Tags are per monitor, so "selected" and "occupied" only make
/// sense together with the monitor they are asked about.
struct TagRef {
    let name: String
    let mask: TagMask
    let monitor: MonitorInfo
}

enum TomObj {
    case window(WindowWithPrefetchedTitle)
    case tag(TagRef)
    case app(any AbstractApp)
    case monitor(MonitorInfo)

    var kind: TomObjKind {
        switch self {
            case .window: .window
            case .tag: .tag
            case .app: .app
            case .monitor: .monitor
        }
    }
}

extension [TomObj] {
    @MainActor
    func format(_ format: [InterToken<InterVar>]) -> Result<[String], [InterVarExpansionError]> {
        var cellTable: [[Cell<String>]] = []
        for obj in self {
            var line: [Cell<String>] = []
            var curCell: String = ""
            var errors = [InterVarExpansionError]()
            for token in format {
                switch token {
                    case .interVar(.plainInterVar(.rightPadding)):
                        line.append(Cell(value: curCell, rightPadding: true))
                        curCell = ""
                    case .literal(let literal):
                        curCell += literal
                    case .interVar(let value):
                        switch value.expandFormatVar(obj: obj) {
                            case .success(let expanded): curCell += expanded.toString()
                            case .failure(let error): errors.append(error)
                        }
                }
            }
            if !errors.isEmpty { return .failure(errors) }
            line.append(Cell(value: curCell, rightPadding: false))
            cellTable.append(line)
        }
        let result = cellTable
            .transposed()
            .map { column in
                let columndWidth = column.map { $0.value.count }.max().orDie()
                return column.map {
                    $0.rightPadding
                        ? $0.value + String(repeating: " ", count: columndWidth - $0.value.count)
                        : $0.value
                }
            }
            .transposed()
            .map { line in line.joined(separator: "") }
        return .success(result)
    }
}

enum Primitive: Encodable {
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)

    enum Kind: String {
        case bool = "Bool"
        case int = "Int"
        case double = "Double"
        case string = "String"
    }

    var kind: Kind {
        switch self {
            case .bool: .bool
            case .int: .int
            case .double: .double
            case .string: .string
        }
    }

    func toString() -> String {
        switch self {
            case .bool(let x): x.description
            case .int(let x): x.description
            case .double(let x): x.description
            case .string(let x): x
        }
    }

    func encode(to encoder: any Encoder) throws {
        let value: Encodable = switch self {
            case .bool(let x): x
            case .int(let x): x
            case .double(let x): x
            case .string(let x): x
        }
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public static func int(_ int: UInt32) -> Self { .int(Int64(exactly: int).orDie()) }
    public static func int(_ int: Int32) -> Self { .int(Int64(exactly: int).orDie()) }
    public static func int(_ int: Int) -> Self { .int(Int64(exactly: int).orDie()) }
}

private struct Cell<T> {
    let value: T
    let rightPadding: Bool
}

extension FormatVar {
    @MainActor func expandFormatVar(obj: TomObj) -> Result<Primitive, InterVarExpansionError> {
        switch (obj, self) {
            case (.window(let w), .monitor):
                return expandFormatVar(obj: .monitor(w.window.monitor))
            case (.window(let w), .app):
                return expandFormatVar(obj: .app(w.window.app))
            case (.window, .window), (.window, .tag): break

            case (.tag(let t), .monitor):
                return expandFormatVar(obj: .monitor(t.monitor))
            case (.tag, _): break

            case (.app, _): break
            case (.monitor, _): break
        }

        switch (obj, self) {
            case (.window(let w), .window(let f)):
                return switch f {
                    case .windowId: .success(.int(w.window.windowId))
                    case .windowIsFullscreen: .success(.bool(w.window.isFullscreen))
                    case .windowIsFloating: .success(.bool(w.window.isFloating))
                    case .windowIsDialog: .success(.bool(w.window.isDialog))
                    case .windowIsVisible: .success(.bool(w.window.isVisible))
                    case .windowTags: .success(.string(w.window.tags.tagNames.joined(separator: ",")))
                    case .windowTitle: .success(.string(w.title.orDie("Title wasn't prefetched")))
                }
            case (.tag(let t), .tag(let f)):
                let state = t.monitor.state
                return switch f {
                    case .tagName: .success(.string(t.name))
                    case .tagIsSelected: .success(.bool(state.tagset.intersects(t.mask)))
                    case .tagIsOccupied: .success(.bool(state.occupiedTags.intersects(t.mask)))
                }
            case (.monitor(let m), .monitor(let f)):
                let state = m.state
                return switch f {
                    case .monitorId_oneBased: .success(m.monitorId_oneBased.map { .int($0) } ?? .string("NULL-MONITOR-ID"))
                    case .monitorAppKitNsScreenScreensId: .success(.int(m.monitorAppKitNsScreenScreensId))
                    case .monitorName: .success(.string(m.name))
                    case .monitorIsMain: .success(.bool(m.isMain))
                    case .monitorLayout: .success(.string(state.layout.rawValue))
                    case .monitorLayoutSymbol: .success(.string(state.layout.symbol))
                    case .monitorTags: .success(.string(state.tagset.tagNames.joined(separator: ",")))
                    case .monitorNmaster: .success(.int(state.nmaster))
                    case .monitorMfact: .success(.double(state.mfact))
                }
            case (.app(let a), .app(let f)):
                return switch f {
                    case .appBundleId: .success(.string(a.rawAppBundleId ?? "NULL-APP-BUNDLE-ID"))
                    case .appName: .success(.string(a.name ?? "NULL-APP-NAME"))
                    case .appPid: .success(.int(a.pid))
                    case .appExecPath: .success(.string(a.execPath ?? "NULL-APP-EXEC-PATH"))
                    case .appBundlePath: .success(.string(a.bundlePath ?? "NULL-APP-BUNDLE-PATH"))
                }
            default: break
        }
        return .failure(.unknownInterpolationVariable(unknownInterpolationVariable(variable: rawValue, obj)))
    }
}

enum InterVarExpansionError: LocalizedError, CustomStringConvertible {
    case unknownInterpolationVariable(String)
    case rightPaddingCannotBeExpanded(String)

    public var description: String {
        switch self {
            case .unknownInterpolationVariable(let msg): msg
            case .rightPaddingCannotBeExpanded(let msg): msg
        }
    }

    public var errorDescription: String? { description }
}

extension PlainInterVar {
    @MainActor func expandFormatVar() -> Result<Primitive, InterVarExpansionError> {
        switch self {
            case .newline: .success(.string("\n"))
            case .tab: .success(.string("\t"))
            case .rightPadding:
                .failure(.rightPaddingCannotBeExpanded("\(PlainInterVar.rightPadding.rawValue.singleQuoted) interpolation variable cannot be expanded"))
        }
    }
}

extension InterVar {
    @MainActor func expandFormatVar(obj: TomObj) -> Result<Primitive, InterVarExpansionError> {
        switch self {
            case .formatVar(let it): it.expandFormatVar(obj: obj)
            case .plainInterVar(let it): it.expandFormatVar()
        }
    }
}

func unknownInterpolationVariable(variable: String, _ obj: TomObj) -> String {
    "Unknown interpolation variable '\(variable)'. " +
        "Possible values:\n\(getAvailableInterVars(for: obj.kind).joined(separator: "\n").prependLines("  "))"
}
