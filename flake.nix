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
    closure-compiler = {
      # From Makefile
      # don't upgrade until https://github.com/google/closure-compiler/issues/3972 is fixed
      url = "https://repo1.maven.org/maven2/com/google/javascript/closure-compiler/v20210601/closure-compiler-v20210601.jar";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, utils, rust-overlay, v86-src, closure-compiler }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          targets = [ "wasm32-unknown-unknown" ];
        };
      in
      {
        defaultPackage = pkgs.stdenv.mkDerivation {
          name = "v86";
          buildInputs = [];
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
      }
    );

}