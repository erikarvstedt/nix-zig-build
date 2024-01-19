{
  description = "Dev helper for building Zig from source.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }: let
    systems = ["x86_64-linux" "aarch64-linux" ];
  in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        outputs = import ./outputs.nix pkgs;
      in {
        packages = {
          default = outputs.zig;
          inherit (outputs)
            zig
            zigPrebuilt
            zigPrebuiltNoLib
            bootstrapEnv;
        };

        devShells.default = outputs.devShell;
      });
}
