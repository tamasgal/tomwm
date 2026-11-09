// FILE IS GENERATED FROM docs/tomwm-*.adoc files
// TO REGENERATE THE FILE RUN generate.sh

let close_all_windows_but_current_help_generated = """
    USAGE: close-all-windows-but-current [-h|--help] [--quit-if-last-window]
    """
let close_help_generated = """
    USAGE: close [-h|--help] [--quit-if-last-window] [--window-id <window-id>]
    """
let config_help_generated = """
    USAGE: config [-h|--help] --get <name> [--json] [--keys]
       OR: config [-h|--help] --major-keys
       OR: config [-h|--help] --all-keys
       OR: config [-h|--help] --config-path
    """
let debug_windows_help_generated = """
    USAGE: debug-windows [-h|--help] [--window-id <window-id>]
    """
let echo_help_generated = """
    USAGE: echo [-h|--help] [--stderr] [--window-id <window-id>] -- <string>...
    """
let enable_help_generated = """
    USAGE: enable [-h|--help] toggle
       OR: enable [-h|--help] on [--fail-if-noop]
       OR: enable [-h|--help] off [--fail-if-noop]
    """
let eval_help_generated = """
    USAGE: eval [-h|--help] [--stdin] [--] <tomwm-shell-expr>
    """
let exec_and_forget_help_generated = """
    USAGE: exec-and-forget <bash-script>
    """
let false_help_generated = """
    USAGE: false [-h|--help]
    """
let floating_help_generated = """
    USAGE: floating [-h|--help] [--window-id <window-id>] [--fail-if-noop] [on|off]
    """
let focus_back_and_forth_help_generated = """
    USAGE: focus-back-and-forth [-h|--help]
    """
let focus_monitor_help_generated = """
    USAGE: focus-monitor [-h|--help] [--wrap-around] (left|down|up|right)
       OR: focus-monitor [-h|--help] [--wrap-around] (next|prev)
       OR: focus-monitor [-h|--help] [--] <monitor-pattern>...
    """
let focus_help_generated = """
    USAGE: focus [-h|--help] [--ignore-floating] [--boundaries <boundary>] [--fail-if-noop] (left|down|up|right|next|prev|master)
       OR: focus [-h|--help] --window-id <window-id>
    """
let fullscreen_help_generated = """
    USAGE: fullscreen [-h|--help]     [--window-id <window-id>] [--no-outer-gaps]
       OR: fullscreen [-h|--help] on  [--window-id <window-id>] [--no-outer-gaps] [--fail-if-noop]
       OR: fullscreen [-h|--help] off [--window-id <window-id>] [--fail-if-noop]
    """
let layout_help_generated = """
    USAGE: layout [-h|--help] [--monitor <monitor-id>] [--fail-if-noop] (tile|monocle|floating)...
       OR: layout [-h|--help] [--monitor <monitor-id>] --toggle
    """
let list_apps_help_generated = """
    USAGE: list-apps [-h|--help] [--macos-native-hidden [no]] [--format <output-format>] [--count] [--json]
    """
let list_exec_env_vars_help_generated = """
    USAGE: list-exec-env-vars [-h|--help]
    """
let list_modes_help_generated = """
    USAGE: list-modes [-h|--help] [--current] [--count] [--json]
    """
let list_monitors_help_generated = """
    USAGE: list-monitors [-h|--help] [--focused [no]] [--mouse [no]] [--format <output-format>] [--count] [--json]
    """
let list_tags_help_generated = """
    USAGE: list-tags [-h|--help] [--monitor <monitor-id>...] [--selected [no]] [--occupied [no]] [--format <output-format>]
       OR: list-tags [-h|--help] [--monitor <monitor-id>...] [--selected [no]] [--occupied [no]] [--count]
       OR: list-tags [-h|--help] [--monitor <monitor-id>...] [--selected [no]] [--occupied [no]] [--json]
    """
