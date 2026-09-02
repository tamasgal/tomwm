#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-dep.sh --complgen

rm -rf .shell-completion && mkdir -p \
    .shell-completion/zsh \
    .shell-completion/fish \
    .shell-completion/bash

./.deps/cargo-root/bin/complgen aot ./grammar/commands-bnf-grammar.txt \
    --zsh-script .shell-completion/zsh/_tomwm \
    --fish-script .shell-completion/fish/tomwm.fish \
    --bash-script .shell-completion/bash/tomwm

# Check basic syntax. setup.sh treats these shells as optional dependencies, so one that is not
# installed is skipped rather than failing the build.
check-syntax() {
    shell="$1"
    shift
    if /usr/bin/which "$shell" > /dev/null 2>&1; then
        "$@"
    else
        echo "warning: $shell is not installed, skipping its completion syntax check" > /dev/stderr
    fi
}

check-syntax zsh zsh -c 'autoload -Uz compinit; compinit; source ./.shell-completion/zsh/_tomwm'
check-syntax fish fish -c 'source ./.shell-completion/fish/tomwm.fish'

# The generated bash completion uses `[[ -v array[index] ]]`, which bash gained in 4.2. macOS ships
# bash 3.2, which cannot parse it at all, so checking there would fail on syntax the completion was
# never meant to support.
if bash -c '((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2)))' 2> /dev/null; then
    check-syntax bash bash -c 'source ./.shell-completion/bash/tomwm'
else
    echo "warning: bash $(bash -c 'echo "$BASH_VERSION"') cannot parse the generated completion (4.2+ required), skipping its syntax check" > /dev/stderr
fi
