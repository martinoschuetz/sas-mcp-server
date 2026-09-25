---
trigger: always_on
---

# SAS MCP Server Development Context

Welcome to the SAS MCP Server project! 
When developing in this project, adhere to the following standards and guidelines:

- **SAS Coding Standards & Performance**: See `knowledge/standards/sas.md` for our canonical guide on DATA step optimizations, PROC FedSQL usage in CAS, and macro best practices.
- **Python Development**: See `knowledge/standards/python.md` for our async, structured concurrency, and performance patterns. 
- **Tool Development**: All tools are grouped into tiers (0-10). When creating new tools, add them to the appropriate tier module in `src/sas_mcp_server/tools/` and classify them correctly in `_access.py` as `READ_ONLY_TOOLS` or `WRITE_TOOLS`.
- **Testing**: Ensure that tool counts are updated in `tests/test_read_only.py` and `tests/test_tier_selection.py` when adding new tools.

These context rules apply globally to this repository and are loaded automatically by Antigravity (no `-c` flag needed).
