# SAS Event Stream Processing (ESP) – Execution Rules & Context Material

Use these rules when you build, deploy, or troubleshoot SAS ESP projects on SAS Viya, especially **Kafka → ESP → CAS** pipelines.
Each rule is tagged with its evidence level:
- **[VERIFIED]**: confirmed on a live Viya 2026.08 system or in the official documentation.
- **[DOC]**: taken from the official documentation but not exercised live.
- **[HEURISTIC]**: a working practice, not formally confirmed.

---

## 0. Critical Rules (read first)

1. **Search the docs before you guess.** The full ESP 2026.08 documentation is available as grep-able text in `references/docs/` (see §6). Look up every connector/adapter property name there before using it. MCP clients can use `search_knowledge("esp", "<property>", path_glob="references/docs/*")` and then `read_knowledge_topic("esp", "references/docs/espca.txt", start_line=N)`. Templates are read the same way, with their extension (for example `templates/kafka_json_to_cas.xml`). [VERIFIED]
2. **Deploy through ESP Studio, not as raw XML.** `POST /SASEventStreamProcessingStudio/v4/projects` needs `Content-Type: application/vnd.sas.esp.espproject+json` and a JSON wrapper `{"friendlyName": "<name>", "xml": "<project …>"}`. If you send raw XML, you get `415`. If the name is missing, you get `400 [8109] The project name is empty`. Use the MCP tool `esp_deploy_project`. → `references/esp_studio_rest_api.md` [VERIFIED]
3. **When you consume Kafka on a managed broker (Confluent Cloud, Event Hubs), set `disableespmetaconsumer=true`.** If you don't, the connector tries to join the `espmeta` consumer group / metadata topic, and the ACLs on a managed cluster usually forbid that. [VERIFIED fix, DOC property]
4. **Offsets: `kafkainitialoffset=smallest` (ESP) is not the same as `auto.offset.reset=earliest` (librdkafka).** If you set `kafkaconsumergroupid` and the broker already holds committed offsets for that group, neither setting rewinds the stream. To replay, **reset the group's offsets** (template `templates/kafka_reset_offsets.py`) or use a **new group ID**. → `references/kafka_connector.md` [VERIFIED + DOC]
5. **`kafkatype=opaquestring` requires a Source window with exactly the schema `index:int64, message:string`** (any field names work, e.g. `id int64 key autogen`, `json_raw string`). The whole Kafka payload lands in the string field, and you parse it downstream in a Python/Lua window. [VERIFIED + DOC]
6. **Batch your writes to CAS.** If you write one event per block, the CAS adapter hammers CAS with small appends, and under load it fails with `IOException when trying to commit an appender: java.io.EOFException` (seen after ~17,500 events). Fix: set `blocksize=1000` on the Kafka publisher **and** `commitblocks=10` on `dfesp_cas_adapter`. → `references/cas_adapter.md` [VERIFIED]
7. **Make the CAS target schema match the subscribed window exactly.** ESP `int64` → CAS `BIGINT`. A pre-existing table with `id DOUBLE` makes the subscriber fail. If you pre-create the table, use `PROC FEDSQL` with exact types, or drop the table and let the schema match. [VERIFIED]
8. **Read the right log.** ESP Studio's log download often returns **Kubernetes operator** logs, and those never contain window or connector errors. Application errors (Python exceptions, CAS adapter errors, Kafka auth errors) are only in the **ESP server pod** log of the running project. [VERIFIED]
9. **Never put credentials in knowledge files, templates, or commits.** Kafka SASL passwords and CAS passwords belong in ESP Studio-managed environment variables or encrypted passwords (`dfesp_pwd_encrypt` + `pwdencrypted=true`) or `@VAR@` substitution. [HEURISTIC / DOC]

---

## 1. Kafka Connector (Publisher into a Source Window)
See `references/kafka_connector.md` for the full property table, semantics, and offset-management decision tree.

## 2. CAS Adapter (Subscriber from a Window into CAS)
See `references/cas_adapter.md` for the command string, throughput tuning, schema mapping, and the EOFException root cause.

## 3. Python Window (JSON flattening)
See `references/python_window.md` for the `create(data, context)` contract, timestamp conversion to ESP `stamp` (microseconds), and defensive parsing.

