#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./swift-test.sh

./.debug/tomwm -h > /dev/null
./.debug/tomwm --help > /dev/null
./.debug/tomwm -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
./.debug/tomwm --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

# The default config is a startup precondition: the server dies if any command in it fails to parse
./script/check-default-config.sh ./.debug/tomwm

./lint.sh
./generate.sh
./script/check-uncommitted-files.sh

echo
echo "✅ All tests have passed successfully"
