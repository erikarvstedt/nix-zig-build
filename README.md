A Nix Flake for developing Zig.

### Features
- A Nix dev shell for building Zig from src
  ```bash
  # Start dev shell
  nix develop .
  ```
- An opinionated script ([`./run`](./run)) that helps with building and testing Zig
  ```bash
  ./run buildBootstrap # Build stage3
  ./run usePrebuilt # Alternatively, use a signature-checked stage3 binary from ziglang.org
  ./run buildDebug # Use stage3 to create a Zig debug build
  ./run testBehavior # Run behavior tests for the debug build
  ```
  Getting from zero to a self-built Zig is really fast: \
  `./run usePrebuilt && ./run buildDebug` takes less than 3 minutes on an average desktop system.
- Zig `master` pkgs
  ```bash
  nix build .#zig # Built from source
  nix build .#zigPrebuilt # Prebuilt static binary from ziglang.org
  ```

This repo is regularly updated to track Zig `master`.

### Usage

See [`./usage.sh`](./usage.sh) on how to use this repo.

### Dev

See [`./dev/README.md`](./dev/README.md) on how to develop and contribute to this repo.

### See also

[zig-overlay](https://github.com/mitchellh/zig-overlay), which packages the official prebuilt static Zig binaries with Nix.
