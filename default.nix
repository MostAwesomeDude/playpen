{ system ? builtins.currentSystem, typhonPackage ? ~/typhon/default.nix, ... }:
let
  nixpkgs = import <nixpkgs> { inherit system; };
  typhon = nixpkgs.callPackage typhonPackage {};
  jobs = with nixpkgs; {
    playpen = callPackage ./playpen.nix { inherit typhon; };
  };
in
  jobs
