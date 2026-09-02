# Architecture

## Definitions

**SPM.** Swift package manager and Swift build tool. In other words, the `swift` CLI tool

## High level project infrastructure overview

- `../Sources`.
  The majority of tomwm source code. Managed by SPM `../Package.swift`
- `../Sources/AppBundle/`.
  TomWM.app server. Technically it is an SPM library exposed to the Xcode app bundle target
- `../Sources/Cli/`.
  CLI client. Built purely with SPM, no Xcode involved
- `../Sources/Common/`.
  Shared code between server and client. Mainly command line args parsing and utils
- `../Sources/TomWmApp/`.
  A 25-line SwiftUI entry point. SPM cannot emit a macOS app bundle, only libraries and CLI
  binaries, so everything else is pushed down into the `AppBundle` library. The Xcode project in
  `../xcode/` is generated from `../xcode/project.yml` by XcodeGen and exists only to produce the
  `.app`
- `../Sources/AppBundleTests/`.
  Tests
- `../docs/`.
  Documentation sources for the site and the man pages, in Asciidoc format https://asciidoc.org/.
  Note that `../docs/tomwm-*.adoc` are BUILD INPUTS, not just documentation: `../generate.sh` globs
  them to synthesise every command's `--help` text into `../Sources/Common/cmdHelpGenerated.swift`.
  A command cannot compile without its `.adoc` file
- `../axDumps/`.
  Recorded Accessibility API dumps. They are the test fixtures for the window classification
  heuristic, and must stay byte-for-byte as captured

## client/server interaction

The `tomwm` CLI binary is the client. `TomWM.app` is the server. They talk over a UNIX socket at
`/tmp/<bundle-id>-<user>.sock`.

Each time you run a CLI command:
1. Args are parsed by the client, and parsing errors are reported. Help is shown for `-h`/`--help`
1. If parsing succeeded, the raw argv is sent to the server
1. The server parses the args again and runs the command
1. The server returns stdout, stderr and the exit code
1. The client prints them and exits with the requested code

The client also forwards `TOMWM_WINDOW_ID` and `TOMWM_MONITOR` from its environment, which is how a
command run from a callback knows what it was invoked for.

## Window model

`../Sources/AppBundle/model/`

tomwm uses dwm's model, not a tree.

- `Window` is a flat object: a window id, an owning monitor, a tag mask, whether it floats, and
  whether macOS has put it into a state we must not manage (native fullscreen, minimized, hidden
  app). `MacWindow` is the real one; `TestWindow` is the one the tests use
- `MonitorState` is dwm's `Monitor`: an ordered `clients` list which is the tiling order, an MRU
  `focusStack`, the selected `tagset`, the layout, `nmaster` and `mfact`
- Monitors have no stable identity on macOS, so `MonitorState` is keyed by the monitor's top left
  corner, and every lookup goes through `monitorStateFor(_:)`, which remaps on a miss rather than
  auto-creating an entry under a stale key. When a monitor disappears its clients are handed to the
  main monitor and re-tagged, which is dwm's `sendmon`
- `TagMask` (in `Common`) is a bitmask over the `tags` config list

## Layout subsystem

`../Sources/AppBundle/layout/`

`arrangeMonitors()` is the only place the model turns into window frames. It runs once per refresh
session and recomputes every frame from scratch, so there is no incremental state to keep
consistent. `tile` reproduces dwm's arithmetic exactly, including the incremental height division
that spreads the remainder rather than dumping it on the last window.

Windows whose tags are not currently selected are parked just off the bottom corner of the screen,
which is how tomwm hides windows without macOS Spaces.

## Refresh sessions

`../Sources/AppBundle/layout/refresh.swift`

Every event (an Accessibility notification, a hotkey, a CLI command, a menu bar click, a config
reload, the mouse) funnels into one of two entry points, and both end in `arrangeMonitors()`.
Accessibility calls never run on the MainActor: each application owns a thread with its own
run loop, and the model hops onto it.

## Commands subsystem

`../Sources/AppBundle/command/`, `../Sources/Common/cmdArgs/`

Every command is two halves: a `Sendable` `CmdArgs` struct in `Common` (shared by client and
server) and a `Command` struct in `AppBundle` that mutates the model on the MainActor. Two
exhaustive switches weld them together, so adding a `CmdKind` case makes the compiler point at
every place you still have to fill in.

Command checklist:
- [ ] `CmdKind` case and `initSubcommands()` arm in `../Sources/Common/cmdArgs/cmdArgsManifest.swift`
- [ ] `CmdArgs` struct in `../Sources/Common/cmdArgs/impl/`
- [ ] `Command` struct in `../Sources/AppBundle/command/impl/`, including `shouldResetClosedWindowsCache`
- [ ] `toCommand()` arm in `../Sources/AppBundle/command/cmdManifest.swift`
- [ ] Documentation in `../docs/tomwm-<name>.adoc`, then `./generate.sh`. This is mandatory: the
      help string is generated from that file and the code will not compile without it
- [ ] `../docs/commands.adoc` include block
- [ ] Do `--window-id` and/or `--monitor` make sense for the command?
- [ ] Shell completion in `../grammar/commands-bnf-grammar.txt`
- [ ] Tests in `../Sources/AppBundleTests/command/`

## TOML config parse subsystem

`../Sources/AppBundle/config/`

A hand-rolled TOML-to-struct mapper. `TOMLDecoder` produces a dictionary, which is normalised into
`OrderedJson` and walked by a static table of parsers, each owning a key path plus a parse closure.
Errors are collected rather than thrown, so one bad key does not abort the rest of the parse.

A removed option stays in that table bound to a `Void` field, so the error message can name its
replacement instead of just saying "unknown key".

The default config is a startup precondition: the server dies if it does not parse. It is checked
two ways, by `testParseDefaultConfig` and by `../script/check-default-config.sh`, which runs every
command in it through the real CLI parser.
