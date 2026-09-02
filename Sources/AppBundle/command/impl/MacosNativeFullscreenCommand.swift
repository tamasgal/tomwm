import AppKit
import Common

/// Problem ID-B6E178F2: It's not first-class citizen command in TomWM model, since it interacts with macOS API directly.
/// Consecutive macos-native-fullscreen commands may not works as expected (because macOS may report correct state with a
/// delay), or may flicker
///
/// The same applies to macos-native-minimize command
struct MacosNativeFullscreenCommand: Command {
    let args: MacosNativeFullscreenCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        guard let prevState = try? await window.isMacosFullscreen(.nonCancellable) else { return .fail(io.err(bugPrompt())) }
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !prevState
        }
        if newState == prevState {
            return switch args.failIfNoop {
                case true: .fail
                case false:
                    .succ(io.err((newState ? "Already fullscreen. " : "Already not fullscreen. ") +
                            "Tip: use --fail-if-noop to exit with non-zero exit code"))
            }
        }
        window.asMacWindow().setNativeFullscreen(newState)
        // The window keeps its place in the client list either way. The next refresh session polls
        // macOS and writes the authoritative value into macosState.
        window.macosState = newState ? .nativeFullscreen : .normal
        return .succ
    }
}
