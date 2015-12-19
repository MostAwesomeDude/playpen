{stdenv, lib, typhonVm, mast}:

stdenv.mkDerivation {
    name = "playpen";
    buildInputs = [ typhonVm mast ];
    buildPhase = ''
      ${typhonVm}/mt-typhon -l ${mast}/mast ${mast}/mast/montec -mix -format mast $src/playpen.mt playpen.mast
      '';
    installPhase = ''
      mkdir -p $out/bin
      cp playpen.mast $out/
      echo "${typhonVm}/mt-typhon -l ${mast}/mast $out/playpen \"\$@\"" > $out/bin/playpen
      chmod +x $out/bin/playpen
      '';
    doCheck = false;
    # Cargo-culted.
    src = builtins.filterSource (path: type: baseNameOf path == "playpen.mt") ./.;
}
