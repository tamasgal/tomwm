import Common
import Darwin
import Foundation
import Network

let usage =
    """
    USAGE: \(CommandLine.arguments.first ?? "tomwm") [-h|--help] [-v|--version] <subcommand> [<args>...]

    SUBCOMMANDS:
    \(subcommandDescriptions.sortedBy { $0[0] }.toPaddingTable(columnSeparator: "   ").joined(separator: "\n"))
    """

@main
struct Main {
    static func main() async {
        let args = CommandLine.arguments.slice(1...) ?? []

        if args.isEmpty {
            exit(EXIT_CODE_TWO, err: usage)
        }
        if args.first == "--help" || args.first == "-h" {
            exit(EXIT_CODE_ZERO, out: usage)
        }

        if args.first == "--version" || args.first == "-v" {
            let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)
            let serverVersionAndHash: String?
            switch await connection.initConnection().error {
                case nil:
                    let ans = await run(connection, [], stdin: "", windowId: nil, monitor: nil, failExitCode: EXIT_CODE_TWO)
                    serverVersionAndHash = ans.serverVersionAndHash
                case .nwError(let e):
                    eprint(e.localizedDescription)
                    serverVersionAndHash = nil
                case .customError(let msg):
                    exit(EXIT_CODE_TWO, err: msg)
            }
            print(
                """
                tomwm CLI client version: \(cliClientVersionAndHash)
                TomWM.app server version: \(serverVersionAndHash ?? "Unknown. The server is not responding")
                """,
            )
            if serverVersionAndHash != nil && cliClientVersionAndHash != serverVersionAndHash {
                eprint(
                    """
                    Warning: TomWM client/server versions don't match. Possible fixes:
                      - Restart TomWM.app (server restart is required after each update)
                      - Reinstall and restart TomWM (corrupted installation)
                    """,
                )
            }
            exit(EXIT_CODE_ZERO)
        }

        let parsedArgs: any CmdArgs
        switch parseCmdArgs(args) {
            // Optimizations
            case .cmd(_ as TrueCmdArgs): exit(ConditionalExitCode._true.rawValue)
            case .cmd(_ as FalseCmdArgs): exit(ConditionalExitCode._false.rawValue)

            case .cmd(let _parsedArgs): parsedArgs = _parsedArgs
            case .help(let help): exit(EXIT_CODE_ZERO, out: help)
            case .failure(let e): exit(e.exitCode, err: e.msg)
        }

        let failExitCode = parsedArgs.failExitCode

        let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)

        switch await connection.initConnection().error {
            case nil: break
            case .customError(let msg):
                exit(failExitCode, err: msg)
            case .nwError(let e):
                exit(failExitCode, err: "Can't connect to TomWM server. Is TomWM.app running?\n\(e.localizedDescription)")
        }

        var stdin = ""
        if parsedArgs.commonState.explicitStdinFlag == true {
            var index = 0
            while let line = readLine(strippingNewline: false) {
                stdin += line
                index += 1
                if index > 1000 {
                    exit(failExitCode, err: "stdin number of lines limit is exceeded")
                }
            }
        }

        let windowId = ProcessInfo.processInfo.environment[TOMWM_WINDOW_ID].flatMap(UInt32.init)
        let monitor = ProcessInfo.processInfo.environment[TOMWM_MONITOR].flatMap(Int.init)

        // Handle subscribe command specially
        if parsedArgs is SubscribeCmdArgs {
            await runSubscribe(connection, args, windowId: windowId, monitor: monitor, failExitCode: parsedArgs.failExitCode)
            exit(EXIT_CODE_ZERO) // Should not reach here
        }

        let ans = await run(connection, args, stdin: stdin, windowId: windowId, monitor: monitor, failExitCode: failExitCode)

        if !ans.stdout.isEmpty { print(ans.stdout) }
        if !ans.stderr.isEmpty { eprint(ans.stderr) }
        if ans.exitCode != EXIT_CODE_ZERO && ans.serverVersionAndHash != cliClientVersionAndHash {
            eprint(
                """
                Warning: TomWM client/server versions don't match
                  - tomwm CLI client version: \(cliClientVersionAndHash)
                  - TomWM.app server version: \(ans.serverVersionAndHash)
                  Possible fixes:
                  - Restart TomWM.app (server restart is required after each update)
                  - Reinstall and restart TomWM (corrupted installation)
                """,
            )
        }
        exit(ans.exitCode)
    }
}

func runSubscribe(_ connection: NWConnection, _ args: StrArrSlice, windowId: UInt32?, monitor: Int?, failExitCode: Int32) async {
    if let e = await connection.writeAtomic(ClientRequest(args: args.toArray(), stdin: "", windowId: windowId, monitor: monitor)).error {
        exit(failExitCode, err: "Failed to write to server socket: \(e)")
    }

    while true {
        switch await connection.readNonAtomic() {
            case .success(let data):
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                    unsafe fflush(stdout)
                } else {
                    exit(failExitCode, err: "Can't convert bytes to utf8 String")
                }
            case .failure(let e):
                exit(failExitCode, err: "runSubscribe error: \(e)")
        }
    }
}

func run(_ connection: NWConnection, _ args: StrArrSlice, stdin: String, windowId: UInt32?, monitor: Int?, failExitCode: Int32) async -> ServerAnswer {
    if let e = await connection.writeAtomic(ClientRequest(args: args.toArray(), stdin: stdin, windowId: windowId, monitor: monitor)).error {
        exit(failExitCode, err: "Failed to write to server socket: \(e)")
    }

    switch await connection.readNonAtomic() {
        case .success(let answer):
            return (try? JSONDecoder().decode(ServerAnswer.self, from: answer)) ?? exitT(EXIT_CODE_TWO, err: "Failed to parse server response: \(String(data: answer, encoding: .utf8).prettyDescription)")
        case .failure(let error):
            exit(failExitCode, err: "Failed to read from server socket: \(error)")
    }
}
