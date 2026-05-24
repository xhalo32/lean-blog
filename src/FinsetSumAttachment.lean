/-
TODO:
- Explain `with` notation https://github.com/leanprover-community/mathlib4/pull/11563
- How to actually work with .attach?
- How to split a ∑ x ∈ (A ∪ B).attach?
- Key challenge when X is a Finset X': a function X → Y can exist if both are empty. Such a function cannot be extended to X' → Y
  - Potential solution: use 0 from addcommmonoid
- Motivation: to prove binomial theorem with `prod_attach_eq_iff` lemma
- Attach is "one way only", can't rewrite left.
- `sum_partition` uses `sum_attach`
-/


/-
Problem with grind and nofun

/-- error: Lean.Meta.realizeConst: _example.match_1.congr_eq_1 was not added to the environment -/
#guard_msgs in
example : ∃ f : Icc 1 0 → (∅ : Set ℕ), Function.Bijective f := by
  refine ⟨nofun, ?_⟩
  -- aesop -- works
  grind

also

example : ∃ f : Icc 1 0 → (∅ : Set ℕ), Function.Bijective f := by
  refine ⟨?_, ?_⟩
  aesop
  aesop
-/


namespace Finset

variable [CommMonoid M]

-- Maybe not so useful after all
@[to_additive]
lemma prod_attach_eq_prod_with (s : Finset ι) (f : s → M) [DecidablePred (· ∈ s)] :
    ∏ i ∈ s.attach, f i = ∏ i ∈ s with h : i ∈ s, f ⟨i, h⟩ := by
  rw [Finset.prod_dite, Finset.univ_eq_attach, Finset.prod_const_one, mul_one]
  congr
  · simp
  · ext; simp
  · apply Function.hfunext <;> simp +contextual [Subtype.heq_iff_coe_eq]

end Finset



/-
Now we can write `∑ i ∈ X.attach, f (g i)` instead of `∑ i ∈ X with hi : i ∈ X, f (g ⟨i, hi⟩)`.
-/

lemma Finset.bijOn_attach {X':Type*} {X Y : Finset X'} {g : X → Y} (hg: Function.Bijective g) : Set.BijOn (Subtype.val ∘ g) X.attach Y := by
  refine ⟨?_, ?_, ?_⟩
  · simp
  · exact Subtype.val_injective.comp_injOn hg.injective.injOn
  · intro y hy
    obtain ⟨x, hx⟩ := hg.surjective ⟨y, hy⟩
    grind

theorem finite_series_of_rearrange_attach_left {X':Type*} {X Y : Finset X'} {f : X' → ℝ} {g : X → Y} (hg: Function.Bijective g) :
    ∑ i ∈ X.attach, f (g i) = ∑ i ∈ Y, f i := by
  apply sum_nondep_bij (i := Subtype.val ∘ g) _ (bijOn_attach hg).injOn (bijOn_attach hg).surjOn
  · simp
  · simp

/-
This is another reformulation of the original `finite_series_of_rearrange` using the `attach` API.
-/
theorem finite_series_of_rearrange_attach {X':Type*} {X Y : Finset X'} {f : X' → ℝ} (g h : X → Y) (hg: Function.Bijective g) (hh: Function.Bijective h) :
    ∑ i ∈ X.attach, f (g i) = ∑ i ∈ X.attach, f (h i) := by
  rw [finite_series_of_rearrange_attach_left hg, finite_series_of_rearrange_attach_left hh]
