{
  description = "A flake wrapper for v86";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    # fenix = { # error: linker `tools/rust-lld-wrapper` not found https://github.com/nix-community/fenix/issues/159 --- wait no this is v86's own rust-lld-wrapper
    #   url = "github:nix-community/fenix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
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
  #outputs = { self, nixpkgs, utils, fenix, v86-src }:
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

        # fenix-pkgs = fenix.packages.${system};
        # f = fenix-pkgs.combine [
          # fenix-pkgs.stable.toolchain
          # fenix-pkgs.targets.wasm32-unknown-unknown.stable.rust-std
        # ];
      in
      {
        defaultPackage = pkgs.stdenv.mkDerivation {
          name = "v86";
          buildInputs = [];
          src = "${v86-src}";
          #src = ./src/v86-master;#"${v86-src}";

          nativeBuildInputs = [
            # f
            rustToolchain
            pkgs.nodejs_24
            # pkgs.nasm
            # pkgs.gdb
            # pkgs.unzip
            # pkgs.p7zip
            #pkgs.jre17_minimal
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
            make all all-debug
          '';

          installPhase = ''
            mkdir -p $out/build
            cp -r build $out/.
          '';
        };
      }
    );

}