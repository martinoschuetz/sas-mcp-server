import os

filepath = r"C:\Git\sas-mcp-server\knowledge\caf\mcp_execution_rules.md"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

new_section = """
## 11. Step Execution Context and Parameter Injection

When an analysis step executes via /iotAnalysis/analyses/{id}/steps/{stepId}/jobs (or from the UI), the FQA microservice dynamically prepends a block of %GLOBAL macro variables (e.g., GLOBAL G_STABLE_PERIOD 29APR24:02...) to the job's SAS code. This preamble is constructed by fetching the step's inputParameters from the PostgreSQL backend and matching them against the parameters declared in the step's input model definition. 

Critical execution gotchas discovered:
- **Parameter Mapping Failure:** If a step's parameter is saved to the Analysis Instance via REST API (and is visible in GET /iotAnalysis/analyses/{id}), it will **still fail** to inject into the SAS execution preamble if the Analysis Type definition (input node) is missing the parameter binding. The parameter will inject as a blank value (e.g., GLOBAL G_STABLE_PERIOD ), leading to catastrophic SAS macro failures (e.g., The function STRIP ... has too few arguments). 
- **Updating Parameters Programmatically:** Updating step parameters for multi-step analyses via PUT /iotAnalysis/analyses/{id} works and correctly saves to the backend. However, ensure that the *full* analysis object (all steps) is sent in the PUT payload; sending truncated step arrays can disrupt the analysis state.
- **Job Arguments are Empty:** The FQA microservice passes parameters **exclusively** via the SAS code preamble, not via the JSON jobRequest.arguments in the compute job.
"""

if "Step Execution Context and Parameter Injection" not in content:
    with open(filepath, "a", encoding="utf-8") as f:
        f.write(new_section)
    print("Updated knowledge rules.")
else:
    print("Knowledge rules already updated.")
