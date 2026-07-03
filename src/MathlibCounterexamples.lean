/-
Building Mathlib Counterexamples
%%%
htmlSplit := .never
%%%
-/

/-
[Recently I had to build mathlib's Counterexamples with lean.](https://github.com/l-oksanen/lean-notes/pull/4)
As I had already opted to use nix, where `leanPackages.mathlib` doesn't come with Counterexamples, I had to come up with a workaround to avoid having to rebuild mathlib.

The solution I came up with was to simply copy `leanPackages.mathlib` to the build directory and specify the `Counterexamples` target instead.
This is the relevant nix code section:

```nix
mathlib-with-counterexamples = pkgs.leanPackages.buildLakePackage {
  pname = "mathlib-with-counterexamples";
  inherit (pkgs.leanPackages.mathlib) version meta;
  leanPackageName = pkgs.leanPackages.mathlib.passthru.lakePackageName;
  leanDeps = pkgs.leanPackages.mathlib.passthru.allLeanDeps;

  dontUnpack = true;

  buildTargets = [
    "Counterexamples"
  ];

  preBuild = ''
    cp -r ${pkgs.leanPackages.mathlib}/. .
    chmod -R u+w .
  '';
};
```

This leverages the existing mathlib derivation and nixpkgs cache.
Building the Counterexamples target only took around 1min.
-/
