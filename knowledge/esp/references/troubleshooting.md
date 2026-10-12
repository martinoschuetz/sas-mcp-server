# ESP Troubleshooting Playbook (Kafka → ESP → CAS)

| # | Symptom | Root cause | Fix | Evidence |
|---|---|---|---|---|
| 1 | `IOException when trying to commit an appender: java.io.EOFException` after N thousand events | Tiny event blocks (Kafka `blocksize=1`) → flood of CAS appends | `blocksize=1000` on the Kafka connector (opaquestring/csv) + `commitblocks=10` on the CAS adapter | VERIFIED |
| 2 | CAS subscriber fails at start or on first block; type mismatch | Pre-existing CAS table with different types (for example `id DOUBLE` vs ESP `int64`) | Drop the table, or re-create it with `PROC FEDSQL` (`id BIGINT`, …) and promote | VERIFIED |
| 3 | Kafka connector fails with authorization errors on managed Kafka | Connector joins the `espmeta` group / meta topic, and ACLs deny it | `disableespmetaconsumer=true` | VERIFIED |
| 4 | Project runs but receives no historical data | Group already has committed offsets. `earliest`/`smallest` is ignored | Stop the project → reset offsets to the low watermark, or use a new `kafkaconsumergroupid` | VERIFIED |
| 5 | Project runs but receives nothing at all | Producer is idle (scheduled simulators), or retention deleted the history | Check the topic's high/low watermarks (reset script prints them) before you debug ESP | VERIFIED |
| 6 | Source window rejects the schema with `kafkatype=opaquestring` | Source window doesn't have exactly `int64 key` + `string` | Make the schema exactly 2 fields: `index:int64, message:string` | DOC |
| 7 | `415 Unsupported Media Type` when you create a project | Raw XML POSTed | JSON wrapper + `application/vnd.sas.esp.espproject+json` | VERIFIED |
| 8 | `400 [8109] The project name is empty.` | Wrapper is missing the name | Include `friendlyName` (and `name`) | VERIFIED |
| 9 | Downloaded "logs" show no errors although the project failed | Those are K8s **operator** logs | Get the **ESP server pod** log of the running project | VERIFIED |
| 10 | `execute_sas_code` fails with syntax errors when large XML is embedded | Escaping of 10 KB+ inline strings | Upload through the Files service, then `proc http` GET → POST (see `esp_studio_rest_api.md` §6) | VERIFIED |
| 11 | MCP tools return "All connection attempts failed" | Viya environment is down or paused (not an ESP issue) | `curl -I https://<host>/`, then retry once the host is reachable | VERIFIED |
| 12 | Python window emits empty rows | Exception swallowed in `try/except` | Log temporarily (`print` goes to the server log), and check the field names against the real payload | HEURISTIC |

## Diagnostic order
1. Is the host/Viya reachable? → 2. Is the producer active (watermarks moving)? → 3. Does the project start (server pod log)? → 4. Kafka auth / meta consumer? → 5. Offsets? → 6. Python window output (enable the CSV/JSON fs subscriber windows temporarily) → 7. CAS adapter (schema, commitblocks).

Tip: keep inactive debugging subscribers in the project (`window-copy active="false"` with an `fs` connector writing `@ESP_PROJECT_OUTPUT@/read.csv`) and switch them on when you need to inspect intermediate data.
