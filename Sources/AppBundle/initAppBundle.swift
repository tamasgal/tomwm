import AppKit
import Common
import Foundation

@MainActor public func initAppBundle() {
    Task.startUnstructured {
        initTerminationHandler()
        unsafe _isCli = false
        initServerArgs()
        if serverArgs.isReadOnly {
            // Easy to forget once it is running: every Accessibility write is dropped, so windows
            // are tracked and tagged but never moved
            eprint("tomwm is running with --read-only. No window will be moved or resized.")
        }
        await waitForAccessibilityPermission_nonCancellable()
        if isDebug {
            await toggleReleaseServerIfDebug(.off)
            interceptTermination(SIGINT)
            interceptTermination(SIGKILL)
        }

        await bootstrapConfig_nonCancellable()
        _ = await reloadConfig_nonCancellable()

        startUnixSocketServer()
        GlobalObserver.initObserver()
        seedMonitorStates()
        await runHeavyCompleteRefreshSession(
            .startup,
            // It's important for the first initialization to be non cancellable
            // to make sure that isStartup propagates to all places
            assumeCancellable: false,
            arrange: false,
        )
        try await runLightSession(.startup, .forceRun) {
            _ = await config.afterStartupCommand.run(.defaultEnv, .emptyStdin)
        }
    }
}

@MainActor private func bootstrapConfig_nonCancellable() async {
    let result = await reloadConfig_nonCancellable(forceConfigUrl: defaultConfigUrl)
    let msg = """
        Can't load default config. Your installation is probably corrupted.
        Please don't modify \(defaultConfigUrl.description.singleQuoted)

        \(result.stdout)
        """
    check(result.isOk, msg)
}

/// Give every monitor a state before the first window is registered, so new windows land on a
/// monitor that already knows which tags it is showing.
@MainActor
private func seedMonitorStates() {
    for monitor in monitorInfos { _ = monitor.state }
    _ = mainMonitorInfo.focusMonitor()
}

var isStartup: Bool { refreshSessionEvent?.isStartup == true }

struct ServerArgs: Sendable {
    var configLocation: String? = nil
    var isReadOnly: Bool = false
}

private let serverHelp = """
    USAGE: \(CommandLine.arguments.first ?? "TomWM.app/Contents/MacOS/TomWM") [<options>]

    OPTIONS:
      -h, --help              Print help
      -v, --version           Print TomWM.app version
      --config-path <path>    Config path. It will take priority over ~/.tomwm.toml
                              and ${XDG_CONFIG_HOME}/tomwm/tomwm.toml
      --read-only             Track and tag windows, but never move or resize them.
                              Every Accessibility write is dropped, so the layout has no effect
                              on screen. Useful for debug-windows and the other query commands.
    """

nonisolated(unsafe) private var _serverArgs = ServerArgs()
var serverArgs: ServerArgs { unsafe _serverArgs }
private func initServerArgs() {
    let args = CommandLine.arguments.slice(1...) ?? []
    if args.contains(where: { $0 == "-h" || $0 == "--help" }) {
        exit(EXIT_CODE_ZERO, out: serverHelp)
    }
    var index = 0
    while index < args.count {
        let current = args[index]
        index += 1
        switch current {
            case "--version", "-v":
                exit(EXIT_CODE_ZERO, out: "\(tomWmAppVersion) \(gitHash)")
            case "--config-path":
                switch args.getOrNil(atIndex: index) {
                    case let arg?: unsafe _serverArgs.configLocation = arg
                    case nil: exit(EXIT_CODE_TWO, err: "Missing <path> in --config-path flag")
                }
                index += 1
            case "--read-only": // todo rename to '--disabled' and unite with disabled feature
                unsafe _serverArgs.isReadOnly = true
            case "-NSDocumentRevisionsDebugMode" where isDebug:
                // Skip Xcode CLI args.
                // Usually it's '-NSDocumentRevisionsDebugMode NO'/'-NSDocumentRevisionsDebugMode YES'
                while args.getOrNil(atIndex: index)?.starts(with: "-") == false { index += 1 }
            default:
                exit(EXIT_CODE_TWO, err: "Unrecognized flag \(args.first.orDie().singleQuoted)")
        }
    }
    if let path = serverArgs.configLocation, !FileManager.default.fileExists(atPath: path) {
        exit(EXIT_CODE_TWO, err: "\(path) doesn't exist")
    }
}
