
# SAS Visual Forecasting & ATSM Context Material

The following resources and documentation links represent the core context material provided for SAS Visual Forecasting, ATSM (Automatic Time Series Modeling), and the EXTLANG (External Languages) package.

## Official Documentation Links
- **Deploying External Languages (EXTLANG):** 
  [https://documentation.sas.com/doc/en/dplyexternlang/latest/n1kmm7khf5nphcn1epjglr1yhiqt.htm](https://documentation.sas.com/doc/en/dplyexternlang/latest/n1kmm7khf5nphcn1epjglr1yhiqt.htm)
  *(Focus: Configuring SAS Viya to run Python and Open Source models natively via EXTLANG).*
- **TSMODEL EXTLANG Package Documentation (v0.77):** 
  [https://go.documentation.sas.com/doc/en/pgmsascdc/v_077/castsp/castsp_extlang_sect002.htm](https://go.documentation.sas.com/doc/en/pgmsascdc/v_077/castsp/castsp_extlang_sect002.htm)
  *(Focus: Using the EXTLANG package within PROC TSMODEL to embed Python code directly into CAS time series processing).*

## Local Books & Reference Files
- **Jira Issue (TIMEFORECAST-1032):** 
  C:\Users\germsz\OneDrive - SAS\Downloads\Jira-TIMEFORECAST-1032
  *(Focus: Bug tracking and root cause investigation for EXTLANG execution failures during Open Source model runs).*

## Key Architectural Goals
- **Minimize Data Movement:** Open Source models (e.g. Python-based forecasting) should be computed directly on the SAS Viya server using PROC TSMODEL with the EXTLANG or PROC PYTHON package, rather than pulling data down to local laptops. Only final reports/HTML should be extracted.
- **Hierarchical Reconciliation:** Leverage SAS Viya's native reconciliation techniques (e.g., MinT) after computing Open Source models to ensure that forecasts on all levels of the product hierarchy (top, inner, leaf nodes) are properly reconciled.

