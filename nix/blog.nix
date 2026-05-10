{ pkgs, ... }:
let
  lib = pkgs.lib;
  inherit (import ./util.nix {inherit pkgs;}) mkOverridesFile;

  # TODO the jq script includes unnecessary new lines inside ```lean blocks
  preprocess-book = pkgs.writeShellScriptBin "preprocess-book" ''
    mkdir -p Book
    for file in src/*.lean; do
      echo "Preprocessing $file"

      name=$(basename "$file")
      jq -Rsr -f scripts/preprocess.jq <$file >Book/$name
    done
  '';

  blog = pkgs.leanPackages.buildLakePackage {
    pname = "lean4-blog";
    version = "0.1.0";
    src = pkgs.nix-gitignore.gitignoreSource [ ] ../.;

    leanPackageName = "blog";

    buildTargets = ["Book"]; # This is also set in lakefile.toml as the only default

    # Generate Book subdirectory
    preBuild = ''
      ${lib.getExe preprocess-book}
    '';

    postBuild =
      # Recursively get lean deps
      let overridesFile = mkOverridesFile blog.passthru.allLeanDeps; in
    ''
      lake --no-ansi --packages=${overridesFile} env lean --run Main.lean --output _out --with-html-multi --verbose
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r _out/html-multi/. $out/
      runHook postInstall
    '';

    leanDeps = [
      pkgs.leanPackages.verso
      pkgs.leanPackages.mathlib
    ];
  };

  generate-book = pkgs.writeShellScriptBin "generate-book" ''
    lake build && lake env lean --run Main.lean --output _out --with-html-multi --verbose
  '';

  livereload = pkgs.writeShellScriptBin "livereload" ''
    inotifywait -r -m -q -e close_write src Book.lean | while read -r phat event file; do preprocess-book && generate-book; done
  '';
in
{
  inherit blog preprocess-book generate-book livereload;
}