{
  description = "Custom xdvipdfmx wrapper";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
  };

  nixConfig = {
    extra-substituters = [ "https://cache.kyouma.net" ];
    extra-trusted-public-keys = [ "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=" ];
  };

  outputs = { self, nixpkgs, ... }:
  let
    inherit (nixpkgs) lib;
    eachSystem = fn: lib.genAttrs lib.systems.flakeExposed (system: fn system
      (import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      }));
  in {
    overlays.default = import ./overlay.nix;
    packages = eachSystem (system: pkgs: {
      default = self.packages.${system}.xdvipdfmx-wrapper;
      xdvipdfmx-wrapper = pkgs.callPackage ./xdvipdfmx.nix { };
    });
  };
}
