pkgs:

rec {
  release = import ./zig-release.nix;

  zig = pkgs.callPackage ./zig.nix { inherit release; };

  devShell = pkgs.mkShell {
    nativeBuildInputs = zig.nativeBuildInputs ++ (with pkgs; [
      # ninja is faster than make which is useful for incremental builds
      ninja
    ]);

    inherit (zig)
      buildInputs
      hardeningDisable;

    inZigDevEnv = 1;
  };

  zigPrebuilt = pkgs.stdenv.mkDerivation {
    pname = "zig";
    inherit (release) version;

    src = let
      inherit (pkgs.stdenv.hostPlatform) system;
    in
      pkgs.fetchurl {
        url = "https://ziglang.org/builds/zig-${system}-${release.version}.tar.xz";
        inherit (release.binaries.${system}) sha256;
      };

    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      mkdir -p $out/bin
      cp zig $out/bin
      cp -r lib/ $out
    '';
  };

  # Contains only `zig`, optimized for fast building
  zigPrebuiltNoLib = pkgs.runCommand "zig-${release.version}" {} ''
    mkdir $out
    tar xfJ ${zigPrebuilt.src} -C $out --strip-components=1 --wildcards --no-wildcards-match-slash  '*/zig'
  '';

  bootstrapEnv = pkgs.symlinkJoin {
    name = "zig-bootstrap";
    paths = with pkgs; [
      gcc
      cmake
      ninja
      python3
    ];
    preferLocalBuild = true;
  };
}
