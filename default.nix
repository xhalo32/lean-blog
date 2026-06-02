let
  overlay = final: prev: {
    leanPackages = prev.leanPackages.overrideScope (
      lean-final: lean-prev: {
        md4lean = lean-final.callPackage ./nix/md4lean.nix { };
        subverso = lean-final.callPackage ./nix/subverso.nix { };
        verso = lean-final.callPackage ./nix/verso.nix { };
        illuminate = lean-final.callPackage ./nix/illuminate.nix { };
      }
    );
  };
in
{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ overlay ];
  },
}:
let
  lib = pkgs.lib;
  inherit (import ./nix/util.nix { inherit pkgs; }) mkOverridesFile;

  inherit (import ./nix/blog.nix { inherit pkgs; })
    blog
    preprocess-book
    generate-book
    livereload
    ;
in
{
  inherit (pkgs.leanPackages) md4lean verso subverso;
  inherit blog overlay;

  shell = pkgs.mkShellNoCC {
    # inputsFrom = [ blog ];
    buildInputs = [
      pkgs.lean4
      generate-book
      preprocess-book
      livereload
      pkgs.live-server
    ];
    LAKE_PACKAGES = mkOverridesFile blog.passthru.allLeanDeps;
  };
}
