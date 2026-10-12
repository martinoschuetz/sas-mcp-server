---
name: sas-esp
description: SAS Event Stream Processing (ESP) rules and context material. Use when building, deploying, or troubleshooting ESP projects on SAS Viya, including Kafka connectors (SASL_SSL/Confluent Cloud, offsets, opaquestring), Python windows for JSON flattening, the CAS adapter (streaming into CAS tables), and the ESP Studio REST API / MCP tools (esp_deploy_project, esp_get_project_xml, esp_delete_project).
---

Start with `mcp_execution_rules.md`, then read §0 "Critical Rules" before you write or deploy any ESP XML.

Topic references (load on demand):
- `references/kafka_connector.md`: Kafka publisher connector, auth, offsets, consumer groups
- `references/cas_adapter.md`: `dfesp_cas_adapter` subscriber, throughput, schema mapping
- `references/python_window.md`: Python window contract and JSON flattening
- `references/esp_studio_rest_api.md`: ESP Studio v4 REST API and MCP tool behavior
- `references/troubleshooting.md`: symptom → cause → fix
- `references/case_study_candf_bioreactor.md`: end-to-end worked example
- `references/docs/*.txt`: full ESP 2026.08 manuals as grep-able text
- `templates/`: sanitized, working XML, Python, and SAS templates
