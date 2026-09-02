public enum CmdKind: String, CaseIterable, Equatable, Sendable {
    // Sorted

    case close
    case closeAllWindowsButCurrent = "close-all-windows-but-current"
    case config
    case debugWindows = "debug-windows"
    case echo
    case enable
    case eval
    case execAndForget = "exec-and-forget"

    case _false = "false"

    case floating
    case focus
    case focusBackAndForth = "focus-back-and-forth"
    case focusMonitor = "focus-monitor"
    case fullscreen
    case layout
    case listApps = "list-apps"
    case listExecEnvVars = "list-exec-env-vars"
    case listModes = "list-modes"
    case listMonitors = "list-monitors"
    case listTags = "list-tags"
    case listWindows = "list-windows"
    case macosNativeFullscreen = "macos-native-fullscreen"
    case macosNativeMinimize = "macos-native-minimize"
    case mfact
    case mode
    case move
    case moveMouse = "move-mouse"
    case moveToMonitor = "move-to-monitor"
    case nmaster
    case reloadConfig = "reload-config"
    case runCallback = "run-callback"
    case subscribe
    case tag
    case test
    case testNot = "test-not"
    case triggerBinding = "trigger-binding"

    case _true = "true"

    case view
    case volume
    case zoom
}

func initSubcommands() -> [String: any SubCommandParserProtocol] {
    var result: [String: any SubCommandParserProtocol] = [:]
    for kind in CmdKind.allCases {
        switch kind {
            case .close:
                result[kind.rawValue] = SubCommandParser(CloseCmdArgs.init)
            case .closeAllWindowsButCurrent:
                result[kind.rawValue] = SubCommandParser(CloseAllWindowsButCurrentCmdArgs.init)
            case .config:
                result[kind.rawValue] = SubCommandParser(parseConfigCmdArgs)
            case .debugWindows:
                result[kind.rawValue] = SubCommandParser(DebugWindowsCmdArgs.init)
            case .echo:
                result[kind.rawValue] = SubCommandParser(EchoCmdArgs.init)
            case .enable:
                result[kind.rawValue] = SubCommandParser(parseEnableCmdArgs)
            case .eval:
                result[kind.rawValue] = SubCommandParser(EvalCmdArgs.init)
            case .execAndForget:
                break // exec-and-forget is parsed separately
            case ._false:
                result[kind.rawValue] = SubCommandParser(FalseCmdArgs.init)
            case .floating:
                result[kind.rawValue] = SubCommandParser(parseFloatingCmdArgs)
            case .focus:
                result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
            case .focusBackAndForth:
                result[kind.rawValue] = SubCommandParser(FocusBackAndForthCmdArgs.init)
            case .focusMonitor:
                result[kind.rawValue] = SubCommandParser(parseFocusMonitorCmdArgs)
            case .fullscreen:
                result[kind.rawValue] = SubCommandParser(parseFullscreenCmdArgs)
            case .layout:
                result[kind.rawValue] = SubCommandParser(parseLayoutCmdArgs)
            case .listApps:
                result[kind.rawValue] = SubCommandParser(parseListAppsCmdArgs)
            case .listExecEnvVars:
                result[kind.rawValue] = SubCommandParser(ListExecEnvVarsCmdArgs.init)
            case .listModes:
                result[kind.rawValue] = SubCommandParser(parseListModesCmdArgs)
            case .listMonitors:
                result[kind.rawValue] = SubCommandParser(parseListMonitorsCmdArgs)
            case .listTags:
                result[kind.rawValue] = SubCommandParser(parseListTagsCmdArgs)
            case .listWindows:
                result[kind.rawValue] = SubCommandParser(parseListWindowsCmdArgs)
            case .macosNativeFullscreen:
                result[kind.rawValue] = SubCommandParser(parseMacosNativeFullscreenCmdArgs)
            case .macosNativeMinimize:
                result[kind.rawValue] = SubCommandParser(MacosNativeMinimizeCmdArgs.init)
            case .mfact:
                result[kind.rawValue] = SubCommandParser(parseMfactCmdArgs)
            case .mode:
                result[kind.rawValue] = SubCommandParser(ModeCmdArgs.init)
            case .move:
                result[kind.rawValue] = SubCommandParser(parseMoveCmdArgs)
            case .moveMouse:
                result[kind.rawValue] = SubCommandParser(parseMoveMouseCmdArgs)
            case .moveToMonitor:
                result[kind.rawValue] = SubCommandParser(parseMoveToMonitorCmdArgs)
            case .nmaster:
                result[kind.rawValue] = SubCommandParser(parseNmasterCmdArgs)
            case .reloadConfig:
                result[kind.rawValue] = SubCommandParser(ReloadConfigCmdArgs.init)
            case .runCallback:
                result[kind.rawValue] = SubCommandParser(parseRunCallbackCmdArgs)
            case .subscribe:
                result[kind.rawValue] = SubCommandParser(parseSubscribeCmdArgs)
            case .tag:
                result[kind.rawValue] = SubCommandParser(parseTagCmdArgs)
            case .test:
                result[kind.rawValue] = SubCommandParser(parseTestCmdArgs)
            case .testNot:
                result[kind.rawValue] = SubCommandParser(parseTestNotCmdArgs)
            case .triggerBinding:
                result[kind.rawValue] = SubCommandParser(parseTriggerBindingCmdArgs)
            case ._true:
                result[kind.rawValue] = SubCommandParser(TrueCmdArgs.init)
            case .view:
                result[kind.rawValue] = SubCommandParser(parseViewCmdArgs)
            case .volume:
                result[kind.rawValue] = SubCommandParser(VolumeCmdArgs.init)
            case .zoom:
                result[kind.rawValue] = SubCommandParser(ZoomCmdArgs.init)
        }
    }
    return result
}
