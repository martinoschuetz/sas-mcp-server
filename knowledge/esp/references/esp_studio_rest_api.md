# ESP Studio REST API (v4) & MCP ESP Tools

Base path: `/SASEventStreamProcessingStudio/v4`. OpenAPI spec: `SASEventStreamProcessingStudio-v4-openapi.yml` in the Viya REST API docs.

## 1. Create a project [VERIFIED]
```
POST /SASEventStreamProcessingStudio/v4/projects
Content-Type: application/vnd.sas.esp.espproject+json
Authorization: Bearer <token>

{"friendlyName": "CandF_UNS_BMC2", "xml": "<project name=\"CandF_UNS_BMC2\" ...>...</project>"}
```
- The minimal working body is `friendlyName` + `xml`. The MCP tool also sends `name` and `projectName`, and the server tolerates that.
- The response echoes the project (`friendlyName`, `xml`, `virtualEnvironments: {}`, `type: "ESP Project"`, ids).
- Keep `<project name>` in the XML the same as `friendlyName`.

| Error | Cause |
|---|---|
| `415 Unsupported Media Type` | Raw XML or `application/xml` / `application/json` content type |
| `400 [8109] The project name is empty.` | Wrapper is missing the name field |

## 2. Update a project
POST creates a project. To update, **delete and then re-create** (the MCP tool does this). [VERIFIED workflow]

## 3. Read / delete
- `GET /projects/{name}` returns the JSON wrapper, with the XML in `.xml`. [VERIFIED 2026-10-12: `esp_get_project_xml("CandF_UNS_BMC2")` returned the deployed XML.]
- `DELETE /projects/{name}` returns `204` or `404`. [UNVERIFIED by name. It was never tested against a running project, so if you get a 404, list `GET /projects` and retry with the UUID.]

## 4. Running projects
Studio stores the projects. To run one, open it in ESP Studio and use **Run in test mode**, or deploy through ESP Studio/Manager to an ESP server. Runtime control endpoints live in the ESP server REST API (`eventStreamProcessing` v3) and in `SASEventStreamManager-v4`. These were **not exercised** in this project.

## 5. MCP tools (`src/sas_mcp_server/tools/esp.py`)
| Tool | Behavior |
|---|---|
| `esp_deploy_project(project_name, xml_content)` | DELETE (ignores 404) → POST with wrapper and vendor media type |
| `esp_get_project_xml(project_name)` | GET → returns only the `xml` string (saves context) |
| `esp_delete_project(project_name)` | DELETE |

## 6. Fallback without the MCP tools [VERIFIED]
When large XML (>10 KB) is passed inline to `execute_sas_code`, shell or JSON escaping often breaks it. A reliable workaround:
1. Upload the JSON wrapper with `upload_file` (needs both `file_path` and `file_name`). This returns a Files service id.
2. In SAS:
```sas
filename pld temp;
proc http method="GET" url="https://<host>/files/files/<id>/content" oauth_bearer=sas_services out=pld; run;
filename resp temp;
proc http method="POST" url="https://<host>/SASEventStreamProcessingStudio/v4/projects"
     oauth_bearer=sas_services in=pld out=resp ct="application/vnd.sas.esp.espproject+json"; run;
```

## 7. Git import
ESP Studio can import projects from Git only if a Git repository is configured in the environment. If it isn't, deploy through the REST API as shown above.
