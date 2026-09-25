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

## 5. Analytical Funnel & Advanced Modeling
*(Extracted from Gemini Notebook)*

Translating a broad emerging issue alert into precise truck subpopulation filter settings requires a structured analytical funnel that moves from macro-level anomaly detection to multi-variable segmentation. 

Below are the best practices for leveraging both the standard SAS Field Quality Analytics (FQA) suite and raw data analytics.

### Part 1: Standard FQA Best-Practice Workflow

To isolate actionable failure patterns in FQA, follow a 4-phase systematic funnel:

#### Phase 1: Descriptive Triage & Boundary Definition
* **Alert Triage**: Subscribe to the emerging issue alert, select the alert area and surrounding cells, and execute **Analyze Subset** to compare alert vs. non-alert data directly in the Analysis Workspace.
* **Pareto Analysis**: Run a Pareto chart on labor codes, replaced part numbers, or DTC prefixes to identify the primary subsystem or component driving the alert.
* **Summary Tables**: Cross-tabulate top failing components against high-level product attributes (e.g., engine family, transmission type, assembly plant) to spot categorical skews.
* **Geographic Analysis**: Map claim rates spatially to identify environmental or operational stressors (e.g., cold-weather embrittlement in northern regions, high torque/thermal loads in mountainous routes).
* **Time of Event & Control Charts**:
  * **Production Period Lens**: Spikes tied to specific manufacture dates indicate batch quality issues, assembly line errors, or supplier defects.
  * **Event Period Lens**: Spikes tied to calendar failure dates indicate seasonal or environmental influences.
  * **Early Life Tracking**: Use **Trend & Control** set with 1-month and 3-month maximum exposure settings to track infant mortality trends.

#### Phase 2: Algorithmic Segmentation & Filter Generation
* **Statistical Drivers Analysis**: Use this node as a dimensionality reduction step. It ranks individual categorical variables (e.g., software firmware version, axle ratio, cab configuration) by their main effect on elevated claim rates.
* **Decision Tree Analysis**: This is the primary tool for generating explicit Boolean filter rules:
  * Applies recursive partitioning (Gini index or Entropy impurity reduction) to segment the fleet into mutually exclusive cohorts.
  * Focus on terminal leaf nodes that exhibit disproportionately high claim probabilities compared to the baseline fleet average.
  * Trace the logical path backward from a high-risk terminal leaf to the root node to extract the combined filter logic (e.g., Engine = 15L Diesel AND DTC = P0299 AND Transmission = AMT AND GVWR > 80,000 lbs).
  * Save this rule set as a **Data Selection** in FQA, allowing you to re-apply the exact subpopulation filter across all other analytical nodes in the workspace.

#### Phase 3: Context & Causality Integration
* **Text Mining**:
  * Applies Natural Language Processing (tokenization, lemmatization, SVD, and k-means clustering) to Support Service Desk logs and technician notes to form structured symptom clusters (e.g., "coolant, leak, reservoir" or "bracket vibration fracture").
  * Inject these **Text Cluster IDs** back into the Decision Tree or Statistical Drivers as categorical variables to synthesize physical build attributes with qualitative failure symptoms.
* **Failure Relationships**: Maps associations and chronological sequences between primary parts, secondary damage, and labor codes via link graphs to separate the root cause component from collateral damage.
* **Details Table**: Apply the saved Data Selection filter to review unaggregated, record-by-record technician narratives as a final human validation step before taking engineering action.

#### Phase 4: Normalization & Predictive Forecasting
* **Exposure Analysis**: Normalizes claim counts against operational metrics (Time-in-Service, cumulative mileage, engine hours) to verify that the elevated claims stem from an inherent defect rather than heavy fleet utilization.
* **Reliability Analysis (Weibull Distribution)**:
  * Fits time-to-first-failure and suspension data to a Weibull distribution.
  * Evaluate the **Shape Parameter (\beta)**: \beta < 1 indicates infant mortality/assembly defects; \beta ≈ 1 indicates random/environmental failures; \beta > 1 indicates wear-out or fatigue failure modes.
  * Compare the Weibull shape parameter and projected 12-month failure rates of alert vs. non-alert groups to confirm statistical significance and project future claim liabilities.
* **Event Forecasting**: Uses time-series models (ARIMA or exponential smoothing) to forecast aggregate short-term claim costs and labor hours for financial budgeting.

### Part 2: Advanced Failure Pattern Analysis on Raw Data

With full access to raw integrated databases (Warranty, Product, Support Service Desk, and DTC telemetry), you can deploy advanced data mining outside the standard FQA interface:

1. **Association Rule Mining (Apriori Algorithm on DTC Streams)**:
   * Evaluates non-hierarchical, multi-variable combinations across DTCs, vehicle attributes, and operational conditions simultaneously without forcing a rigid tree structure.
   * Generates IF-THEN rules evaluated by **Support**, **Confidence**, and **Lift** (e.g., IF {DTC P0299} AND {Route = Mountainous} AND {Load = Heavy} THEN {Turbocharger Failure} with Lift = 4.5).
   * Enables proactive predictive maintenance on operational trucks displaying precursor DTCs before catastrophic physical failure occurs.

2. **Random Forest Ensembles (Noise Resilience & Variable Importance)**:
   * Uses bagging and feature randomness across hundreds of decision trees to handle noisy sensor data and raw DTC telemetry.
   * Calculates **Variable Importance** scores (Mean Decrease in Impurity) to uncover subtle multi-way interactions (e.g., specific software firmware interacting with transmission fluid temperature ranges).
   * Top predictor variables can be extracted and fed back into standard FQA Decision Trees to visualize decision logic.

3. **Cox Proportional Hazards Survival Modeling (PROC PHREG)**:
   * Accounts for right-censored fleet data (healthy operational trucks accumulating mileage without failure).
   * Evaluates multiple continuous and categorical covariates directly on the instantaneous hazard function.
   * **Hazard Ratios (e^{\beta_i})** quantify exact risk multipliers for specific subpopulation traits (e.g., Hazard Ratio = 2.8 for Body Material = Aluminum).

4. **Macro-Driven Automated Subgroup Discovery**:
   * SAS macros utilizing DO LOOPS with iterative PROC SQL or PROC FREQ statements systematically test thousands of variable permutations (Engine x Assembly Plant x Production Month x Cab).
   * Compares actual vs. expected claim rates using Poisson or binomial probability distributions to automatically export a ranked matrix of high-risk subpopulation filter settings.
