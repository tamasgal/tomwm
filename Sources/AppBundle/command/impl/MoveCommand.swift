import AppKit
import Common

/// Reorder the focused window in the client list, which is the tiling order. dwm's movestack patch.
struct MoveCommand: Command {
    let args: MoveCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        let state = window.monitorState
        if window.isFloating || state.layout == .floating {
            return args.failIfNoop ? .fail : .succ(io.err("Only tiled windows can be moved in the stack"))
        }

        // Positions of the tiled windows inside the client list, so the swap keeps everything else
        // where it is
        let tiledPositions = state.clients.indices.filter { state.clients[$0].isTiled }
        guard let ownIndex = state.clients.firstIndex(of: window),
              let ownPosition = tiledPositions.firstIndex(of: ownIndex),
              tiledPositions.count > 1
        else {
            return args.failIfNoop ? .fail : .succ(io.err("Nowhere to move the window"))
        }
        let step = args.direction.val == .next ? 1 : -1
        let newPosition = (ownPosition + step + tiledPositions.count) % tiledPositions.count
        state.clients.swapAt(ownIndex, tiledPositions[newPosition])
        return .succ
    }
}
