# SAS MCP Server Development Context

Welcome to the SAS MCP Server project! 
When developing in this project, adhere to the following standards and guidelines:

## Core Architectural Guidelines
- **Tool Development**: All tools are grouped into tiers. When creating new tools, add them to the appropriate tier module in src/sas_mcp_server/tools/ and classify them correctly in src/sas_mcp_server/tools/_access.py as READ_ONLY_TOOLS or WRITE_TOOLS.
- **Testing**: Ensure that tool counts are updated in 	ests/test_read_only.py and 	ests/test_tier_selection.py when adding new tools.

## Knowledge Base (Extremely Important)
This project uses a rich, modular knowledge base located in the knowledge/ directory. **You must consult these rules before writing code or orchestrating workflows.**

- **SAS Coding Standards & Performance**: See knowledge/standards/sas.md for our canonical guide on DATA step optimizations, PROC FedSQL usage in CAS, and macro best practices.
- **Python Development**: See knowledge/standards/python.md for our async, structured concurrency, and performance patterns.
- **Domain-Specific Playbooks**: If you are working on specific integrations, consult their respective folders:
  - **FQA** (Field Quality Analytics): knowledge/fqa/
  - **CAF** (Custom Analysis Framework): knowledge/caf/ (especially mcp_execution_rules.md)
  - **Forecasting**: knowledge/forecasting/
  - **ESP**: knowledge/esp/

*Note for Claude/Cursor:* If you are running as an MCP client and this server is attached, you can dynamically read these files using the list_knowledge_domains and ead_knowledge_topic tools! Otherwise, read the files directly from the knowledge/ directory in the workspace.
