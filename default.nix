{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ (import sources.verso-nix { }).overlays.default ];
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
  inherit blog;

  shell = pkgs.mkShellNoCC {
    # inputsFrom = [ blog ];
    buildInputs = [
      pkgs.leanPackages.lean4
      generate-book
      preprocess-book
      livereload
      pkgs.live-server
    ];
    LAKE_PACKAGES = mkOverridesFile blog.passthru.allLeanDeps;
  };
}
