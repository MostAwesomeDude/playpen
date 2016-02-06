{ typhon }:

let
  playpen = typhon.montePackage rec {
    name = "playpen";
    version = "0.0.0.0";
    entrypoints = [ "playpen" ];
    # Cargo-culted.
    src = builtins.filterSource (path: type: baseNameOf path == "playpen.mt") ./.;
  };
  mtpkg = { monte-playpen = playpen; };
in
  playpen
