{
  lib,
  buildLakePackage,
  fetchFromGitHub,
  plausible,
  md4lean,
  subverso,
  illuminate,
  pkgs,
  # Test dependencies
  runCommandCC,
  git,
  unzip,
  perl,
  lean4,
  elan,
}:
let
  version = "4.31.0";
  src = fetchFromGitHub {
    owner = "leanprover";
    repo = "verso";
    tag = "v${version}";
    hash = "sha256-tWqtpWs6bGvx+hJTctTcL9Tv+eCMapbs/1bQcFBXcY4=";
  };
  plausible-static = plausible.overrideAttrs (prevAttrs: {
    # Pre-build static library for downstream executables.
    postPatch = ''
      substituteInPlace lakefile.toml \
        --replace-fail '[[lean_lib]]
      name = "Plausible"' '[[lean_lib]]
      name = "Plausible"
      defaultFacets = ["static"]'
    '';
  });

  inherit (import ./util.nix { inherit pkgs; }) mkOverridesFile;
in
buildLakePackage (
  finalAttrs:
  let
    overridesFile = mkOverridesFile (finalAttrs.passthru.allLeanDeps);
  in
  rec {
    pname = "lean4-verso";
    inherit src version;

    leanPackageName = "verso";

    patches = [ ./verso-remove-default-targets-add-static-facets-and-fix-globs.patch ];

    # Disable tests that try to clone lake dependencies
    postPatch = ''
      substituteInPlace src/tests/TestMain.lean \
        --replace-fail "testLiterateHtml,
        testLiterateHtmlMultiRoot,
        testSetupLiterate" \
        "-- testLiterateHtml,
        -- testLiterateHtmlMultiRoot,
        -- testSetupLiterate"
      patchShebangs src
    '';

    # Without this interactive tests fail with
    #   +fatal: unable to access 'https://github.com/leanprover/illuminate/': Could not resolve host: github.com
    # So it seems to be working
    env.LAKE_PACKAGES = overridesFile;
    # Interactive tests fail with
    #   +Watchdog error: TZ='UTC': timezone not found in any zoneinfo directory
    # if TZDIR is not set
    env.TZDIR = "${pkgs.tzdata}/share/zoneinfo";
    doCheck = true;
    nativeCheckInputs = [
      git
      unzip
      perl
    ];
    checkPhase = ''
      runHook preCheck

      lake test

      runHook postCheck
    '';

    leanDeps = [
      plausible-static
      md4lean
      subverso
      illuminate
    ];

    passthru.tests.test =
      let
        tests = buildLakePackage {
          inherit
            pname
            src
            version
            leanPackageName
            patches
            postPatch
            leanDeps
            ;

          isLibrary = false;
          buildTargets = [ "verso-tests" ];
        };
      in
      runCommandCC "verso-tests"
        {
          inherit src;
          buildInputs = [
            git
            unzip
            perl
            lean4
            # elan
          ];
          # Without this interactive tests fail with
          #   +fatal: unable to access 'https://github.com/leanprover/illuminate/': Could not resolve host: github.com
          # So it seems to be working
          env.LAKE_PACKAGES = overridesFile;
          # Interactive tests fail with
          #   +Watchdog error: TZ='UTC': timezone not found in any zoneinfo directory
          # if TZDIR is not set
          env.TZDIR = "${pkgs.tzdata}/share/zoneinfo";
        }
        ''
          cp -r $src/. .
          chmod -R u+w .
          patchShebangs src
          zdump Europe/Helsinki
          echo Running ${tests}/bin/verso-tests
          ${tests}/bin/verso-tests
          # lake test
          touch $out
        '';

    # A shell for running the tests in
    passthru.shell = pkgs.mkShell {
      env.LAKE_PACKAGES = overridesFile;
      inputsFrom = [ passthru.tests.test ];
      buildInputs = [
        pkgs.util-linux # unshare
      ];
    };
  }
)
