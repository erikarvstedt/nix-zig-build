pkgs:

rec {
  llvmPackages = pkgs.llvmPackages_17;

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

  release = import ./zig-release.nix;

  zig = let
    inherit (pkgs)
      fetchFromGitHub
      coreutils;
  in pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "zig";
    inherit (release) version;

    src = fetchFromGitHub {
      owner = "ziglang";
      repo = "zig";
      rev = release.src.rev;
      hash = release.src.hash;
    };

    # Zig's build looks at /usr/bin/env to detect the dynamic linker (ld-linux).
    # This path doesn't exist in the Nix build environment.
    postPatch = ''
      substituteInPlace lib/std/zig/system.zig \
        --replace "/usr/bin/env" "${coreutils}/bin/env"
    '';

    nativeBuildInputs = with pkgs; [
      cmake
    ];

    buildInputs = with pkgs; [
      libgcc.lib # Work around https://github.com/ziglang/zig/issues/18612 (libstdc++.so not found in rpath)
      libxml2
      zlib
    ] ++ (with llvmPackages; [
      libclang
      lld
      llvm
    ]);

    cmakeFlags = [
      # This ensures that the resulting zig binary
      # - runs on all CPUs with the same arch (like x86-64)
      # - is identical when built on different systems
      "-DZIG_TARGET_MCPU=baseline"
      # To optimize for recent x86_64 CPUs, you can set the following:
      # "-DZIG_TARGET_MCPU=x86_64_v4"

      ## Other useful options
      #
      # Statically link LLVM
      # This increases the zig binary size, but reduces the total derivation closure size.
      # "-DZIG_STATIC_LLVM=ON"
    ];

    # Silence some warnings when building stage2
    # ("_FORTIFY_SOURCE requires compiling with optimization").
    # This setting has no effect on the final Zig binary (stage3).
    hardeningDisable = [ "all" ];

    env.ZIG_GLOBAL_CACHE_DIR = "$TMP/zig-cache";

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      srcDir=$TMP/$sourceRoot
      $out/bin/zig test --cache-dir "$TMP/zig-test-cache" -I $srcDir/test $srcDir/test/behavior.zig

      runHook postInstallCheck
    '';

    passthru = { inherit llvmPackages; };

    meta = {
      description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
      homepage = "https://ziglang.org/";
      changelog = "https://ziglang.org/download/${finalAttrs.version}/release-notes.html";
      license = pkgs.lib.licenses.mit;
      mainProgram = "zig";
      platforms = pkgs.lib.platforms.unix;
    };
  });

  zigPrebuilt = pkgs.stdenv.mkDerivation {
    pname = "zig";
    inherit (release) version;

    src = let
      inherit (pkgs.stdenv.hostPlatform) system;
      zigSystem = zigSystems.${system};
    in
      pkgs.fetchurl {
        url = "https://ziglang.org/builds/zig-${zigSystem}-${release.version}.tar.xz";
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

  zigSystems = {
    x86_64-linux = "linux-x86_64";
    aarch64_linux = "linux-aarch64";
  };

  bootstrapEnv =
    pkgs.symlinkJoin {
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
