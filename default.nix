let
  overlay = final: prev: {
    leanPackages = prev.leanPackages.overrideScope (
      lean-final: lean-prev: {
        md4lean = lean-final.callPackage ./nix/md4lean.nix { };
        subverso = lean-final.callPackage ./nix/subverso.nix { };
        verso = lean-final.callPackage ./nix/verso.nix { };
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
  inherit (import ./nix/util.nix {inherit pkgs;}) mkOverridesFile;

  lean4-src-branch = pkgs.fetchFromGitHub {
    repo = "lean4";
    owner = "xhalo32";
    rev = "de81323214ba25d8080acbe3edd5917f4bd38936";
    hash = "sha256-Kvd/bN7EqrQPy+49d7ULPSR9QtZhbCGh8Ol1+pW3VKM=";
  };

  leanPackagesPatched = pkgs.leanPackages.overrideScope (
    self: super: {
      lean4 = (
        super.lean4.override {
          # HACK inject custom lean4 to leanPackages
          fetchFromGitHub =
            args:
            if args.repo or "" == "lean4" then
              # lean4-src-local
              lean4-src-branch // { tag = args.tag; } # This is used as LEAN_GITHASH which needs to match the version mathlib etc. are built against
            else
              pkgs.fetchFromGitHub args;
        }
      );
    }
  );

  inherit (import ./nix/blog.nix { inherit pkgs; }) blog preprocess-book generate-book livereload;
in
{
  # inherit (pkgs.leanPackages) md4lean verso subverso;
  inherit blog;
  verso-lib = pkgs.leanPackages.verso;
  shell = pkgs.mkShellNoCC {
    # inputsFrom = [ blog ];
    buildInputs = [
      leanPackagesPatched.lean4
      generate-book
      preprocess-book
      livereload
      pkgs.live-server
    ];
    LAKE_PACKAGES = mkOverridesFile blog.passthru.allLeanDeps;
  };
}
