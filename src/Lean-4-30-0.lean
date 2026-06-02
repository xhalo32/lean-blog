/-
Lean 4.30.0 nixpkgs
%%%
htmlSplit := .never
%%%
-/

/-
# Bump from 4.29.0 to 4.30.0

- My [testing changes commit](https://github.com/xhalo32/nixpkgs/commit/be4ffd277d5e8d448424501e3701bf16f1dba9cd)
- [The PR to nixpkgs](https://github.com/NixOS/nixpkgs/pull/526718)

This is an investigation and a journal of trying to update Lean from 4.29.0 to 4.30.0.

Naïvely bumping to 4.30.0 leads to the following mysterious build error at stage0:

```
ln -f ../../../build/stage0/lib/lean/libLake.a ../../../build/stage0/lib/lean/libLake.a.export
make[7]: Leaving directory '/build/source/stage0/src/lake'
"/build/source/build/stage0/bin/leanmake" lib PKG=LeanChecker LEAN="/bin/lean" LEANC="/build/source/build/stage0/leanc.sh" OUT="../../build/stage0/lib" LIB_OUT="../../build/stage0/lib/lean" OLEAN_OUT="../../build/stage0/lib/lean" BIN_OUT="/build/source/build/stage0/bin" LEAN_OPTS+=" -Dbackward.do.legacy=false" LEANC_OPTS+=" -I/build/source/build/stage0/include -O3 -DNDEBUG" LEAN_AR="/nix/store/788mx070y81zjlg5ipcl0cra3afviw9k-gcc-wrapper-15.2.0/bin/ar" MORE_DEPS+="/bin/lean" CMAKE_LIKE_OUTPUT=1 C_ONLY=1 C_OUT=/build/source/stage0/src/../stdlib/ OUT="/build/source/build/stage0/lib/lean" LIB_OUT="/build/source/build/stage0/lib/lean" TEMP_OUT="../../build/stage0/lib/temp" OLEAN_OUT="/build/source/build/stage0/lib/lean"
make[7]: Entering directory '/build/source/stage0/src'
[    ] Building /build/source/stage0/src/../stdlib//LeanChecker.c
/build/source/build/stage0/leanc.sh -c -o ../../build/stage0/lib/temp/LeanChecker.o.export /build/source/stage0/src/../stdlib//LeanChecker.c -I/build/source/build/stage0/include -O3 -DNDEBUG -DLEAN_EXPORTING
ln -f ../../build/stage0/lib/temp/LeanChecker.o.export ../../build/stage0/lib/temp/LeanChecker.o
make[7]: Leaving directory '/build/source/stage0/src'
make[6]: Leaving directory '/build/source/stage0/src'
make[5]: Leaving directory '/build/source/build/stage0'
[ 98%] Built target make_stdlib
make[4]: Leaving directory '/build/source/build/stage0'
make[3]: *** [Makefile:146: all] Error 2
make[3]: Leaving directory '/build/source/build/stage0'
make[2]: *** [CMakeFiles/stage0.dir/build.make:95: stage0-prefix/src/stage0-stamp/stage0-build] Error 2
make[2]: Leaving directory '/build/source/build'
make[1]: *** [CMakeFiles/Makefile2:138: CMakeFiles/stage0.dir/all] Error 2
make[1]: Leaving directory '/build/source/build'
make: *** [Makefile:136: all] Error 2
```

> Source: I built this [`package.nix`](https://github.com/xhalo32/nixpkgs/blob/be4ffd277d5e8d448424501e3701bf16f1dba9cd/pkgs/by-name/le/lean4/package.nix) (failing)

Initially I thought the solution is to switch to using Clang as [leanprover/lean4/flake.nix](github.com/leanprover/lean4/blob/d024af099ca4bf2c86f649261ebf59565dc8c622/flake.nix) used that, and after some tweaking, I got 4.30.0 to compile.
However, trying to build lean manually (outside of nix) with GCC through `nix develop`, the build succeeded so the failure was not due to GCC vs Clang.
The "minor tweak" I mentioned was setting `INSTALL_LEANTAR` to `OFF` in both `CMakeLists.txt`.
Changing to Clang didn't have an impact after all.

> Source: [`lean4-clang.nix`](https://github.com/xhalo32/nixpkgs/blob/be4ffd277d5e8d448424501e3701bf16f1dba9cd/pkgs/by-name/le/lean4/lean4-clang.nix) (builds successfully)

## Leantar issues

I found a mention of `INSTALL_LEANTAR` in [this FreeBSD forum post from 2026-05-28](https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=295656) which links to [this fix](https://cgit.freebsd.org/ports/commit/?id=516f8a5764de5c7bdd0e9f7810601a5057bbc650).
Their fix adds `leangz` as a dependency which contains the `leantar` binary.

The logic for resolving `LEANTAR` is in `/CMakeLists.txt` from line 80 onwards but `INSTALL_LEANTAR` is in `/src/CMakeLists.txt`, and it's the line 800 that fails in the nix build:

```
if(LEANTAR AND INSTALL_LEANTAR)
  add_custom_target(
    copy-leantar
    COMMAND cmake -E copy_if_different "${LEANTAR}" "${CMAKE_BINARY_DIR}/bin/leantar${CMAKE_EXECUTABLE_SUFFIX}"
  )
  add_dependencies(leancpp copy-leantar)
endif()
```

Notice that adding `-DINSTALL_LEANTAR=OFF` to cmakeFlags doesn't disable line 800 in `/src/CMakeLists.txt`.
Instead I had to hardcode `INSTALL_LEANTAR` to `OFF` using the following patches:

```
substituteInPlace stage0/src/CMakeLists.txt \
  --replace-fail 'option(INSTALL_LEANTAR "Install a copy of leantar" ON)' 'option(INSTALL_LEANTAR "Install a copy of leantar" OFF)'
substituteInPlace src/CMakeLists.txt \
  --replace-fail 'option(INSTALL_LEANTAR "Install a copy of leantar" ON)' 'option(INSTALL_LEANTAR "Install a copy of leantar" OFF)'
```

> These are found in [`lean4-gcc-leantar-off-default-preset.nix`](https://github.com/xhalo32/nixpkgs/blob/be4ffd277d5e8d448424501e3701bf16f1dba9cd/pkgs/by-name/le/lean4/lean4-gcc-leantar-off-default-preset.nix) (builds successfully)

When I started looking more closely at the logs of the original 4.30.0 build attempt, i.e. [`package.nix`](https://github.com/xhalo32/nixpkgs/blob/be4ffd277d5e8d448424501e3701bf16f1dba9cd/pkgs/by-name/le/lean4/package.nix), I noticed the following error occurring in early stage of the build logs:

```
make[5]: *** [CMakeFiles/copy-leantar.dir/build.make:70: CMakeFiles/copy-leantar] Error 1
make[5]: Leaving directory '/build/source/build/release/stage0'
make[4]: *** [CMakeFiles/Makefile2:1347: CMakeFiles/copy-leantar.dir/all] Error 2
```

Grepping for `copy-leantar` I found this in other failed build attempts too.
This finally explains the mysterious error 2: the actual error was simply buried deep in the logs.

## Fixing leantar

> For reference, [this is the PR where leantar was added to lean4](https://github.com/leanprover/lean4/pull/12822)

`leantar` is not actually used as part of the build process, its only purpose is to be copied to the final output `bin`.
E.g. building this file [`lean4-leantar-mock.nix`](https://github.com/xhalo32/nixpkgs/blob/be4ffd277d5e8d448424501e3701bf16f1dba9cd/pkgs/by-name/le/lean4/lean4-leantar-mock.nix) succeeds and the mock ends up in the output.

Looking at the FreeBSD fix, they add `-DLEANTAR=${LOCALBASE}/bin/leantar` which seems to be unnecessary when `INSTALL_LEANTAR` is anyways off.
Maybe they faced the same issue that simply setting `-DINSTALL_LEANTAR=OFF` doesn't actually disable the `copy-leantar` step (i.e. line 800).

My goal next was to avoid having to disable `INSTALL_LEANTAR` and to actually provide it in native build inputs.
I packaged `leangz` as part of [`lean4-with-leangz.nix`](https://github.com/xhalo32/nixpkgs/blob/be4ffd277d5e8d448424501e3701bf16f1dba9cd/pkgs/by-name/le/lean4/lean4-with-leangz.nix) which builds successfully (as expected).

## Pretty-lean flake

I [reached out to the community](https://leanprover.zulipchat.com/#narrow/channel/113488-general/topic/nixpkgs.3A.20bumping.20lean.20packages.20from.204.2E29.2E0.20to.204.2E30.2E0/with/598863783) and [got a very helpful reply](https://leanprover.zulipchat.com/#narrow/channel/113488-general/topic/nixpkgs.3A.20bumping.20lean.20packages.20from.204.2E29.2E0.20to.204.2E30.2E0/near/598863783) which linked me to the [flake.nix in pretty-lean](https://github.com/wvhulle/pretty-lean/blob/master/flake.nix).

The way the build is split into multiple stages looks nice and I wonder if we should integrate that to nixpkgs or if it's overkill.

I did not investigate this further due to the following observations
1. The flake.nix from pretty-lean didn't work out of the box with the 4.30.0 source.
1. The lean output of pretty-lean doesn't copy leantar over.

## Open questions and potential improvements

- Why does the build not exit immediately on copy-leantar failure? Should we try to make it fail fast, or at least warn the user that the actual error might be buried deep in the logs?
- Could we unify pkgs.lean4 and leanPackages.lean4?
  - What is the reason that leanPackages.lean4 contains a patch to `src/lake/Lake/Load/Lean/Elab.lean`? I managed to get some libraries building through `buildLakePackage` using just pkgs.lean4...
- The lack of `defaultFacets = ["static"]` is a widespread issue across many lean libraries (like Batteries, Cli and Verso).
  - We should highlight the issue of "missing static facets fail to build when the dependency is in a read-only environment" to upstream repositories.
- Should leanPackages support both GCC and Clang stdenvs?
  - [This PR](https://github.com/NixOS/nixpkgs/pull/457058) attempts to fix some issues at elan level.

-/
