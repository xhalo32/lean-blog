{
  stdenv,
  leanPackages,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "verso";
  version = "4.29.0";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp ${leanPackages.verso}/.lake/build/bin/{verso-literate-plan,verso-literate-html,verso-literate,verso-html,verso} $out/bin
  '';
})
