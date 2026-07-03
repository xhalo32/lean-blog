{
  lib,
  buildLakePackage,
  fetchFromGitHub,
}:
let
  src = fetchFromGitHub {
    owner = "leanprover";
    repo = "illuminate";
    rev = "20b8493528eed2fac9827ce18d41c475f0e1c50a";
    hash = "sha256-pc6vgkmC8E70/vj7b5v2cd2eLig0Gtbj0kTL6fgu+U4=";
  };
in
buildLakePackage {
  pname = "lean4-illuminate";
  version = "main";
  inherit src;

  leanPackageName = "illuminate";

  postPatch = ''
    substituteInPlace lakefile.lean \
      --replace-fail 'lean_lib «Illuminate» where' 'lean_lib «Illuminate» where
      defaultFacets := #[LeanLib.staticFacet]'
  '';

  lakeHash = null;
}
