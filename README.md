# Lean blog

Build with:
```
nix-build -A blog
```

The generated site will be in `result/`.

You can inspect the result with e.g.

```
python -m http.server 8000 -d result
```

## Live reload

The nix-shell comes with a `livereload` command.

If you hit a weird error like

```
error: (interpreter) unknown declaration 'Lean.Name.toStringWithSep._at_.Lake.LeanExeConfig.exeName._proj.spec_0'
```

then try removing `.lake`.

---

```
Copyright (C) 2026  Niklas Halonen
```