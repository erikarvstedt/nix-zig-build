#!/usr/bin/env bash
set -euo pipefail

trap 'echo "Error at ${BASH_SOURCE[0]}:$LINENO"' ERR

cd "${BASH_SOURCE[0]%/*}"

test_pkg() {
    nix build --no-link --print-out-paths -L ..
}

test_manual_build() {
    tmpdir=$(mktemp -d /tmp/test-nix-zig-build.XXX)
    echo "Using tmp dir $tmpdir"
    export src=$tmpdir/src
    export build_dir=$tmpdir/build_dir
    nix build -o "$src" ..#zig.src
    printAndRun ../run buildBootstrap
    printAndRun ../run buildDebug
    printAndRun ../run testBehaviorFast
    rm -rf "$tmpdir"
}

test_manual_build_prebuilt() {
    tmpdir=$(mktemp -d /tmp/test-nix-zig-build-prebuilt.XXX)
    echo "Using tmp dir $tmpdir"
    export src=$tmpdir/src
    export build_dir=$tmpdir/build_dir
    nix build -o "$src" ..#zig.src
    printAndRun ../run usePrebuilt
    printAndRun ../run buildDebug
    printAndRun ../run testBehaviorFast
    rm -rf "$tmpdir"
}

# These tests are run for CI
test_ci() {
    printAndRun test_pkg
    printAndRun test_manual_build_prebuilt
}

test_quick() {
    printAndRun test_manual_build_prebuilt
}

test_all() {
    printAndRun test_pkg
    printAndRun test_manual_build
    printAndRun test_manual_build_prebuilt
}

printAndRun() {
    printf "%q " "$@"; echo
    eval "$@"
}

eval "$@"
