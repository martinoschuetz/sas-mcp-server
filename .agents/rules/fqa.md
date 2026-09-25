# FQA Analysis Execution Guidelines

When working with SAS Field Quality Analytics (FQA) in this MCP Server, you must adhere strictly to the following validation pattern before triggering ANY analytical tool:

## 1. Pre-Flight Data Validation & Explainability
Before executing an analysis (e.g., \
un_failure_relationships_analysis_tool\, \
un_decision_tree_analysis_tool\, etc.), you **MUST** evaluate whether the analysis is mathematically and logically sound for the current Data Selection.
- **Failure Relationships:** Requires a high volume of transactions with *multiple, distinct categorical events per product* (e.g., a truck having multiple parts replaced over time). If the underlying Data Selection is overly constrained (e.g., an Alert based on a single Labor Code or a single Part Code), the Association Rule Mining macro will fail because it cannot find sequential rules. 
- **Descriptive Analytics:** If cardinality is too high for a single dimension, recommend Pareto.
- **Predictive Analytics (Phase 2 & 3):** Ensure that the target analysis variables actually exist in the launched Data Selection profile.

**Action Required:** If you determine an analysis mathematically or logically does not make sense due to the data situation, **DO NOT EXECUTE IT**. Instead, inform the user directly in the chat with a clear explanation of *why* the algorithm cannot run on that subset of data.

## 2. Dynamic Rule Filtering & GUI Documentation
When backend CAS computations (like \PROC FEDSQL\ via \xecute_sas_code\) are used to bypass GUI limitations (such as finding sequential failure patterns when the GUI macro fails due to a single-part filter), you must ensure the user can still follow the drill-down in the FQA project tree.
- Do not leave failed analysis nodes in the FQA GUI. Clean them up via backend scripts.
- To document backend findings in the GUI, create a successful 'placeholder' analysis (such as \
un_summary_tables_analysis_tool\) with a clean name (e.g., \Phase 3 - Sequence Findings (Alert 2)\).
- Always update the \Description\ field of both the parent Data Selection and the placeholder Analysis node with a detailed markdown summary of the backend findings, so the context is preserved in the SAS FQA interface itself.
- Never use the word 'Alarm'; always use 'Alert'. Never use words like 'Fixed' in node names.

## 3. Dynamic Domain Routing (Hardware vs. Workmanship)
When transitioning from Phase 2 (Diagnostic) to Phase 3 (Predictive/Sequence), you must dynamically select the analysis domain based on the top statistical drivers:
- **Workmanship / Repair-Induced Faults:** If the Phase 2 Statistical Driver Analysis identifies variables like SELLING_DEALER_COUNTRY_CD, DEALER_CD, CSTMR_STATE_CD, or TECHNICIAN_ID as top predictors, the anomaly is likely tied to local repair practices (e.g., a technician replacing a battery and dripping acid on a secondary cable). You MUST run Phase 3 Failure Relationships on the **LABOR** domain (data_domain='PRODUCT,CLAIM,LABOR', report_var='CLAIM.PRIM_LABOR_CD') to uncover sequential repair dependencies (Repair A causing Repair B).
- **Manufacturing / Hardware Faults:** If Phase 2 identifies variables like PRODUCTION_MONTH, PLANT_CD, SUPPLIER_ID, or MODEL_CD as top predictors, the anomaly is likely a physical engineering defect. You MUST run Phase 3 Failure Relationships on the **PART** domain (data_domain='PRODUCT,CLAIM,PART', report_var='PART.REPL_PART_CD') to uncover physical collateral damage (Part A breaking Part B).


## 4. Standard operating procedure / Best Practice Workflow
The standard workflow for a Quality Analyst using FQA is as follows (extracted from the Dave Froning demo):
1. **Early Warning Workspace**: Monitor automatically generated alerts that detect statistically significant spikes in failure rates.
2. **Analyze in Project**: Push an interesting alert into a Project to isolate the data subset.
3. **Root Cause Analysis (Standard Tools)**:
   - *Pareto Analysis*: Identify the top contributing variables (e.g., top labor codes or replacement parts).
   - *Failure Relationships*: Uncover causal links (e.g., repairing Part A causes Part B to fail).
   - *Details Table*: Read the unstructured technician comments to confirm ground truth.
   - *Geographic Analysis / Decision Tree*: Find spatial concentrations or predictive variables.
   - *Text Mining*: Cluster unstructured claim comments to find hidden issues (e.g. leaks vs pressure).
4. **Assign and Track**: Update the alert's status and assign it to an engineer for resolution.
5. *(Alternative)*: Start manually in the **Data Selections** workspace to build a custom query if you already know what you are looking for.
