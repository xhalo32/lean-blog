/-
Hilbert's Basis Theorem
%%%
htmlSplit := .never
%%%
-/
import Mathlib.Tactic
open Ideal
open Polynomial
open Classical

/-
[Conrad: Noetherian Rings][conrad] is the primary source for this formalization.
You can explore this post as a lean file in [live.lean-lang.org](https://live.lean-lang.org/#url=https%3A%2F%2Fraw.githubusercontent.com%2Fxhalo32%2Flean-blog%2Frefs%2Fheads%2Fmain%2Fsrc%2FHilbertsBasisTheorem.lean).
The source code is available [here](https://github.com/xhalo32/lean-blog/blob/main/src/HilbertsBasisTheorem.lean).

# Noetherian Rings

*Definition 1.1*: A commutative ring $`R` is called _Noetherian_ if each ideal in $`R` is finitely generated.

[conrad]: https://kconrad.math.uconn.edu/blurbs/ringtheory/noetherian-ring.pdf
-/

/-
This definition [is in mathlib](https://leanprover-community.github.io/mathlib4_docs/Mathlib/RingTheory/Noetherian/Defs.html#IsNoetherianRing) and is generalized to modules.
-/
#check IsNoetherianRing

/-
We begin with the finite chain property of Noetherian rings.

*Theorem 3.1*: The following conditions on a commutative ring $`R` are equivalent:
1. $`R` is Noetherian: all ideals in $`R` are finitely generated.
2. each infinite increasing sequence of ideals $`I_1 ⊆ I_2 ⊆ I_3 ⊆ \cdots` in $`R` eventually stabilizes: $`I_k = I_{k+1}` for all large $`k`.
3. Every nonempty collection $`S` of ideals of $`R` contains a maximal element with respect to inclusion: there's an ideal in $`S` not strictly contained in another ideal in $`S`.

## Finite Chain Property

We only show $`(1) \Rightarrow (2)` as it's used in the proof of Hilbert's basis theorem.
-/

variable {R : Type*} [CommRing R]

/-
Let's begin by showing that if `a : ℕ →o Ideal R`{margin}[`→o` is a "bundled monotone function" and notation for `OrderHom`.] is a monotone sequence of ideals (i.e. $`a₀ ⊆ a₁ ⊆ \cdots`) and $`S` is a finite subset of $`\bigcup_i a_i` then $`S ⊆ a_n` for some $`n`.

The proof is a straight-forward induction in $`S`.
-/
lemma ascending_chain_exists_finset_subset {a : ℕ →o Ideal R} {S : Finset R} (hS : (S : Set R) ⊆ ⋃ i, a i) : ∃ n, (S : Set R) ⊆ a n := by
  induction S using Finset.case_strong_induction_on with
  | h₀ =>
    simp
  | h₁ x s hx ih =>
    simp at hS
    simp [Set.insert_subset_iff] at hS
    obtain ⟨hS1, hS2⟩ := hS
    specialize ih s subset_rfl hS2
    obtain ⟨n, hn⟩ := ih
    obtain ⟨m, hm⟩ := hS1
    have hx1 : x ∈ a (n ⊔ m) := a.mono (le_max_right _ _) hm
    have hS : (s : Set R) ⊆ a (n ⊔ m)
    · apply subset_trans hn
      exact a.mono (le_max_left _ _)
    rw [SupHomClass.map_sup] at hx1 hS
    use n ⊔ m
    simp [Set.insert_subset_iff]
    grind

/-
Now, $`(1) \Rightarrow (2)` of 3.1.

Let `a : ℕ →o Ideal R` i.e. $`a₀ ⊆ a₁ ⊆ \cdots`.

We start by observing that $`\bigcup_k a_k = \bigsqcup_k a_k` i.e. the union of the ideals equals their supremum.
-/

#check Submodule.coe_iSup_of_chain

/-
As $`\bigsqcup_k a_k` is finitely generated, we get $`\bigsqcup_k a_k = (s)` for some finite set $`s`.
Using the previous lemma, we get some $`m ∈ ℕ` such that $`s ⊆ a_m`.
Let $`n ≥ m`.
Now we get the following inequalities between the ideals
$$`
\bigsqcup_i a_i ≤ a_m ≤ a_n ≤ \bigsqcup_i a_i
`
therefore $`a_m = a_n` and the chain stabilizes.
-/

theorem noeth_acc [IsNoetherianRing R] (a : ℕ →o Ideal R) : ∃ n, ∀ m ≥ n, a n = a m := by
  obtain ⟨s, hs⟩ : (⨆ i, a i).FG := IsNoetherian.noetherian _
  have hs2 : (s : Set R) ⊆ ⋃ i, a i
  · rw [← Submodule.coe_iSup_of_chain, ← hs]
    exact subset_span
  obtain ⟨m, hm⟩ := ascending_chain_exists_finset_subset hs2

  use m
  intro n hn
  have h1 : ⨆ i, a i ≤ a m
  · rw [← hs, span_le]
    exact hm
  have h2 := a.mono hn
  have h3 : a n ≤ ⨆ i, a i := le_iSup _ _
  -- Now we have `⨆ i, a i ≤ a m ≤ a n ≤ ⨆ i, a i` so they are all equal
  grind

-- This is of course already in mathlib!
#check monotone_stabilizes_iff_noetherian

/-
## Setup for Hilbert's Basis Theorem

First, let's state the theorem.

*Theorem 3.6 (Hilbert Basis Theorem)*: If $`R` is a Noetherian ring, then so is $`R[X]`.

The proof begins contradiction, assume $`I` is not a finitely generated ideal of $`R[X]`.
Next we choose a sequence of polynomials $`f₁, f₂, ...` such that $`f_{k + 1} ∈ I - (f₁, ..., fₖ)` with minimal degree.

This is a tricky recursive definition, and my initial attempt at defining $`f` directly failed, so I came up with the following strategy.

1. Define a choose function $`F(s) : I` which picks a least-degree polynomial from $`I - (s)` where $`s ⊆ I` finite.
   For this, we prove existence first.
2. Define a sequence $`S_n` of finite sets recursively as follows.
   $$`
   \begin{align*}
   S_0 &= ∅ \\
   S_{n + 1} &= S_n \cup F(S_n)
   \end{align*}
   `
3. Define $`f_n = F(S_n)`.

Now we have $`S_n = {f₀, f₁, ..., f_{n-1}}`.

### Choose Function `F`

First, we show that for all finite sets $`s ⊆ I` there exists a $`g ∈ I - (s)` with minimal degree, i.e. $`deg(g) ≤ deg(h)` for all $`h ∈ I - (s)`.

We write `g : I` and `g.val ∉ span s` as the analog of $`g ∈ I - (s)`.
Unfortunately, mathlib's coercions can't convert a `Finset I` into a `Set R`, so we define an auxiliary definition `finspan` that converts from `Finset I` to `Finset R` first, and then `Finset R` can be coerced to `Set R`.
-/

noncomputable section

-- This is a def instead of an abbrev because we don't want it to unfold automatically. The rest of the API will exclusively use `finspan` instead of `span`.
def finspan {r : Type*} [Semiring r] {I : Ideal r} (s : Finset I) : Ideal r := span (s.map (Function.Embedding.subtype _))

lemma finspan_le {r : Type*} [Semiring r] {I : Ideal r} {s : Finset I} : finspan s ≤ I := by
  unfold finspan
  rw [span_le]
  intro a ha
  simp only [Finset.coe_map, Function.Embedding.subtype_apply, Set.mem_image, SetLike.mem_coe] at ha
  obtain ⟨i, hi, rfl⟩ := ha
  exact Subtype.coe_prop i

theorem exists_minimalDegree_of_not_fg {I : Ideal R[X]} (hI : ¬ I.FG) (s : Finset I) :
    ∃ g : I, g.val ∉ (finspan s).carrier ∧
    ∀ h : I, h.val ∉ (finspan s).carrier → g.val.degree ≤ h.val.degree := by
  have wf := Polynomial.degree_lt_wf (R := R)
  have hne : (I.carrier \ finspan s).Nonempty
  · have : finspan s < I
    · apply lt_of_le_of_ne finspan_le
      contrapose! hI
      rw [← hI]
      exact exists_apply_eq_apply _ _
    simp [Set.diff_nonempty, not_le_of_gt this]
  obtain ⟨g, hg_mem, hg_not_lt⟩ := wf.has_min _ hne
  rw [Set.mem_diff] at hg_mem
  refine ⟨⟨g, hg_mem.1⟩, hg_mem.2, ?_⟩
  · intro h hh
    rw [← not_lt]
    apply hg_not_lt
    rw [Set.mem_diff]
    exact ⟨h.prop, hh⟩

/-
Now it's straight-forward to define $`F` using `Exists.choose`.
It's properties are given by `Exists.choose_spec` and are exposed by `F_spec`.
-/

def F {I : Ideal R[X]} (hI : ¬ I.FG) (s : Finset I) : I := (exists_minimalDegree_of_not_fg hI s).choose

theorem F_spec {I : Ideal R[X]} (hI : ¬ I.FG) (s : Finset I)
    : (F hI s).val ∉ (finspan s).carrier ∧
    ∀ h : I, h.val ∉ (finspan s).carrier → (F hI s).val.degree ≤ h.val.degree :=
  (exists_minimalDegree_of_not_fg hI s).choose_spec

/-
### The Finite Sets `Sₙ`

The finite sets $`S_n = {f₀, f₁, ..., f_{n-1}}` for all $`n`.
As $`f₁` is chosen from $`I - (f₀) = I - S_0`, we write a recursive definition.

$$`
\begin{align*}
S_0 &= ∅ \\
S_{n + 1} &= S_n \cup F(S_n)
\end{align*}
`
-/

def S {I : Ideal R[X]} (hI : ¬ I.FG) (n : ℕ) : Finset I := match n with
  | 0 => ∅
  | n + 1 => insert (F hI (S hI n)) (S hI n)

/-
### $`f_n`
-/

def f {I : Ideal R[X]} (hI : ¬ I.FG) (n : ℕ) : I := F hI (S hI n)

/-
### API Lemmas

Next, we write a couple of API lemmas about $`S`.
Notice that we refer to $`f` instead of $`F` in the API.
-/

@[simp]
lemma S_zero {I : Ideal R[X]} (hI : ¬ I.FG) : S hI 0 = ∅ := rfl

@[simp]
lemma S_succ {I : Ideal R[X]} (hI : ¬ I.FG) {n : ℕ} : S hI (n + 1) = insert (f hI n) (S hI n) := rfl

lemma S_mono {I : Ideal R[X]} (hI : ¬ I.FG) {n m : ℕ} (h : n ≤ m) : S hI n ⊆ S hI m := by
  induction h with
  | refl =>
    rfl
  | step hm ih =>
    exact subset_trans ih (Finset.subset_insert _ _)

/-
And we also need API lemmas about $`f`.
-/

lemma f_not_mem_span {I : Ideal R[X]} (hI : ¬ I.FG) (n : ℕ) : (f hI n).val ∉ (finspan (S hI n)).carrier := (F_spec hI _).1

lemma f_forall_degree_le {I : Ideal R[X]} (hI : ¬ I.FG) (n : ℕ) : ∀ h : I, h.val ∉ (finspan (S hI n)).carrier → (f hI n).val.degree ≤ h.val.degree := (F_spec hI _).2

lemma f_degree_step {I : Ideal R[X]} (hI : ¬ I.FG) (n : ℕ) : (f hI n).val.degree ≤ (f hI (n + 1)).val.degree := by
  apply f_forall_degree_le hI
  have := f_not_mem_span hI (n + 1)
  contrapose! this
  apply span_mono _ this
  simp

theorem f_degree_mono {I : Ideal R[X]} (hI : ¬ I.FG) {n m} (h : n ≤ m) : (f hI n).val.degree ≤ (f hI m).val.degree := by
  induction h with
  | refl => rfl
  | step _ ih =>
    grw [ih, f_degree_step]

lemma f_mem_S {I : Ideal R[X]} (hI : ¬ I.FG) {n m : ℕ} (h : n < m) : f hI n ∈ S hI m := by
  apply S_mono hI h
  simp

lemma f_ne_zero {I : Ideal R[X]} (hI : ¬ I.FG) {n : ℕ} : (f hI n).val ≠ 0 := by
  intro h
  apply f_not_mem_span hI (n := n)
  simp [h]

lemma f_degree_ne_bot {I : Ideal R[X]} (hI : ¬ I.FG) {n} : (f hI n).val.degree ≠ ⊥ := by
  change ¬ _
  rw [degree_eq_bot]
  exact f_ne_zero hI

/-
## Leading Coefficients

We have made it through the first part of the proof regarding the sequence of polynomials $`(f_n)`.

Next, we define $`c_n` to be the leading coefficient of $`f_n` along with basic API.
-/

def c {I : Ideal R[X]} (hI : ¬ I.FG) (n : ℕ) : R := (f hI n).val.leadingCoeff

lemma c_def {I : Ideal R[X]} (hI : ¬ I.FG) {n : ℕ} : c hI n = (f hI n).val.leadingCoeff := rfl

lemma c_ne_zero {I : Ideal R[X]} (hI : ¬ I.FG) {n : ℕ} : c hI n ≠ 0 := by
  change ¬ _
  rw [c_def, leadingCoeff_eq_zero]
  exact f_ne_zero hI

/-
Next, we formalize the $`R`-linear combination of $`c_{m + 1}` where $`m ∈ ℕ` such that $`(c₁, c₂, ...) = (c₁, c₂, ..., cₘ)`.
In the final proof, we use the Noetherian property of $`R` (notably `noeth_acc` that was proved earlier) to get such an $`m`.

The $`R`-linear combination of $`c_{m + 1}` is

$$`
c_{m + 1} = \sum_{k = 0}^m r_k c_k
`

for some $`r_k ∈ R`.

First, we define `spanc : ℕ →o Ideal R` as the monotone sequence $`(c₀), (c₀, c₁), ...`.
As this eventually stabilizes (at $`m ∈ ℕ`) we have that
$$`
\bigsqcup_i (c₀, ..., cᵢ) = (c₀, ..., cₘ)
`
-/

-- Formalization note: `Set.range (c ∘ @Fin.toNat (m + 1))` is just `{c n | n ≤ m}`.
example {α} {c : ℕ → α} {m : ℕ} : {c n | n ≤ m} = Set.range (c ∘ @Fin.toNat (m + 1)) := by
  ext x
  simp
  constructor
  · intro hx
    obtain ⟨n, hn1, hn2⟩ := hx
    use ⟨n, by grind⟩
  · intro hx
    obtain ⟨n, hn⟩ := hx
    use n
    grind

def spanc {I : Ideal R[X]} (hI : ¬ I.FG) : ℕ →o Ideal R := ⟨fun m => span (Set.range (c hI ∘ @Fin.toNat (m + 1))), by
    apply monotone_nat_of_le_succ
    intro n
    rw [span_le]
    apply subset_trans _ subset_span
    rw [Set.range_subset_iff]
    intro k
    exact ⟨Fin.castLE (by simp) k, rfl⟩
  ⟩

lemma spanc_def {I : Ideal R[X]} (hI : ¬ I.FG) {m} : spanc hI m = span (Set.range (c hI ∘ @Fin.toNat (m + 1))) := rfl

lemma spanc_iSup_eq_spanc {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} (hm : ∀ n ≥ m, spanc hI m = spanc hI n) : ⨆ i, spanc hI i = spanc hI m := by
  apply le_antisymm
  · simp
    intro i
    by_cases hi : i ≤ m
    · simp [spanc]
      rw [span_le]
      apply subset_trans _ subset_span
      rw [Set.range_subset_iff]
      intro k
      exact ⟨Fin.castLE (by grind) k, rfl⟩
    · rw [not_le] at hi
      rw [hm _ hi.le]
  · apply le_iSup

/-
From $`cₙ ∈ (c₀, ..., cₙ)` we get $`cₙ ∈ \bigsqcup_i (c₀, ..., cᵢ) = (c₀, ..., cₘ)` using the above lemma and `Submodule.mem_iSup_of_chain`, which says that
$$`
cₙ ∈ \bigsqcup_i (c₀, ..., cᵢ) ↔ ∃ k, cₙ ∈ (c₀, ..., cₖ)
`
-/

#check Submodule.mem_iSup_of_chain

lemma c_mem_spanc {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} (hm : ∀ n ≥ m, spanc hI m = spanc hI n) {n} : (c hI n) ∈ spanc hI m := by
  rw [← spanc_iSup_eq_spanc _ hm]
  rw [Submodule.mem_iSup_of_chain]
  use n
  apply subset_span
  exact ⟨Fin.mk n (by simp), rfl⟩

/-
## Degree of `fₖ`

We define $`dₖ := deg(fₖ)` as a monotone sequence.

The degree of a polynomial ranges in `WithBot ℕ`, which adds a `⊥` element below all naturals as the degree of the zero polynomial.
-/

def d {I : Ideal R[X]} (hI : ¬ I.FG) : ℕ →o ℕ := ⟨fun k => (f hI k).val.degree.unbot (f_degree_ne_bot hI), by
    intro n m h
    simp
    exact f_degree_mono hI h
⟩

lemma d_def {I : Ideal R[X]} {hI : ¬ I.FG} {k} : d hI k = (f hI k).val.degree.unbot (f_degree_ne_bot hI) := rfl

lemma f_degree_eq {I : Ideal R[X]} {hI : ¬ I.FG} (k) : (f hI k).val.degree = d hI k := by
  rw [d_def, Nat.cast_withBot, WithBot.coe_unbot _ (f_degree_ne_bot hI)]

-- Glue for natDegree
lemma f_natDegree_eq {I : Ideal R[X]} (hI : ¬ I.FG) (k) : (f hI k).val.natDegree = d hI k := by
  change WithBot.unbotD 0 _ = _
  unfold d
  rw [WithBot.unbotD_eq_iff]
  left
  simp

/-
## The Key Polynomial

Next, we define $`pᵣ` to be the polynomial

$$`
p := \sum_{k = 0}^m r_k f_k X^{d_{m + 1} - d_k}
`

where $`rₖ ∈ R`.

and show the following
1. $`pᵣ ∈ (S_{m + 1}) = (f₀, f₁, ..., fₘ)`.
2. The coefficient of $`pᵣ` at $`X^{d_{m + 1}}` is $`c_{m + 1}`.
3. The degree of $`pᵣ` is $`d_{m + 1}`. This is almost a direct consequence of 2. and the fact that the leading coefficient of any `fₖ` is not zero (`c_ne_zero`).
4. $`pᵣ ≠ 0`.

Where 2-4 need the assumption that $`\sum_{k = 0}^m r_k c_k = c_{m + 1}`.
-/

def p {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} (r : Fin (m + 1) → R) : I := ⟨∑ k, r k • ((f hI k).val * X^(d hI (m + 1) - d hI k)), by
    apply Ideal.sum_mem
    intro k hk
    rw [smul_eq_C_mul]
    apply mul_mem_left
    apply mul_mem_right
    exact Subtype.prop _
  ⟩

lemma p_def {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} (r : Fin (m + 1) → R) : (p hI r).val = ∑ k, r k • ((f hI k).val * X^(d hI (m + 1) - d hI k)) := rfl

-- 1.
lemma p_mem {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} (r : Fin (m + 1) → R) : (p hI r).val ∈ (finspan (S hI (m + 1))) := by
  rw [p_def]
  -- This proof starts identically as p ∈ I
  apply Ideal.sum_mem
  intro k hk
  rw [smul_eq_C_mul]
  apply mul_mem_left
  apply mul_mem_right
  apply subset_span
  suffices f hI ↑k ∈ S hI (m + 1) by
    simp_all
  apply f_mem_S
  exact k.isLt

lemma hf_r_mul_coeff [Nontrivial R] {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} (r : Fin (m + 1) → R) (k : Fin (m + 1))
    : (r k • ((f hI k).val * X^(d hI (m + 1) - d hI k))).coeff (d hI (m + 1)) = r k * c hI k := by
  simp [smul_eq_C_mul]
  by_cases hr0 : r k = 0
  · simp [hr0]
  · suffices ((f hI k).val * X^(d hI (m + 1) - d hI k)).coeff (d hI (m + 1)) = c hI k by
      rw [this]
    have this : ((f hI k).val * X^(d hI (m + 1) - d hI k)).natDegree = d hI (m + 1)
    · rw [natDegree_mul_X_pow _ (f_ne_zero hI)]
      rw [f_natDegree_eq]
      -- Is it possible to make grind automatically find this?
      have : d hI k ≤ d hI (m + 1)
      · apply (d hI).mono
        simp
      grind
    nth_rw 2 [← this]
    rw [coeff_natDegree]
    exact leadingCoeff_mul_X_pow

-- 2.
lemma p_coeff_eq [Nontrivial R] {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} {r : Fin (m + 1) → R} (hr : ∑ i : Fin (m + 1), r i * c hI i = c hI (m + 1))
    : (p hI r).val.coeff (d hI (m + 1)) = c hI (m + 1) := by
  rw [← hr]
  unfold p
  rw [finset_sum_coeff]
  simp [hf_r_mul_coeff hI]

-- 3.
lemma p_degree_eq [Nontrivial R] {I : Ideal R[X]} {hI : ¬ I.FG} {m : ℕ} {r : Fin (m + 1) → R} (hr : ∑ i : Fin (m + 1), r i * c hI i = c hI (m + 1))
    : (p hI r).val.degree = d hI (m + 1) := by
  -- This proof is quite ugly and can probably be significantly shorter
  apply le_antisymm
  · rw [degree_le_iff_coeff_zero]
    intro n hn
    simp at hn
    rw [p_def]
    simp
    apply Finset.sum_eq_zero
    intro k hk
    rw [coeff_mul_X_pow']
    have : d hI (m + 1) - d hI k ≤ n
    · grind
    simp [this]
    apply mul_eq_zero_of_right
    apply coeff_eq_zero_of_natDegree_lt
    rw [f_natDegree_eq]
    have : d hI k ≤ d hI (m + 1)
    · apply (d hI).mono
      simp
    grind
  · apply le_degree_of_ne_zero
    rw [p_coeff_eq hI hr]
    exact c_ne_zero hI

-- 4.
lemma p_ne_zero [Nontrivial R] {I : Ideal R[X]} {hI : ¬ I.FG} {m : ℕ} {r : Fin (m + 1) → R} (hr : ∑ i : Fin (m + 1), r i * c hI i = c hI (m + 1))
    : (p hI r).val ≠ 0 := by
  intro h
  have hpdeg := p_degree_eq hr
  rw [h] at hpdeg
  simp at hpdeg

/-
## The Difference

Now consider the difference

$$`
f_{m + 1} - p_r = f_{m + 1} - \sum_{k = 0}^m r_k f_k X^{d_{m + 1} - d_k}
`

We show that it's not in $`(S_{m + 1}) = (f₀, f₁, ..., fₘ)` and that its degree is less than that of $`f_{m + 1}` which yields a contradiction in the final proof.
-/

lemma f_sub_p_not_mem {I : Ideal R[X]} (hI : ¬ I.FG) {m : ℕ} (r : Fin (m + 1) → R)
    : (f hI (m + 1) - p hI r).val ∉ (finspan (S hI (m + 1))) := by
  intro h
  apply f_not_mem_span hI (m + 1)
  rw [show f hI (m + 1) = f hI (m + 1) - p hI r + p hI r by simp]
  rw [Submodule.carrier_eq_coe] -- exact won't work without this
  exact add_mem h (p_mem hI r)

/-
The proof that $`f^r` has degree less than that of $`f_{m + 1}` is a direct application of `degree_sub_lt`.
-/

#check degree_sub_lt

lemma f_sub_p_degree_lt [Nontrivial R] {I : Ideal R[X]} {hI : ¬ I.FG} {m : ℕ} {r : Fin (m + 1) → R} (hr : ∑ i : Fin (m + 1), r i * c hI i = c hI (m + 1))
    : (f hI (m + 1) - p hI r).val.degree < (f hI (m + 1)).val.degree := by
  apply degree_sub_lt
  · rw [f_degree_eq, p_degree_eq hr]
  · exact f_ne_zero hI
  · change c hI (m + 1) = _
    rw [← coeff_natDegree]
    have hp_deg := p_degree_eq hr
    rw [degree_eq_iff_natDegree_eq (p_ne_zero hr)] at hp_deg
    rw [hp_deg]

    -- this is the key step
    rw [p_def]
    rw [finset_sum_coeff]
    rw [← hr]
    congr
    ext i

    simp [smul_eq_C_mul]
    rw [← hf_r_mul_coeff]
    rfl

/-
## Hilbert's Basis Theorem

Let $`I` be an ideal in $`R[X]`.
If $`R` is trivial, every ideal of $`R[X]` is `⊥`, which is finitely generated.
Therefore we can assume $`R` is not trivial.

By way of contradiction, assume $`I` is not finitely generated.
By the ascending chain property (`noeth_acc`) we get that $`(c₁, c₂, ...) = (c₁, c₂, ..., cₘ)` for some $`m ∈ ℕ`.
As $`c_{m + 1} ∈ (c₁, c₂, ..., cₘ)` (`c_mem_spanc`) it can be expressed as an $`R`-linear combination

$$`
c_{m + 1} = \sum_{k = 0}^m r_k c_k
`

for some $`r_k ∈ R`.

Now the polynomial $`f_{m + 1} - p_r ∈ I - (f₀, f₁, ..., fₘ)` (`f_sub_p_not_mem`) has degree less than that of $`f_{m + 1}` (`f_sub_p_degree_lt`), however $`f_{m + 1}` was chosen to have least degree among elements of $`I - (f₀, f₁, ..., fₘ)` (`f_forall_degree_le`) hence we get a contradiction.
-/
theorem hbt [IsNoetherianRing R] : IsNoetherianRing R[X] := by
  rw [isNoetherianRing_iff_ideal_fg]
  intro I
  by_cases h : ¬Nontrivial R
  · rw [not_nontrivial_iff_subsingleton] at h
    have : I = ⊥
    · rw [Submodule.eq_bot_iff I]
      intro x hx
      exact Subsingleton.eq_zero _
    rw [this]
    use {0}
    simp
  rw [not_not] at h

  by_contra hI
  obtain ⟨m, hm⟩ := noeth_acc (spanc hI)
  have : c hI (m + 1) ∈ spanc hI m := c_mem_spanc hI hm
  obtain ⟨r, hr⟩ := mem_span_range_iff_exists_fun.mp this
  have h1 := f_sub_p_degree_lt hr
  have h2 := f_forall_degree_le hI _ _ (f_sub_p_not_mem hI r)
  rw [← not_le] at h1
  apply h1
  exact h2

/-
## Final Words

Hilbert's basis theorem is of course available in mathlib, and the proof therein is self-contained unlike my piece-by-piece proof.
-/

#check Polynomial.isNoetherianRing
