{
  description = "A units replacement in Zig";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, nixpkgs, gitignore, flake-utils, flake-compat, zig, zls}:
    let
      overlays = [
        (final: prev: { 
          zigpkgs = zig.packages.${prev.system};
        })
        (final: prev: {
          zlspkgs = zls.packages.${prev.system};
        })
      ];
      systems = builtins.attrNames zig.packages;
      inherit (gitignore.lib) gitignoreSource;
    in
      flake-utils.lib.eachSystem systems (system:
        let
          pkgs = import nixpkgs { inherit overlays system; };
          zig = pkgs.zigpkgs.master-2023-04-22;
        in
          rec {
            devShells = {
              default = pkgs.mkShell {
                buildInputs = (with pkgs; [
                  zlspkgs.default
                  zig
                  gdb
                ]);
              };

              ci = pkgs.mkShell {
                buildInputs = (with pkgs; [ 
                  zig 
                ]);
              };
            };

            packages.default = packages.ulice;
            packages.ulice = pkgs.stdenvNoCC.mkDerivation {
              name = "ulice";
              version = "master";
              src = gitignoreSource ./.;
              nativeBuildInputs = [ zig ];
              dontConfigure = true;
              dontInstall = true;
              buildPhase = ''
                mkdir -p $out
                mkdir -p .cache/{p,z,tmp}
                zig build install --cache-dir $(pwd)/zig-cache --global-cache-dir $(pwd)/.cache -Dcpu=baseline -Doptimize=ReleaseSafe --prefix $out
              '';
            };
          }
      );
}
