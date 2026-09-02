#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="0.0.0-SNAPSHOT"
codesign_identity="tomwm-codesign-certificate"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

#############
### BUILD ###
#############

./build-docs.sh --release
./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh
./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity" --generate-git-hash

swift build -c release --arch arm64 --arch x86_64 --product tomwm -Xswiftc -warnings-as-errors # CLI

# todo: make xcodebuild use the same toolchain as swift
# toolchain="$(plutil -extract CFBundleIdentifier raw ~/Library/Developer/Toolchains/swift-6.1-RELEASE.xctoolchain/Info.plist)"
# xcodebuild -toolchain "$toolchain" \
# Unfortunately, Xcode 16 fails with:
#     2025-05-05 15:51:15.618 xcodebuild[4633:13690815] Writing error result bundle to /var/folders/s1/17k6s3xd7nb5mv42nx0sd0800000gn/T/ResultBundle_2025-05-05_15-51-0015.xcresult
#     xcodebuild: error: Could not resolve package dependencies:
#       <unknown>:0: warning: legacy driver is now deprecated; consider avoiding specifying '-disallow-use-new-driver'
#     <unknown>:0: error: unable to execute command: <unknown>

rm -rf .release && mkdir .release

cd ./xcode
    xcode_configuration="Release"
    xcodebuild -version
    xcodebuild-pretty ../.release/xcodebuild.log clean build \
        -scheme TomWM \
        -destination "generic/platform=macOS" \
        -configuration "$xcode_configuration" \
        -derivedDataPath .xcode-build
cd -

git checkout .

cp -r "xcode/.xcode-build/Build/Products/$xcode_configuration/TomWM.app" .release
cp -r .build/apple/Products/Release/tomwm .release

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" .release/tomwm

################
### VALIDATE ###
################

expected_layout=$(cat <<EOF
.release/TomWM.app
.release/TomWM.app/Contents
.release/TomWM.app/Contents/_CodeSignature
.release/TomWM.app/Contents/_CodeSignature/CodeResources
.release/TomWM.app/Contents/MacOS
.release/TomWM.app/Contents/MacOS/TomWM
.release/TomWM.app/Contents/Resources
.release/TomWM.app/Contents/Resources/default-config.toml
.release/TomWM.app/Contents/Resources/AppIcon.icns
.release/TomWM.app/Contents/Resources/Assets.car
.release/TomWM.app/Contents/Info.plist
.release/TomWM.app/Contents/PkgInfo
EOF
)

if test "$expected_layout" != "$(find .release/TomWM.app)"; then
    echo "!!! Expect/Actual layout don't match !!!"
    find .release/TomWM.app
    exit 1
fi

check-universal-binary() {
    if ! file "$1" | grep --fixed-string -q "Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64"; then
        echo "$1 is not a universal binary"
        exit 1
    fi
}

check-contains-hash() {
    hash=$(git rev-parse HEAD)
    if ! strings "$1" | grep --fixed-string "$hash" > /dev/null; then
        echo "$1 doesn't contain $hash"
        exit 1
    fi
}

check-universal-binary .release/TomWM.app/Contents/MacOS/TomWM
check-universal-binary .release/tomwm

check-contains-hash .release/TomWM.app/Contents/MacOS/TomWM
check-contains-hash .release/tomwm

codesign -v .release/TomWM.app
codesign -v .release/tomwm

############
### PACK ###
############

mkdir -p ".release/TomWM-v$build_version/manpage" && cp .man/*.1 ".release/TomWM-v$build_version/manpage"
cp -r ./legal ".release/TomWM-v$build_version/legal"
cp -r .shell-completion ".release/TomWM-v$build_version/shell-completion"
cd .release
    mkdir -p "TomWM-v$build_version/bin" && cp -r tomwm "TomWM-v$build_version/bin"
    cp -r TomWM.app "TomWM-v$build_version"
    zip -r "TomWM-v$build_version.zip" "TomWM-v$build_version"
cd -

echo
echo "Built .release/TomWM-v$build_version.zip"
echo "To install: unzip it and drag TomWM.app into /Applications, and put bin/tomwm on your PATH"
