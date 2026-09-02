public enum MonitorId: Equatable, Sendable {
    case focused
    case all
    case mouse
    case index(Int)
}

private let monitor = "<monitor-id>"
private let monitors = "\(monitor)..."

func parseMonitorIds(input: SubArgParserInput) -> ParsedCliArgs<[MonitorId]> {
    let args = input.nonFlagArgs()
    let possibleValues = "\(monitor) possible values: (<monitor-id>|focused|mouse|all)"
    if args.isEmpty {
        return .fail("\(monitors) is mandatory. \(possibleValues)", advanceBy: args.count)
    }
    var result: [MonitorId] = []
    var i = 0
    for raw in args {
        switch Int.init(raw) {
            case let unwrapped?: result.append(.index(unwrapped - 1))
            case _ where raw == "mouse": result.append(.mouse)
            case _ where raw == "all": result.append(.all)
            case _ where raw == "focused": result.append(.focused)
            default: return .fail("Can't parse monitor ID '\(raw)'. \(possibleValues)", advanceBy: i + 1)
        }
        i += 1
    }
    return .succ(result, advanceBy: result.count)
}
