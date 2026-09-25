# Text Mining

**Phase 3 — Context & causality.** Clusters claim comments into symptom themes (tokenize,
lemmatize, SVD, k-means), with detected phrases, synonym groups and quantitative breakdowns.

## When
- Data-selection-driven entry: find hidden failure modes ("leak vs. pressure").
- When comment review is inconsistent: cluster the parent subset.

## Parameters
Native: `run_text_mining_analysis_tool` (uses the mart `SYNONYMS` and `STOPLIST`). Templated:
CAS text-mining action set with a fixed seed. Run **per field** (`TECH_COMMENT`, `CSTMR_COMMENT`).

## Preflight
≥ 15 non-missing comments per field. With low comment coverage, use the widest scope that still
holds the pattern.

## Interpretation
- Label each cluster with a failure mode; check breakdowns (e.g. by build year).
- Inject cluster IDs into the decision tree or statistical drivers as candidate variables.
- A dominant cluster that doesn't match the claim codes is a **data-quality finding** (text-to-code
  mismatch), not a failure mode of the coded part.

## Pitfalls
Short, truncated comments (100 chars) cluster poorly; report n per cluster and keep claims modest.
