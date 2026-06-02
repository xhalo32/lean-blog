{
  lib,
  buildLakePackage,
  fetchFromGitHub,
  plausible,
  md4lean,
  subverso,
  illuminate,
}:
let
  version = "4.30.0";
  src = fetchFromGitHub {
    owner = "leanprover";
    repo = "verso";
    tag = "v${version}";
    hash = "sha256-zreaafs3z+mb5CcoZ7QN4/goCyiixKxqnscyqnZJutM=";
  };
in
buildLakePackage {
  pname = "lean4-verso";
  inherit src version;

  leanPackageName = "verso";

  patches = [ ./verso-remove-default-targets-add-static-facets-and-fix-globs.patch ];

  # TODO lean_exe «verso-tests»
  # passthrough.tests = buildLakePackage {
  #   pname = "lean4-verso-test";
  #   version = "main";
  #   inherit src;

  #   leanPackageName = "versoTest";

  #   buildTargets = [ "VersoTest" ];
  # };

  leanDeps = [
    plausible
    md4lean
    subverso
    illuminate
  ];
}
