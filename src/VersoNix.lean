/-
Packaging Verso Using Nix
%%%
htmlSplit := .never
%%%
-/

/-
# Introduction: verso-nix

The goal is to package [Verso](https://github.com/leanprover/verso) version 4.31.0 on nix including its test suite.
I have set up an experimental [repository verso-nix][xhalo32-verso] for this.
This blog post is about the problems I faced on the way and what I did to fix them.

[xhalo32-verso]: https://codeberg.org/xhalo32/verso-nix

## Packaging Verso

Packaging Verso on its own was quite straight-forward.
Verso needs the usual patches (add submodule globs, static facets and remove unnecessary targets) I have mentioned in a previous article [How to use verso, a short guide](../How-to-use-verso___-a-short-guide).
I also needed to add static facets to [plausible](https://github.com/leanprover-community/plausible) because otherwise lake would try to compile C code in the nix store.

```nix
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
in
buildLakePackage {
  pname = "lean4-verso";
  inherit src version;

  leanPackageName = "verso";

  patches = [ ./verso-remove-default-targets-add-static-facets-and-fix-globs.patch ];

  leanDeps = [
    plausible-static
    md4lean
    subverso
    illuminate
  ];
}
```

where [`md4lean`](https://codeberg.org/xhalo32/verso-nix/src/branch/main/md4lean.nix), [`subverso`](https://codeberg.org/xhalo32/verso-nix/src/branch/main/subverso.nix) and [`illuminate`](https://codeberg.org/xhalo32/verso-nix/src/branch/main/illuminate.nix) come from [the overlay](https://codeberg.org/xhalo32/verso-nix/src/branch/main/overlay.nix) found in the repository.

## Verso Tests

The primary challenge was to get the tests working.
During `lake test`, verso creates temporary lake repositories which in a normal environment would download dependencies (like illuminate) from the internet.
This clearly won't work for us.

To work around this, I utilized an [RFC to lean4](https://github.com/leanprover/lean4/issues/13344) that I proposed, and a proof-of-concept implementation from [my fork](https://github.com/xhalo32/lean4/tree/lake-packages-env-var-4-31-0) injected in the overlay.
The idea is to pass [package overrides](https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Lake/#package-overrides) via environment variables rather than via the `--packages` argument, which verso tests doesn't support overriding -- and I don't think they should.

I started by experimenting in a nix-shell and a local checkout of verso.
To do this I had to define the overrides file that `LAKE_PACKAGES` would point to.
Unfortunately this required copying the [overridesFile function](https://github.com/NixOS/nixpkgs/blob/36c0ecd764bb4081fd94ae132849f04991f34381/pkgs/build-support/lake/default.nix#L101) from nixpkgs as it's not exposed.

```nix
let
  # ...
  mkOverridesFile =
    allLeanDeps:
    pkgs.writeText "lake-overrides.json" (
      builtins.toJSON {
        schemaVersion = "1.2.0";
        packages = map (dep: {
          type = "path";
          name = dep.passthru.lakePackageName or dep.pname;
          inherited = false;
          dir = "${dep}";
        }) allLeanDeps;
      }
    );
in
buildLakePackage (
  finalAttrs:
  let
    overridesFile = mkOverridesFile (finalAttrs.passthru.allLeanDeps);
  in # ...
```

Next, I added the shell as a passthru to the lean4-verso derivation.
The shell sets the `LAKE_PACKAGES` environment variables to point to the `overridesFile`.
This way lake doesn't need to clone any dependencies when working in the Verso repository.

```nix
  # A shell for running the tests in a local checkout
  passthru.shell = pkgs.mkShell {
    env.LAKE_PACKAGES = overridesFile;
    buildInputs = [
      git
      unzip
      perl
      lean4
      pkgs.util-linux # unshare
    ];
  };
```

I entered the shell, changed directory to the local checkout of Verso 4.31.0 and ran the tests without network connectivity:

```
$ unshare -n -r lake test
⚠ [130/211] Replayed VersoManual.Docstring
warning: src/verso-manual/VersoManual/Docstring.lean:1535:2: `@[expose]` has no effect outside a `module` file
Running build-log tests...
[...]
Running interactive (LSP) tests...
current dir: /home/niklash/Projects/verso
could not execute external process 'src/tests/interactive/run_interactive.sh'
Interactive LSP tests failed with exit code 255
Running literate config unit tests...
[...]
Running literate HTML tests...
lake update stderr: could not execute external process 'elan'

lake update verso failed with exit code 255
Running multi-root literate HTML tests...
lake update stderr: could not execute external process 'elan'

lake update verso failed with exit code 255
Running setup-literate tests...
setup-literate failed: info: test-project: no previous manifest, creating one from scratch
info: toolchain not updated; already up-to-date
info: illuminate: cloning https://github.com/leanprover/illuminate
info: stderr:
Cloning into '/tmp/nix-shell-890600-861577778/tmp.XXaZj4CN/.lake/packages/illuminate'...
fatal: unable to access 'https://github.com/leanprover/illuminate/': SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)
error: external command 'git' exited with code 128
```

The first issue `could not execute external process 'src/tests/interactive/run_interactive.sh'` is easy to fix: the file has an invalid interpreter `#!/bin/bash`.

The second issue is more fundamental: literate HTML tests need internet connectivity as they need to clone Verso's dependencies.
I didn't find a way to fix this properly so I decided to comment out the tests `testLiterateHtml`, `testLiterateHtmlMultiRoot` and `testSetupLiterate`.

I fixed those issues in the local checkout first, and then in the derivation's `postPatch` with `substituteInPlace` and `patchShebangs`.
Then I added the checkPhase to the derivation which just runs `lake test`:

```nix
  # patches ...

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

  env.LAKE_PACKAGES = overridesFile;
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

  # leanDeps ...
```

### Timezone problem

Now, building the derivation fails during `checkPhase` to some strange test failures about `timezone not found in any zoneinfo directory`:

```
$ nix-build -A verso
[...]
------------------------------------------------
 Starting Verso Interactive Test Suite: Mon Jul  6 12:01:32 UTC 2026
------------------------------------------------
Running test: completion_inline.lean... ❌ FAIL (Exit Code: 1)
--- FAILURE LOG: completion_inline.lean ---
--- src/tests/interactive/test-cases/completion_inline.lean.expected.out        1970-01-01 00:00:01.000000000 +0000
+++ src/tests/interactive/test-cases/completion_inline.lean.produced.out        2026-07-06 12:01:33.251255178 +0000
@@ -1,25 +1,5 @@
+Watchdog error: TZ='UTC': timezone not found in any zoneinfo directory
 {"textDocument":
  {"uri": "file:///src/tests/interactive/test-cases/completion_inline.lean"},
  "position": {"line": 9, "character": 6}}
-{"items": [], "isIncomplete": true}
-{"textDocument":
- {"uri": "file:///src/tests/interactive/test-cases/completion_inline.lean"},
- "position": {"line": 14, "character": 13}}
-{"items":
- [{"label": "add_sub_assoc",
-   "kind": 23,
-   "data":
-   ["file:///src/tests/interactive/test-cases/completion_inline.lean",
-    14,
-    13,
-    0,
-    "cNat.add_sub_assoc"]},
-  {"label": "add_assoc",
-   "kind": 23,
-   "data":
-   ["file:///src/tests/interactive/test-cases/completion_inline.lean",
-    14,
-    13,
-    0,
-    "cNat.add_assoc"]}],
- "isIncomplete": false}
+uncaught exception: Cannot read LSP message: Stream was closed
ERROR: file src/tests/interactive/test-cases/completion_inline.lean.produced.out does not match src/tests/interactive/test-cases/completion_inline.lean.expected.out
```

It took me a while to find a fix, but it's a simple one: just add

```nix
env.TZDIR = "${pkgs.tzdata}/share/zoneinfo";
```

to the derivation, and voilà, the checkPhase goes through.

You can find the final nix code in the [verso-nix][xhalo32-verso] repository.

## The demo

I decided to cook up a demo starting from [VersoDemo/IntegralApprox.lean](https://live.lean-lang.org/#project=verso-demo&url=https%3A%2F%2Flive.lean-lang.org%2Fapi%2Fexample%2Fverso-demo%2FVersoDemo%2FIntegralApprox.lean).
This went quite smoothly.
The package (simplified a bit) is just:

```nix
buildLakePackage {
  pname = "demo";
  version = "4.31.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Demo.lean
      ./Main.lean
      ./lakefile.toml
      ./lake-manifest.json
      ./lean-toolchain
    ];
  };

  leanDeps = [
    verso
  ];
}
```

After building `demo`, one can run `result/bin/demo --output _out --with-html-multi --verbose` to generate the HTML document.

For convenience, I added a few passthru scripts: `generate`, `serve`, `html` and `serve-html`.

### Running locally

After entering the `demo` directory, enter the development shell `nix-shell -A shell --pure` and run `generate` (which just runs the Verso main program through `lake exe demo`)

```
$ unshare -n -r generate
⚠ [132/434] Replayed VersoManual.Docstring
warning: src/verso-manual/VersoManual/Docstring.lean:1535:2: `@[expose]` has no effect outside a `module` file
Saving multi-page HTML
Initializing extensions
Traversal pass 0
  ... pass 0 completed in 0 ms
Traversal pass 1
  ... pass 1 completed in 1 ms
Traversal pass 2
  ... pass 2 completed in 0 ms
Traversal pass 3
  ... pass 3 completed in 0 ms
Loading project config. Project is '/home/niklash/Projects/verso-nix/demo'.
No remote data configuration specified, and the default file ./verso-sources.json does not exist.
Saving _out/html-multi/index.html
```

> Using `unshare -n -r` isolates the process from the network.
> If you `unset LAKE_PACKAGES` running `lake` will fail with `error: missing manifest` as the manifest is empty on purpose as the dependencies are managed by nix.

After generating the document, run `serve` to start an HTTP server listening on [127.0.0.1:8000](http://127.0.0.1:8000).

Note: you can see if you are using my `LEAN_PACKAGES` RFC feature by running `lake --help` and looking for the following lines

```
  --packages=file       JSON file of package entries that override the manifest
                        Can be set via LAKE_PACKAGES environment variable
```

### Building with nix

> Note: for these commands you don't need to be in the development shell.

To build the demo with `nix`, simply run

```
$ nix-build -A demo.passthru.html
```

The HTML document can be found in `result`.

You can use `demo.passthru.serve-html` to build and serve the demo from the nix store:

```
$ nix-build -A demo.passthru.serve-html
$ result/bin/serve-html
```

## Other notes

- When inside the development shell, `lake clean` tries to delete artifacts from the nix store:
  ```
  $ lake clean
  error: read-only file system (error code: 4294967266)
    file: /nix/store/2c83zmjk80g7wdk02ksfiki4xbibnfyf-lean4-verso-4.31.0/.lake/build/ir/VersoMain.c.o.export.hash
  ```

- Verso's tests are not technically reproducible as some of them need internet access. They also print a bunch of timestamps, but that's less of a reproducibility issue.

-/
