{
  lib,
  buildLakePackage,
  fetchFromGitHub,
}:
let
  src = fetchFromGitHub {
    owner = "leanprover";
    repo = "subverso";
    rev = "0bd508e8362f56d4a05cbf63614d4c97db954041";
    hash = "sha256-H3qYUxHaIAZT9iLjv7i8BEEb4gwAd2t1WI4LwMKaQow=";
  };
in
buildLakePackage {
  pname = "lean4-subverso";
  version = "main";
  inherit src;

  leanPackageName = "subverso";

  # TODO tests
  # passthrough.tests = buildLakePackage {
  #   pname = "lean4-verso-test";
  #   version = "main";
  #   inherit src;

  #   leanPackageName = "versoTest";

  #   buildTargets = [ "VersoTest" ];
  # };

  # subverso doesn't have lake-manifest???

  lakeHash = null;
}
