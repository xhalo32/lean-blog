/-
Collection of my favorite proofs
%%%
htmlSplit := .never
%%%
-/
import Mathlib.Tactic
/-
This is a collection of proofs I wrote that are "nice."
-/

section rearranged_series

/-
# Convergence of rearranged series

While reformalizing [Tao's Analysis I Lean companion](https://teorth.github.io/analysis/Analysis/Section_7_4/), I had a go at proving the convergence of a rearranged series myself.
This is what I came up with:
-/
open Finset Filter Topology SummationFilter

variable {α : Type*} [DecidableEq α]
variable {β : Type*} [AddCommMonoid β] [PseudoMetricSpace β] [CompleteSpace β]
-- Note: one should not add [UniformSpace β] [TopologicalSpace β] as those come from [PseudoMetricSpace β]
variable {s : α → β}

theorem summable_perm (h : Summable s) (σ : Equiv.Perm α) : Summable (s ∘ σ) := by
  rw [summable_iff_cauchySeq_finset] at * -- Cauchy criterion
  rw [Metric.cauchySeq_iff] at *
  intro ε hε
  specialize h ε hε
  obtain ⟨N, h⟩ := h
  -- Map N using σ⁻¹
  refine ⟨N.map σ.symm.toEmbedding, ?_⟩
  intro p hp q hq
  -- Pick suitable p' and q' by mapping with σ
  let p' := p.map σ.toEmbedding
  let q' := q.map σ.toEmbedding
  -- These are ≥ (⊇) N due to `subset_map_symm`
  specialize h p' (subset_map_symm.mpr hp) q' (subset_map_symm.mpr hq)
  -- Now `∑ b ∈ p', s b = ∑ b ∈ p, s (σ b)`
  unfold p' q' at h
  simp at h
  exact h

end rearranged_series