## 4. ESP Studio REST API & MCP Tools
See `references/esp_studio_rest_api.md`. MCP tools in `src/sas_mcp_server/tools/esp.py`: `esp_deploy_project`, `esp_get_project_xml`, `esp_delete_project`.

## 5. Troubleshooting Playbook
See `references/troubleshooting.md` (symptom → cause → fix table).

## 6. Local Documentation (grep-able)
`references/docs/` holds text extractions of the ESP 2026.08 PDFs. The PDF-to-text conversion inserts spaces inside words (for example `kafk a`), but **property names are mostly intact**, so search for exact property names (`disableespmetaconsumer`, `commitblocks`, `opaquestring`, `kafkaglobalconfig`).

| File | Manual |
|---|---|
| `espca.txt` | Connectors and Adapters (Kafka at ~L4560–5000, CAS adapter at ~L1750–1900) |
| `espxmllang.txt` | XML Language Reference |
| `espcreatewindows.txt` | Source & Derived Windows (Python/Lua windows) |
| `espan.txt` | Streaming Analytics |
| `espstudio.txt` | ESP Studio |
| `espex.txt` | ESP in Kubernetes |
| `esppsapi.txt` | Publish/Subscribe API |
| `espts.txt` | Troubleshooting |
| `espov.txt` | Overview |
| `espxmllayer.txt` | ESP Server in Edge environments |

## 7. Official Latest Documentation Links
- **espan:** [Using Streaming Analytics](https://go.documentation.sas.com/doc/en/espcdc/default/espan/titlepage.htm)
- **espca:** [Connectors and Adapters](https://go.documentation.sas.com/doc/en/espcdc/default/espca/titlepage.htm)
- **espcreatewindows:** [Using Source and Derived Windows](https://go.documentation.sas.com/doc/en/espcdc/default/espcreatewindows/titlepage.htm)
- **espex:** [Using ESP in a Kubernetes Environment](https://go.documentation.sas.com/doc/en/espcdc/default/espex/titlepage.htm)
- **espov:** [Overview](https://go.documentation.sas.com/doc/en/espcdc/default/espov/titlepage.htm)
- **esppsapi:** [Publish/Subscribe API Reference](https://go.documentation.sas.com/doc/en/espcdc/default/esppsapi/titlepage.htm)
- **espstudio:** [Using ESP Studio](https://go.documentation.sas.com/doc/en/espcdc/default/espstudio/titlepage.htm)
- **espts:** [Troubleshooting](https://go.documentation.sas.com/doc/en/espcdc/default/espts/titlepage.htm)
- **espxmllang:** [XML Language Reference](https://go.documentation.sas.com/doc/en/espcdc/default/espxmllang/titlepage.htm)
- **espxmllayer:** [Using the ESP Server in an Edge Environment](https://go.documentation.sas.com/doc/en/espcdc/default/espxmllayer/titlepage.htm)
- **Kafka `smallest` vs `earliest` (v0.75):** [Kafka connector](https://go.documentation.sas.com/doc/en/espcdc/v_075/espca/p0sbfix2ql9xpln1l1x4t9017aql.htm)

## 8. Templates
| File | Purpose |
|---|---|
| `templates/kafka_json_to_cas.xml` | Working Kafka (SASL_SSL, opaquestring) → Python flatten → CAS project, sanitized |
| `templates/kafka_reset_offsets.py` | Reset a consumer group to the low watermark (credentials via env vars) |
| `templates/create_cas_target_table.sas` | Pre-create a CAS target table with types matching the ESP window |

## 9. Example Projects
The official **[ESP Studio Examples Repository](https://github.com/sassoftware/esp-studio-examples)** has ready-to-use XML templates:
- **Practical use cases:** `activitytracker`, `geofence`, `sailing`, `trades`.
- **Lua & Python integration:** `lua_compute`, `lua_connector`, `python_compute`, `python_connector`, `patterns`.
- **ML & computer vision:** `onnx_object_detection`, `onnx_pose_estimation`, `onnx_voice_transcription`.
- **Streaming analytics:** Calculate/Train/Score windows (K-Means, SST, SVM, TF-IDF, linear regression).
- **Custom windows:** `alert_suppression`, `event_sorter`.

## 10. Case Study
`references/case_study_candf_bioreactor.md` is a complete worked example (Confluent Cloud UNS topic → ESP → CAS `BMC_RAW` → ABT), including the full debugging history.
