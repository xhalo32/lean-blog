/-
How to use verso, a short guide
-/

/-
# My Setup

I use nix, so my approach is nix-based.
The verso infrastructure for this blog is set up as follows:

1. Lean source code lives in `src`. It is preprocessed using `scripts/preprocess.jq` {margin}[The script is copied from [`l-oksanen/lean-notes`][lauri-notes].] which turns the lean files into verso documents.
   The processed files are written under `/Book/`.
2. To generate the book's HTML, we use `Main.lean` directly rather than invoking the `generate-book` executable.
   {margin}[The reason for not using `generate-book` from `lakefile.toml` is that it unnecessarily tries to build static facets from mathlib etc. which are not available by default and need to be compiled.]
3. Everything is packaged in `/nix/blog.nix` and the HTML page can be built with `nix build -A blog`.

[lauri-notes]: https://github.com/l-oksanen/lean-notes

Then to use it in practice, the `nix-shell` comes with [live-server](https://github.com/lomirus/live-server) and the scripts `preprocess-book` and `generate-book` to generate the book manually.

Then I run these two commands in separate shells and my browser autoreloads when the source code changes.

```
livereload
live-server -H 127.0.0.1 --hard -o _out/html-multi/
```

## Notes

- Packaging verso with nix required adding `defaultFacets := #[LeanLib.staticFacet]` to all library targets as well as removing default targets (such as tests) which don't need to be built to use verso.
  Verso does not appear to be designed to be used as a prebuilt dependency...
- We also need to patch the verso to build `Verso.Output.Html.CssVars` and `Verso.Output.Html.KaTeX` which are not exported by default.
  This can be done by patching `lean_lib Verso` with ```globs := #[.andSubmodules `Verso]```.
- Verso uses static and shared facts from MD4Lean so those need be built with nix.
-/
