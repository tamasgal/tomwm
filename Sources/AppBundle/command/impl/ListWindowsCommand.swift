import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        let focus = focus
        var windows: [Window] = []

        if args.filteringOptions.focused {
            switch focus.windowOrNil {
                case let window?: windows = [window]
                case nil: return .fail(io.err(noWindowIsFocused))
            }
        } else {
            windows = Window.all
            if !args.filteringOptions.monitors.isEmpty {
                let monitors: Set<CGPoint> = args.filteringOptions.monitors.resolveMonitorPoints(io)
                if monitors.isEmpty { return .fail }
                windows = windows.filter { monitors.contains(resolvedMonitorPoint($0.monitorPoint)) }
            }
            if !args.filteringOptions.tags.isEmpty {
                var mask = TagMask.none
                for filter in args.filteringOptions.tags {
                    switch filter {
                        case .selected: mask.formUnion(focus.monitorState.tagset)
                        case .name(let name):
                            guard let tag = TagMask.named(name) else {
                                return .fail(io.err("Unknown tag '\(name)'. Known tags: \(config.tags.joined(separator: ", "))"))
                            }
                            mask.formUnion(tag)
                    }
                }
                windows = windows.filter { $0.tags.intersects(mask) }
            }
            if let pid = args.filteringOptions.pidFilter {
                windows = windows.filter { $0.app.pid == pid }
            }
            if let appId = args.filteringOptions.appIdFilter {
                windows = windows.filter { $0.app.rawAppBundleId == appId }
            }
        }

        if args.outputOnlyCount {
            return .succ(io.out("\(windows.count)"))
        } else {
            var _list: [WindowWithPrefetchedTitle] = [] // todo cleanup
            for window in windows {
                guard let window = try? await WindowWithPrefetchedTitle.resolveWindow(window, for: args.format, .nonCancellable) else { return .fail(io.err(bugPrompt())) }
                _list.append(window)
            }
            _list = _list.sortedBy([{ $0.window.app.name ?? "" }, { $0.title ?? "" }])

            let list = _list.map { TomObj.window($0) }
            if args.json {
                return switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): .succ(io.out(json))
                    case .failure(let msg): .fail(io.err(msg))
                }
            } else {
                return switch list.format(args.format) {
                    case .success(let lines): .succ(io.out(lines))
                    case .failure(let msg): .fail(io.err(msg.map(\.description).joinErrors()))
                }
            }
        }
    }
}
