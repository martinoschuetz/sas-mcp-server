# Text Mining

**Phase 3 — Context & causality.** Clusters claim comments into symptom themes (tokenize,
lemmatize, SVD, k-means), with detected phrases, synonym groups and quantitative breakdowns.

## When
- Data-selection-driven entry: find hidden failure modes ("leak vs. pressure").
- When comment review is inconsistent: cluster the parent subset.

## Parameters
Native: `run_text_mining_analysis_tool` (uses the mart `SYNONYMS` and `STOPLIST`). Templated:
CAS text-mining action set with a fixed seed. Run **per field** (`TECH_COMMENT`, `CSTMR_COMMENT`).

Keep the topic count low (3–5) when volume is modest: a higher count fragments one real theme
into several and invites you to read meaning into the split.

## Where the text actually lives
Check the comment columns per **event domain** before planning the run. The claim domain may
expose only one short field while the richer narrative sits in another event type on the same
units — a service-desk or workshop-order domain with symptom, previous-activity and solution
fields several thousand characters long. Reach those through the unit, not the claim: take the
cohort that had the claim of interest and pull their tickets from the other domain. Combined
domain handling must be enabled on the tenant.

## Reporting variable
The variable you report topics against decides the question:
- **production quarter** — did a new symptom narrative arrive with the new builds? Use this
  first, and as the substitute for the `alert` flag once you widen past the alert subset;
- **damage code** — is one coded symptom hiding two mechanisms? High value when the dominant
  code describes a symptom rather than a failure mode;
- **object code**, on a widened event set — do the narratives on this component mention other
  components? This is the collateral-damage read;
- **primary damaged part** — do newly appearing part numbers carry different language?

## Preflight
≥ 15 non-missing comments per field. With low comment coverage, use the widest scope that still
holds the pattern. Cluster across the whole population, then cross-tabulate cluster membership
against the alert flag: a cluster present at normal frequency in both is the established failure
mode, one that appears only from the alert window is the new mechanism.

## Interpretation
- Label each cluster with a failure mode; check breakdowns (e.g. by build year).
- Inject cluster IDs into the decision tree or statistical drivers as candidate variables.
- A dominant cluster that doesn't match the claim codes is a **data-quality finding** (text-to-code
  mismatch), not a failure mode of the coded part.

## Pitfalls
- Short, truncated comments (100 chars) cluster poorly; report n per cluster and keep claims modest.
- **Multilingual comments cluster by language, not by symptom.** On tenants spanning several
  markets the topics look entirely plausible until you notice each one maps onto a country. The
  cheap check is one run with customer country as the reporting variable; a one-to-one mapping
  means the run is worthless. The fix is to mine the dominant language alone, then repeat for the
  second and keep only themes that emerge independently in both. Language identification before
  mining helps but does not remove the need to verify.