let list_windows_help_generated = """
    USAGE: list-windows [-h|--help] (--tag <tag>...|--monitor <monitor>...)
                        [--monitor <monitor>...] [--tag <tag>...]
                        [--pid <pid>] [--app-bundle-id <app-bundle-id>] [--format <output-format>]
                        [--count] [--json]
       OR: list-windows [-h|--help] --all [--format <output-format>] [--count] [--json]
       OR: list-windows [-h|--help] --focused [--format <output-format>] [--count] [--json]
    """
let macos_native_fullscreen_help_generated = """
    USAGE: macos-native-fullscreen [-h|--help] [--window-id <window-id>]
       OR: macos-native-fullscreen [-h|--help] [--window-id <window-id>] [--fail-if-noop] on
       OR: macos-native-fullscreen [-h|--help] [--window-id <window-id>] [--fail-if-noop] off
    """
let macos_native_minimize_help_generated = """
    USAGE: macos-native-minimize [-h|--help] [--window-id <window-id>]
    """
let mfact_help_generated = """
    USAGE: mfact [-h|--help] [--monitor <monitor-id>] <fraction>
    """
let mode_help_generated = """
    USAGE: mode [-h|--help] [--] <binding-mode>
    """
let move_mouse_help_generated = """
    USAGE: move-mouse [-h|--help] [--fail-if-noop] <mouse-position>
    """
let move_to_monitor_help_generated = """
    USAGE: move-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                                [--wrap-around] (left|down|up|right|next|prev)
       OR: move-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                                [--fail-if-noop] [--] <monitor-pattern>...
    """
let move_help_generated = """
    USAGE: move [-h|--help] [--window-id <window-id>] [--fail-if-noop] (next|prev)
    """
let nmaster_help_generated = """
    USAGE: nmaster [-h|--help] [--monitor <monitor-id>] <n>
    """
let reload_config_help_generated = """
    USAGE: reload-config [-h|--help] [--no-gui] [--dry-run] [--warnings-as-errors]
    """
let run_callback_help_generated = """
    USAGE: run-callback [-h|--help] [--for-every-window|--window-id <window-id>] on-window-detected
       OR: run-callback [-h|--help] (on-focus-changed|on-focused-monitor-changed)
    """
let subscribe_help_generated = """
    USAGE: subscribe [-h|--help] [--all] [--no-send-initial] [<event>...]
    """
let tag_help_generated = """
    USAGE: tag [-h|--help] [--window-id <window-id>] [--toggle] <tag>...
       OR: tag [-h|--help] [--window-id <window-id>] [--toggle] --index <n>...
       OR: tag [-h|--help] [--window-id <window-id>] --all
    """
let test_not_help_generated = """
    USAGE: test-not [-h|--help] <lhs> = <rhs>
       OR: test-not [-h|--help] <lhs> ~= <rhs>
    """
let test_help_generated = """
    USAGE: test [-h|--help] <lhs> = <rhs>
       OR: test [-h|--help] <lhs> ~= <rhs>
    """
let trigger_binding_help_generated = """
    USAGE: trigger-binding [-h|--help] --mode <mode-id> [--] <binding>
    """
let true_help_generated = """
    USAGE: true [-h|--help]
    """
let view_help_generated = """
    USAGE: view [-h|--help] [--monitor <monitor-id>] [--toggle] <tag>...
       OR: view [-h|--help] [--monitor <monitor-id>] [--toggle] --index <n>...
       OR: view [-h|--help] [--monitor <monitor-id>] --all
       OR: view [-h|--help] [--monitor <monitor-id>] [--back-and-forth]
    """
let volume_help_generated = """
    USAGE: volume [-h|--help] (up|down) [--no-gui]
       OR: volume [-h|--help] (mute-toggle|mute-off|mute-on) [--no-gui]
       OR: volume [-h|--help] set <number> [--no-gui]
    """
let zoom_help_generated = """
    USAGE: zoom [-h|--help] [--window-id <window-id>] [--monitor <monitor-id>]
    """
