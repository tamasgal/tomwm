import AppKit
import Common

struct ListTagsCommand: Command {
    let args: ListTagsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let focus = focus
        var monitors: [MonitorInfo] = sortedMonitorInfos
        if args.monitors.isEmpty {
            monitors = [focus.monitor]
        } else {
            monitors = args.monitors.resolveMonitors(io)
            if monitors.isEmpty { return .fail }
        }

        var result: [TagRef] = []
        for monitor in monitors {
            let state = monitor.state
            for (index, name) in config.tags.enumerated() {
                let mask = TagMask(index: index)
                if let selected = args.selected, state.tagset.intersects(mask) != selected { continue }
                if let occupied = args.occupied, state.occupiedTags.intersects(mask) != occupied { continue }
                result.append(TagRef(name: name, mask: mask, monitor: monitor))
            }
        }

        lazy var list = result.map(TomObj.tag)
        return switch true {
            case args.outputOnlyCount:
                .succ(io.out("\(result.count)"))
            case args.json:
                switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): .succ(io.out(json))
                    case .failure(let msg): .fail(io.err(msg))
                }
            default:
                switch list.format(args.format) {
                    case .success(let lines): .succ(io.out(lines))
                    case .failure(let msg): .fail(io.err(msg.map(\.description).joinErrors()))
                }
        }
    }
}
