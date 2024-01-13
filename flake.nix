{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem = {pkgs, ...}: {
        devShells.default = with pkgs;
          mkShell {
            packages = [
              nim
              nimPackages.nimble

              # Deps for waku
              cargo
              stdenv.cc
              pkg-config
              openssl.dev
            ];
          };
      };
    };
}
