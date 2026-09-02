#!/usr/bin/env bash
# The default config is a hard startup precondition: the server dies if it does not parse.
# Every command in it is checked here, because the parse only happens at runtime otherwise.
cd "$(dirname "$0")/.."
source ./script/setup.sh

cli="${1:-./.build/debug/tomwm}"
config='docs/config-examples/default-config.toml'

python3 - "$cli" "$config" <<'PY'
import io, pathlib, shlex, subprocess, sys, tomllib

cli, config = sys.argv[1], sys.argv[2]
raw = tomllib.load(io.BytesIO(pathlib.Path(config).read_bytes()))

commands = []
def collect(value, where):
    if isinstance(value, str):
        commands.append((where, value))
    elif isinstance(value, list):
        for i, item in enumerate(value):
            collect(item, f"{where}[{i}]")

for key in ('after-startup-command', 'on-focused-monitor-changed', 'on-mode-changed'):
    collect(raw.get(key), key)
for mode_name, mode in raw.get('mode', {}).items():
    for binding, value in mode.get('binding', {}).items():
        collect(value, f"mode.{mode_name}.binding.{binding}")

failures = []
for where, command in commands:
    if command.startswith('exec-and-forget'):
        continue
    for part in command.replace('&&', ';').replace('||', ';').split(';'):
        part = part.strip()
        if not part:
            continue
        result = subprocess.run([cli, *shlex.split(part)], capture_output=True, text=True)
        if result.returncode == 2 and result.stderr.startswith('ERROR:'):
            failures.append(f"{where}: {part!r}\n    {result.stderr.strip()}")

if failures:
    print(f"{len(failures)} command(s) in {config} do not parse:\n", file=sys.stderr)
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print(f"OK: {len(commands)} commands in {config} parse")
PY
