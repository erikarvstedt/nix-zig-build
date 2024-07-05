{ lib
, stdenv
, fetchFromGitHub
, cmake
, coreutils
, llvmPackages_18
, libgcc
, libxml2
, xz
, icu
, zlib
, release
}:

let
  llvmPackages = llvmPackages_18;
in
stdenv.mkDerivation (finalAttrs: {
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

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    libgcc.lib # Work around https://github.com/ziglang/zig/issues/18612 (libstdc++.so not found in rpath)
    libxml2
    zlib
    xz
    icu
  ] ++ (with llvmPackages; [
    libclang
    lld
    llvm
  ]);

  LD_LIBRARY_PATH = lib.makeLibraryPath [ xz icu ];

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

  preConfigure = ''
    export ZIG_GLOBAL_CACHE_DIR=$TMP/zig-cache;
  '';

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
    license = lib.licenses.mit;
    mainProgram = "zig";
    platforms = lib.platforms.unix;
  };
})
