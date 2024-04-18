#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 1. Build Zig from src (manually)

# Start the dev shell
nix develop

# You can now follow the build instructions from the Wiki
# https://github.com/ziglang/zig/wiki/Development-with-nix
# https://github.com/ziglang/zig/wiki/Building-Zig-From-Source

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 2. Build Zig from src (with ./run)
# ./run is an opinionated script that helps with building and testing Zig.
./run --help

# It accepts these env vars:
# - src (default: /tmp/zig-src)
# - build_dir (default: /tmp/zig-build)
#
# You might want to use a wrapper script that sets these variables, like so:
install -m755 <(echo '#!/usr/bin/env bash
export src=<Your Zig src>
export build_dir=<Your build dir>
. /path/to/nix-zig-build/run.sh "$@"') ~/bin/zb

## 2.1 Clone Zig repo
git clone https://github.com/ziglang/zig /tmp/zig-src

## 2.2
# Note: All ./run functions used here are idempotent.

# Build Zig from source (with optimize=ReleaseFast), using only a C compiler.
# This cmd automatically runs within the dev shell.
./run buildBootstrap
# Run Zig created by `buildBootstrap`
./run 'eval $build_dir/stage3/bin/zig help'

# Alternatively, use a pre-built Zig release binary from ziglang.org.
# This is much faster than running a bootstrap build.
./run usePrebuilt
# Run Zig created by `usePrebuilt`
./run 'eval $build_dir/stage3/bin/zig help'

## 2.3
# Build Zig from source (with optimize=Debug), using the Zig binary created in step 2.2.
# After changing the src, rebuilding with `buildDebug` is much faster than `buildBootstrap`.
./run buildDebug
# Run Zig created by `zig-debug`
./run 'eval $build_dir/zig-debug/bin/zig help'

## 2.4 Run tests using the Zig binary created by `buildDebug`
./run testStdlibFast
./run testBehavior
./run testBehavior --verbose # Print Zig build cmds
./run testBehaviorFast
./run zigSrc build --help # Show Zig build options for the Zig repo

# For more cmds, see the src of ./run

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 3. Build the Zig pkgs
# Built from source
nix build --no-link --print-out-paths -L
# Prebuilt static binary from ziglang.org
nix build --no-link --print-out-paths -L .#zigPrebuilt

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# 4. Build Zig as a statically linked executable
# This requires musl and is best achieved using zig-bootstrap.

git clone --depth 1 https://github.com/ziglang/zig-bootstrap /tmp/zig-bootstrap
# Enter bootstrap shell
nix shell .#bootstrapEnv
cd /tmp/zig-bootstrap
export CMAKE_GENERATOR=Ninja
./build x86_64-linux-musl baseline

# Run Zig
/tmp/zig-bootstrap/out/zig-x86_64-linux-musl-baseline/zig help
