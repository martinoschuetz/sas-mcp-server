import os
import re

in_path = r'C:\Users\germsz\OneDrive - SAS\Desktop\FQA_MCP\FQA_Users_Guide.md'
with open(in_path, 'r', encoding='utf-8') as f:
    content = f.read()

motivation_arch = """
## SAS Field Quality Analytics (FQA) Overview

### Motivation
Manufacturing and service organizations face significant challenges in monitoring product reliability and managing warranty costs. As products become more complex and interconnected, identifying the root causes of failures—whether they stem from specific parts, manufacturing plants, software versions, or environmental conditions—requires sifting through massive volumes of data.

**SAS Field Quality Analytics (FQA)** empowers users to:
* **Detect Issues Early (Emerging Issues):** Automatically monitor thousands of product/part combinations to detect statistically significant spikes in failure rates before they escalate into costly recalls.
* **Diagnose Root Causes:** Use an extensive suite of descriptive (Pareto, Trend) and predictive (Statistical Drivers, Decision Trees) analytical configurations to pinpoint exactly what is driving a spike in warranty claims.
* **Reduce Warranty Spend:** By shortening the time-to-detection and time-to-correction, organizations can implement manufacturing fixes or supplier chargebacks much faster.

### FQA Architecture

FQA is built on **SAS Viya** and leverages the massively parallel processing power of **SAS Cloud Analytic Services (CAS)**. 

```mermaid
flowchart TD
    subgraph Data Sources
        A[(Warranty Claims)] 
        B[(Product / Asset Data)]
        C[(Labor / Parts Data)]
    end
    
    subgraph In-Memory Engine (SAS CAS)
        D[CAS Tables / In-Memory Data]
        A --> D
        B --> D
        C --> D
    end
    
    subgraph FQA Analytical Core
        E[Data Selection Engine]
        F[Alerts / Emerging Issues Engine]
        G[Descriptive Analytics (Pareto, Trend, etc.)]
        H[Predictive Analytics (Stat Driver, Trees)]
    end
    
    D --> E
    E --> F
    E --> G
    E --> H
    
    subgraph Client Layer
        I[SAS Analytics for IoT UI]
        J[FQA MCP Server / AI Agents]
    end
    
    F --> I
    G --> I
    H --> I
    F --> J
    G --> J
    H --> J
```
- **Data Selection Engine:** The core filtering mechanism. All analyses run against a defined subset of data (a "Data Selection").
- **Alerts Engine:** Runs scheduled jobs (Emerging Issues) against Data Selections, using statistical algorithms to flag anomalous failure rates.
- **MCP Integration:** The MCP Server automates the manual UI workflows. When an Alert fires, the agent can programmatically query the top drivers, spawn a targeted Child Data Selection, and launch predictive models (Phase 2) to determine the root cause, passing results directly to the user.

---
"""

param_descriptions = {
    'analysis_var': 'The primary numeric measure to aggregate (e.g., CLAIM.CLAIMCOST or claim count).',
    'by_var': 'The variable used to stratify or group the analysis into separate series (e.g., comparing across years).',
    'report_var': 'The primary dimension or category being analyzed (e.g., Part Code, Labor Code).',
    'data_domain': 'Comma-separated list of domains/tables to include (e.g., PRODUCT, CLAIM, LABOR).',
    'usage_type': 'How product age/exposure is measured (e.g., mileage, time, hours).',
    'wrty_usage_max_mileage': 'Upper threshold for mileage to filter out extreme outliers.',
    'wrty_usage_max_hours': 'Upper threshold for operating hours to filter outliers.',
    'repair_before_sold': 'Boolean flag to include or exclude repairs that occurred before the product was sold.',
    'failures': "Specifies whether to count 'all' failures or only the 'first' failure per product.",
    'maturity_level': 'Controls data inclusion for products that have not yet reached maturity (full exposure).',
    'min_sample_size': 'The minimum number of events required for a group to be included in the results.',
    'calc_method': 'The statistical calculation method used for deriving rates.',
    'exposure_type': 'How exposure is calculated (e.g., Time in Service).',
    'control_charts': 'Boolean flag to overlay statistical control limits on Trend charts.',
    'ucl': 'Upper Control Limit configuration for charts.',
    'lcl': 'Lower Control Limit configuration for charts.',
    'data_selection_id': 'The unique UUID of the target Data Selection (the filtered population).',
    'folder_id': 'The ID of the project folder where the analysis object will be saved.',
    'parent_analysis_id': 'The ID of the parent analysis or alert from which a child analysis branches.',
    'new_filters': 'A JSON array of dictionaries specifying new filter constraints when copying a Data Selection.'
}

lines = content.split('\n')
new_lines = []
inserted_arch = False

for line in lines:
    if line.startswith('## 1.') and not inserted_arch:
        new_lines.extend(motivation_arch.split('\n'))
        inserted_arch = True
        
    if line.startswith('| `') and '` | `' in line:
        parts = line.split('|')
        if len(parts) >= 4:
            param_name = parts[1].strip().strip('`')
            desc = param_descriptions.get(param_name, '')
            current_constraint = parts[3].strip()
            if desc:
                parts[3] = f' {current_constraint}<br/>*{desc}* '
            new_lines.append('|'.join(parts))
            continue
            
    new_lines.append(line)

with open(in_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(new_lines))

print('Done applying updates to documentation!')
