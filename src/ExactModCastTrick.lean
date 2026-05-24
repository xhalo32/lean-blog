/-
The `exact_mod_cast` trick
%%%
htmlSplit := .never
%%%
-/
import Mathlib.Tactic
/-
Today I stumbled upon the following convenient little trick.

When proving relatively simple properties of reals which clearly holds in naturals etc, the `exact_mod_cast` tactic augmentation is quite efficient.

As an example, the following statement is tricky to prove, e.g. `grind` (or any other automation I tried) can't prove it.

```lean +error
example {n : ℕ} : (2^(n - 1) : ℝ) ≤ 2^(n + 1) := by
  induction n with grind
```

However, if you prefix `grind` with `exact_mod_cast`, it is easily solved.
-/

example {n : ℕ} : (2^(n - 1) : ℝ) ≤ 2^(n + 1) := by
  induction n with exact_mod_cast by grind

/-
Moving the cursor after the `by` shows the ℕ version of the goal which is then transported to the reals.
-/
