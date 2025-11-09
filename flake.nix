{
  description = "v86 - x86 PC emulator and x86-to-wasm JIT, running in the browser";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    v86-src = {
      url = "github:copy/v86";
      flake = false;
    };
    seabios-src = {
      # official git repo seems to be down?
      #url = "git+https://git.seabios.org/seabios.git?ref=rel-1.16.2";
      # use github mirror instead
      url = "github:coreboot/seabios/rel-1.16.2";
      flake = false;
    };
    closure-compiler = {
      # From Makefile
      # don't upgrade until https://github.com/google/closure-compiler/issues/3972 is fixed
      url = "https://repo1.maven.org/maven2/com/google/javascript/closure-compiler/v20210601/closure-compiler-v20210601.jar";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, utils, rust-overlay, v86-src, seabios-src, closure-compiler }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          targets = [ "wasm32-unknown-unknown" ];
        };
        libv86 = pkgs.stdenv.mkDerivation {
          name = "v86";
          src = "${v86-src}";

          nativeBuildInputs = [
            rustToolchain
            pkgs.nodejs_24
            pkgs.jdk17
            pkgs.wget
            pkgs.python314

            pkgs.llvmPackages_21.clang-unwrapped
            pkgs.lld_21
          ];

          postPatch = ''
            patchShebangs --build gen/generate_analyzer.js
            patchShebangs --build gen/generate_interpreter.js
            patchShebangs --build gen/generate_jit.js
            patchShebangs --build tools/rust-lld-wrapper
          '';

          buildPhase = ''
            mkdir -p closure-compiler
            cp ${closure-compiler} closure-compiler/compiler.jar
            make all all-debug build/v86-fallback.wasm
          '';

          installPhase = ''
            mkdir -p $out
            cp \
              build/libv86-debug.js \
              build/libv86-debug.mjs \
              build/libv86.js \
              build/libv86.mjs \
              build/v86-debug.wasm \
              build/v86-fallback.wasm \
              build/v86.wasm \
              $out/
          '';
        };
        seabios = pkgs.stdenv.mkDerivation {
          name = "seabios";
          src = "${seabios-src}";
          nativeBuildInputs = [
            pkgs.python3
          ];
          configurePhase = ''
            cp "${v86-src}/bios/seabios.config" .config
          '';
          buildPhase = ''
            make
          '';
          installPhase = ''
            mkdir -p "$out"
            cp out/bios.bin "$out/seabios.bin"
            cp out/vgabios.bin "$out/vgabios.bin"
          '';
        };
        tools = pkgs.stdenv.mkDerivation {
          name = "v86-tools";
          src = "${v86-src}";
          nativeBuildInputs = [
            pkgs.python314
          ];
          buildPhase = ''
            patchShebangs --build tools/copy-to-sha256.py
            patchShebangs --build tools/fs2json.py
            patchShebangs --build tools/split-image.py
          '';
          installPhase = ''
            mkdir -p "$out/bin"
            cp tools/copy-to-sha256.py "$out/bin"
            cp tools/fs2json.py "$out/bin"
            cp tools/split-image.py "$out/bin"
          '';
        };
      in
      {
        packages = {
          inherit libv86 seabios tools;
          default = libv86;
        };
      }
    );

}