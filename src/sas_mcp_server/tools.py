# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Shared tool registration for both HTTP and stdio MCP servers.
All tools are registered via ``register_tools(mcp, get_token)``.
"""

import json
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx
from fastmcp import Context, FastMCP

from sas_mcp_server.helpers import auto_ml_helpers, report_export_helpers

from .config import CONTEXT_NAME, SSL_VERIFY, VIYA_ENDPOINT
from .env import env_bool
from .viya_client import (
    delete_resource,
    get_json,
    get_paged_items,
    logger,
    make_client,
    post_json,
    return_items,
)
from .viya_utils import (
    copy_data_selection,
    copy_data_selections,
    copy_iot_analyses,
    create_and_run_analysis,
    create_folder,
    create_iot_analysis,
    create_project,
    delete_data_selection,
    delete_folder,
    delete_iot_analysis,
    delete_project,
    get_cached_session,
    get_cas_summary_statistics,
    get_data_selection,
    get_iot_analysis,
    get_iot_analysis_job,
    get_iot_model,
    launch_data_selection,
    launch_data_selection_and_wait,
    list_data_selections,
    list_folders_and_projects,
    list_iot_analyses,
    list_iot_models,
    list_iot_projects,
    reset_cached_session,
    run_iot_analysis,
    run_iot_analysis_and_wait,
    run_one_snippet,
    set_data_selection_date_range,
    update_data_selection,
)


# --- upload_data / upload_inline_data: source-format registry -----------------
# One registry of DataFormat objects is the single place file formats are
# described: each maps a logical format to the casManagement ``uploadTable``
# ``format`` value plus the per-format flags. Adding a format (or enabling one,
# e.g. parquet once an endpoint accepts it) is a one-line change here — the
# lookup tables below are derived from it, so nothing is kept in sync by hand.
# Per the uploadTable API the accepted ``format`` values are csv, xls, xlsx,
# sas7bdat and sashdat; ``tsv`` is csv with a tab delimiter and ``xlsm`` uploads
# as ``xlsx``.
@dataclass(frozen=True)
class DataFormat:
    key: str  # logical name used in data_format / detection (e.g. "tsv")
    cas_format: str  # value sent in the multipart ``format`` field (e.g. "csv")
    extensions: tuple[str, ...] = ()  # file extensions that map here (with the dot)
    aliases: tuple[str, ...] = ()  # accepted ``data_format`` synonyms
    delimiter: str | None = None  # delimiter override (e.g. a tab for tsv)
    header_row: bool = False  # accepts the containsHeaderRow flag
    excel_format: bool = False  # accepts a sheetName
    binary: bool = False  # non-text; must come from file_path/url, not inline
    supported: bool = True  # accepted by the uploadTable endpoint
    unsupported_reason: str | None = None  # guidance shown when supported is False


_DATA_FORMATS: tuple[DataFormat, ...] = (
    DataFormat("csv", "csv", extensions=(".csv",), header_row=True),
    DataFormat(
        "tsv",
        "csv",
        extensions=(".tsv", ".tab"),
        aliases=("tab",),
        delimiter="\t",
        header_row=True,
    ),
    DataFormat("xls", "xls", extensions=(".xls",), header_row=True, excel_format=True, binary=True),
    DataFormat(
        "xlsx", "xlsx", extensions=(".xlsx",), aliases=("excel",), header_row=True, excel_format=True, binary=True
    ),
    DataFormat("xlsm", "xlsx", extensions=(".xlsm",), header_row=True, excel_format=True, binary=True),
    DataFormat("sas7bdat", "sas7bdat", extensions=(".sas7bdat",), aliases=("sas",), binary=True),
    DataFormat("sashdat", "sashdat", extensions=(".sashdat",), binary=True),
    # Recognized but not accepted by the upload endpoint: detected so we can fail
    # fast with guidance rather than a guaranteed HTTP 400. Flip ``supported`` to
    # True if/when a deployment's endpoint accepts parquet.
    DataFormat(
        "parquet",
        "parquet",
        extensions=(".parquet", ".parq"),
        binary=True,
        supported=False,
        unsupported_reason=(
            "The casManagement file-upload endpoint does not accept parquet "
            "(it supports csv, tsv, xls, xlsx, sas7bdat, sashdat). Load parquet via a "
            "path-based caslib and promote_table_to_memory, or convert it to "
            "csv/sas7bdat first."
        ),
    ),
)


def _index_formats_by_name() -> dict[str, DataFormat]:
    """Map every format key and alias to its DataFormat (built once at import)."""
    out: dict[str, DataFormat] = {}
    for fmt in _DATA_FORMATS:
        out[fmt.key] = fmt
        for alias in fmt.aliases:
            out[alias] = fmt
    return out


_FORMAT_BY_NAME = _index_formats_by_name()
_FORMAT_BY_EXT = {ext: fmt for fmt in _DATA_FORMATS for ext in fmt.extensions}
_SUPPORTED_FORMATS = tuple(fmt.key for fmt in _DATA_FORMATS if fmt.supported)


def _resolve_data_format(
    data_format: str | None, file_path: str | None, url: str | None
) -> tuple[DataFormat | None, dict[str, Any] | None]:
    """Resolve the source to a *supported* ``DataFormat``, or a structured error.

    An explicit ``data_format`` (key or alias) wins; otherwise the format is
    inferred from the ``file_path``/``url`` extension. Returns ``(format, None)``
    on success, or ``(None, error)`` for an unknown extension, an unrecognized
    ``data_format``, or a recognized-but-unsupported format (e.g. parquet).
    """
    if data_format:
        name = data_format.strip().lower().lstrip(".")
        fmt = _FORMAT_BY_NAME.get(name)
        if fmt is None:
            return None, {
                "status": "unsupported_format",
                "data_format": name,
                "message": (f"Unsupported data_format '{name}'. Supported: {', '.join(_SUPPORTED_FORMATS)}."),
            }
    else:
        fmt = None
        ref = file_path or url
        if ref:
            # Drop any URL query/fragment before reading the suffix.
            clean = ref.split("?", 1)[0].split("#", 1)[0]
            fmt = _FORMAT_BY_EXT.get(Path(clean).suffix.lower())
        if fmt is None:
            return None, {
                "status": "unknown_format",
                "message": (
                    "Could not infer the data format from the file/URL extension. "
                    "Pass data_format (csv, tsv, xls, xlsx, sas7bdat, sashdat)."
                ),
            }
    if not fmt.supported:
        return None, {
            "status": "format_not_supported",
            "data_format": fmt.key,
            "message": fmt.unsupported_reason or f"Format '{fmt.key}' is not accepted by the upload endpoint.",
        }
    return fmt, None


async def _resolve_source_bytes(file_path: str | None, url: str | None) -> tuple[bytes | None, dict[str, Any] | None]:
    """Materialize the upload bytes server-side from ``file_path`` or ``url``.

    Assumes exactly one of the two is set (the caller's exactly-one-source
    guard). The bytes are read off the server's disk or fetched over HTTP, never
    routed through the model context. Returns ``(bytes, None)`` or ``(None, error)``.
    """
    if file_path:
        if not env_bool("ALLOW_LOCAL_FILE_UPLOAD", True):
            return None, {
                "status": "file_upload_disabled",
                "message": (
                    "Server-side file reads are disabled "
                    "(ALLOW_LOCAL_FILE_UPLOAD=false). Use url or the upload_inline_data tool."
                ),
            }
        path = Path(file_path).expanduser()
        if not path.is_file():
            return None, {
                "status": "file_not_found",
                "file_path": file_path,
                "message": (
                    f"No readable file at '{file_path}' on the server host. In "
                    "stdio mode that host is your local machine; pass an absolute path."
                ),
            }
        try:
            return path.read_bytes(), None
        except OSError as exc:
            return None, {
                "status": "file_unreadable",
                "file_path": file_path,
                "message": str(exc),
            }
    # url — fetch with a plain client (no Viya bearer on an external URL).
    assert url is not None
    try:
        async with httpx.AsyncClient(timeout=120.0, follow_redirects=True, verify=SSL_VERIFY) as fetch_client:
            fetch_resp = await fetch_client.get(url)
            fetch_resp.raise_for_status()
            return fetch_resp.content, None
    except httpx.HTTPError as exc:
        return None, {"status": "fetch_failed", "url": url, "message": str(exc)}


async def _post_cas_upload(
    client: httpx.AsyncClient,
    server_id: str,
    caslib_name: str,
    table_name: str,
    fmt: DataFormat,
    file_bytes: bytes,
    source: str,
    *,
    sheet_name: str | None = None,
    contains_header_row: bool = True,
) -> dict[str, Any]:
    """POST resolved bytes to the casManagement uploadTable endpoint, shape the result.

    Shared by ``upload_data`` (file_path/url) and ``upload_inline_data`` (inline
    text). *fmt* is a resolved, supported :class:`DataFormat`; *source* is echoed
    back in the result so callers can tell how the bytes arrived.
    """
    fields: dict[str, str] = {"tableName": table_name, "format": fmt.cas_format}
    if fmt.delimiter is not None:
        fields["delimiter"] = fmt.delimiter
    if fmt.header_row:
        fields["containsHeaderRow"] = "true" if contains_header_row else "false"
    if sheet_name and fmt.excel_format:
        fields["sheetName"] = sheet_name
    content_type = "application/octet-stream" if fmt.binary else "text/csv"
    # The uploadTable API requires the ``file`` part to come *last*; httpx
    # serializes ``data`` fields before ``files``, so this satisfies that.
    resp = await client.post(
        f"{VIYA_ENDPOINT}/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables",
        data=fields,
        files={"file": (f"data.{fmt.key}", file_bytes, content_type)},
    )
    if resp.status_code == 409:
        return {
            "status": "table_already_exists",
            "table_name": table_name,
            "caslib": caslib_name,
            "message": (
                f"Table '{table_name}' already exists in caslib '{caslib_name}'. Drop or rename before re-uploading."
            ),
        }
    if resp.status_code >= 400:
        # Surface why CAS refused (bad caslib, malformed file, scope/perm) as a
        # structured error instead of raising an opaque one.
        return {
            "status": "upload_failed",
            "http_status": resp.status_code,
            "data_format": fmt.key,
            "message": (f"CAS rejected the {fmt.key} upload (HTTP {resp.status_code}). Viya said: {resp.text[:400]}"),
        }
    body = resp.json()
    return {
        "status": "success",
        "source": source,
        "data_format": fmt.key,
        "table_name": body.get("name"),
        "rows_uploaded": body.get("rowCount", 0),
        "column_count": body.get("columnCount", 0),
        "caslib": body.get("caslibName"),
        "scope": body.get("scope"),
    }


# --- export_report: Visual Analytics export-format registry -------------------
def register_tools(mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]) -> None:
    """Register all tools on *mcp*.

    Parameters
    ----------
    mcp : FastMCP
        The server instance to register tools on.
    get_token : callable
        ``async def get_token(ctx: Context) -> str`` — returns a Viya access
        token.  HTTP mode pulls it from context state; stdio mode reads a
        token cached by ``sas-viya auth loginCode`` or runs an RFC 8628
        device-code flow.
    """

    @asynccontextmanager
    async def viya_session(name: str, ctx: Context) -> AsyncIterator[httpx.AsyncClient]:
        """Log tool usage, resolve a Viya token, and yield an authed client.

        Collapses the per-tool preamble (log line + token fetch + client
        construction) into one context manager shared by every tool.
        """
        logger.info("--- TOOL USED: %s ---", name)
        token = await get_token(ctx)
        async with make_client(token) as client:
            yield client

    @asynccontextmanager
    async def compute_tool_session(
        name: str, ctx: Context, context_name: str
    ) -> AsyncIterator[tuple[httpx.AsyncClient, str]]:
        """Like :func:`viya_session` but also resolves the cached compute session.

        Yields ``(client, session_id)`` where *session_id* is the reusable
        per-user compute session for *context_name* — created on first use and
        reused (not torn down) on later calls. Use ``reset_compute_session`` to
        discard it.
        """
        logger.info("--- TOOL USED: %s ---", name)
        token = await get_token(ctx)
        async with make_client(token) as client:
            session_id = await get_cached_session(client, context_name, token)
            yield client, session_id

    # ------------------------------------------------------------------
    # Original tool
    # ------------------------------------------------------------------

    @mcp.tool()
    async def execute_sas_code(sas_code: str, ctx: Context) -> dict[str, str]:
        """
        Executes the provided SAS code in the Viya environment and returns information about the completed Job.
        This will create a job definition for the SAS code, execute it, and then retrieve the results.

        The code runs in a reusable compute session that is kept warm and shared
        across calls (per user), so SAS state — WORK tables, macro variables, and
        assigned librefs — persists between successive ``execute_sas_code`` calls.
        Call ``reset_compute_session`` to discard that state and start fresh.

        Args:
            sas_code (str): the SAS code snippet to be executed using the Viya Job Execution API Service

        Returns:
            A dictionary with four string fields describing the executed job:
            ``snippet_id`` (the job's snippet identifier), ``state`` (the final
            job state, e.g. ``completed``/``error``/``warning``), ``log`` (the
            full SAS log — execution details, notes, and any errors/warnings),
            and ``listing`` (the SAS listing output, i.e. the intended results
            when the code ran successfully).
        """
        logger.info("--- TOOL USED: execute_sas_code ---")
        token = await get_token(ctx)
        return await run_one_snippet(sas_code, "1", token)

    # ------------------------------------------------------------------
    # Tier 1 — Data Discovery (CAS Management)
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_cas_servers(ctx: Context) -> list[dict[str, Any]]:
        """List available CAS servers on the Viya environment."""
        async with viya_session("list_cas_servers", ctx) as client:
            items, _ = await get_paged_items("/casManagement/servers", client)
            return return_items(items, ["name", "id", "description"])

    @mcp.tool()
    async def list_caslibs(server_id: str, ctx: Context, limit: int = 50) -> list[dict[str, Any]]:
        """List CAS libraries (caslibs) available on a CAS server.

        Args:
            server_id: CAS server name or ID (e.g. 'cas-shared-default').
            limit: Maximum number of caslibs to return (default 50).
        """
        async with viya_session("list_caslibs", ctx) as client:
            items, _ = await get_paged_items(f"/casManagement/servers/{server_id}/caslibs", client, limit=limit)
            return return_items(items, ["name", "type", "description"])

    @mcp.tool()
    async def list_castables(server_id: str, caslib_name: str, ctx: Context, limit: int = 50) -> list[dict[str, Any]]:
        """List tables in a CAS library.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            limit: Maximum number of tables to return (default 50).
        """
        async with viya_session("list_castables", ctx) as client:
            items, _ = await get_paged_items(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables",
                client,
                limit=limit,
            )
            return return_items(items, ["name", "rowCount", "columnCount"])

    @mcp.tool()
    async def list_source_tables(
        server_id: str, caslib_name: str, ctx: Context, limit: int = 50
    ) -> list[dict[str, Any]]:
        """List source tables that are NOT yet loaded into memory in a CAS library.

        These are the candidates for ``promote_table_to_memory`` — tables that
        exist on the caslib's data source but are not in CAS memory yet.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            limit: Maximum number of tables to return (default 50).
        """
        async with viya_session("list_source_tables", ctx) as client:
            items, _ = await get_paged_items(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables",
                client,
                limit=limit,
                extra_params={"state": "unloaded"},
            )
            return return_items(items, ["name", "sourceTableName", "scope", "state"])

    @mcp.tool()
    async def get_castable_info(server_id: str, caslib_name: str, table_name: str, ctx: Context) -> dict[str, Any]:
        """Get metadata for a CAS table (row count, column count, size, etc.).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
        """
        async with viya_session("get_castable_info", ctx) as client:
            return await get_json(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}",
                client,
            )

    @mcp.tool()
    async def get_castable_columns(
        server_id: str,
        caslib_name: str,
        table_name: str,
        ctx: Context,
        limit: int = 200,
    ) -> list[dict[str, Any]]:
        """Get column metadata for a CAS table (names, types, labels, formats).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
            limit: Maximum columns to return (default 200).
        """
        async with viya_session("get_castable_columns", ctx) as client:
            items, _ = await get_paged_items(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}/columns",
                client,
                limit=limit,
            )
            return return_items(items, ["name", "type", "rawLength", "label", "format"])

    @mcp.tool()
    async def get_castable_data(
        server_id: str,
        caslib_name: str,
        table_name: str,
        ctx: Context,
        limit: int = 100,
        start: int = 0,
    ) -> dict[str, Any]:
        """Fetch rows from a CAS table with column names.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
            limit: Maximum rows to return (default 100).
            start: Row offset (default 0).
        """
        data_source_id = f"cas~fs~{server_id}~fs~{caslib_name}"
        table_id = f"cas~fs~{server_id}~fs~{caslib_name}~fs~{table_name}"
        async with viya_session("get_castable_data", ctx) as client:
            columns: list[dict[str, Any]] = []
            col_start = 0
            col_limit = 100
            while True:
                col_resp = await client.get(
                    f"{VIYA_ENDPOINT}/dataTables/dataSources/{data_source_id}/tables/{table_name}/columns",
                    params={"start": col_start, "limit": col_limit},
                    follow_redirects=True,
                )
                col_resp.raise_for_status()
                col_data = col_resp.json()
                for item in col_data.get("items", []):
                    columns.append(
                        {
                            "name": item.get("name"),
                            "type": item.get("type"),
                            "index": item.get("index"),
                        }
                    )
                total = col_data.get("count", 0)
                col_start += col_limit
                if col_start >= total:
                    break

            row_resp = await client.get(
                f"{VIYA_ENDPOINT}/rowSets/tables/{table_id}/rows",
                params={"start": start, "limit": limit},
                follow_redirects=True,
            )
            row_resp.raise_for_status()
            row_data = row_resp.json()

            col_names = [c["name"] for c in columns]
            rows = []
            for item in row_data.get("items", []):
                cells = item.get("cells", [])
                rows.append(dict(zip(col_names, cells, strict=False)))

            return {
                "columns": col_names,
                "rows": rows,
                "count": row_data.get("count", len(rows)),
                "start": start,
                "limit": limit,
            }

    @mcp.tool()
    async def get_castable_summary_statistics_tool(server_id: str, caslib_name: str,
                                              table_name: str, ctx: Context) -> dict:
        """Retrieves summary statistics for a CAS table (min, max, mean, count, etc.).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
        """
        logger.info(f"--- TOOL USED: get_castable_summary_statistics ({table_name}) ---")
        token = await get_token(ctx)
        return await get_cas_summary_statistics(server_id, caslib_name, table_name, token)

    # ------------------------------------------------------------------
    # Tier 2 — Data Operations & Files
    # ------------------------------------------------------------------

    @mcp.tool()
    async def upload_data(
        server_id: str,
        caslib_name: str,
        table_name: str,
        ctx: Context,
        file_path: str | None = None,
        url: str | None = None,
        data_format: str | None = None,
        sheet_name: str | None = None,
        contains_header_row: bool = True,
    ) -> dict[str, Any]:
        """Upload a data file into a CAS table — read **by the server**, not the model.

        Provide the data by reference through **exactly one** of:

        * ``file_path`` — the server reads the file off its own disk (in stdio mode
          that's your machine). Disable with ``ALLOW_LOCAL_FILE_UPLOAD=false``.
        * ``url`` — the server fetches it over HTTP.

        Either way the bytes are read server-side and never pass through the calling
        model's context window. To create a *small* table you are building inline (no
        file or URL), use the ``upload_inline_data`` tool instead.

        The casManagement uploadTable endpoint only accepts an uploaded file (multipart
        form-data) and has no URL parameter, so ``url`` is fetched and sent on as the
        multipart file part.

        **Formats.** Per the uploadTable API: csv, xls, xlsx (single sheet), sas7bdat,
        sashdat; ``tsv`` is csv with a tab delimiter. parquet is **not** accepted and is
        rejected up front with guidance (load via a path-based caslib +
        promote_table_to_memory, or convert to csv/sas7bdat). The format is auto-detected
        from the ``file_path``/``url`` extension; pass ``data_format`` to override (needed
        for URLs with no clean suffix).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Target caslib name.
            table_name: Name for the new table.
            file_path: Path to a data file the server reads directly from disk.
            url: HTTP(S) URL the server fetches the file from.
            data_format: Override format detection. One of csv, tsv, xls, xlsx,
                sas7bdat, sashdat (aliases: excel→xlsx, tab→tsv, sas→sas7bdat).
            sheet_name: For Excel sources, the worksheet to import (first sheet by default).
            contains_header_row: Whether the first row holds column names — applies
                to csv/tsv/Excel (default True).
        """
        provided = [n for n, v in (("file_path", file_path), ("url", url)) if v]
        if len(provided) != 1:
            return {
                "status": "invalid_source",
                "provided": provided,
                "message": (
                    "Provide exactly one of file_path or url. To upload inline text use the upload_inline_data tool."
                ),
            }
        source = provided[0]

        # Resolve the format first (fails cheaply before any disk/URL/Viya I/O),
        # then materialize the bytes server-side; each helper returns a structured
        # error or its result.
        fmt, fmt_error = _resolve_data_format(data_format, file_path, url)
        if fmt_error is not None:
            return fmt_error
        assert fmt is not None  # paired with fmt_error by _resolve_data_format

        file_bytes, source_error = await _resolve_source_bytes(file_path, url)
        if source_error is not None:
            return source_error
        assert file_bytes is not None  # paired with source_error

        async with viya_session("upload_data", ctx) as client:
            return await _post_cas_upload(
                client,
                server_id,
                caslib_name,
                table_name,
                fmt,
                file_bytes,
                source,
                sheet_name=sheet_name,
                contains_header_row=contains_header_row,
            )

    @mcp.tool()
    async def upload_inline_data(
        server_id: str,
        caslib_name: str,
        table_name: str,
        data: str,
        ctx: Context,
        data_format: str = "csv",
        contains_header_row: bool = True,
    ) -> dict[str, Any]:
        """Create a small CAS table from inline delimited text passed as a string.

        Use this only for **tiny, hand-built tables** — a lookup/mapping table the model
        constructs on the fly, or a quick test table — because the whole payload travels
        through the model's context as a tool argument. For anything larger, or any file
        you already have, use ``upload_data`` (file_path/url), which reads the bytes
        server-side instead.

        Text formats only: ``csv`` (default) or ``tsv`` (tab-separated). For binary
        formats (Excel, sas7bdat, sashdat) use ``upload_data``.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Target caslib name.
            table_name: Name for the new table.
            data: The delimited text, including the header row.
            data_format: 'csv' (default) or 'tsv' (alias 'tab').
            contains_header_row: Whether the first row holds column names (default True).
        """
        fmt = _FORMAT_BY_NAME.get(data_format.strip().lower())
        # Inline text can only carry the text formats (csv/tsv) — never a binary
        # or endpoint-unsupported format.
        if fmt is None or fmt.binary or not fmt.supported:
            return {
                "status": "text_only",
                "data_format": data_format,
                "message": (
                    "upload_inline_data accepts only csv or tsv text. For binary formats "
                    "(xls, xlsx, sas7bdat, sashdat) use upload_data with file_path or url."
                ),
            }
        async with viya_session("upload_inline_data", ctx) as client:
            return await _post_cas_upload(
                client,
                server_id,
                caslib_name,
                table_name,
                fmt,
                data.encode("utf-8"),
                "inline",
                contains_header_row=contains_header_row,
            )

    @mcp.tool()
    async def promote_table_to_memory(
        server_id: str, caslib_name: str, table_name: str, ctx: Context
    ) -> dict[str, Any]:
        """Load a source table into CAS memory at global scope (visible to all sessions).

        Loads the table from its caslib data source and promotes it to global
        scope via the casManagement ``updateTableState`` API. Idempotent: if the
        table is already loaded in global scope it is left untouched. Use
        ``list_source_tables`` to discover unloaded tables that can be promoted.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Caslib containing the table.
            table_name: Table to load and promote.
        """
        table_path = f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}"
        async with viya_session("promote_table_to_memory", ctx) as client:
            # Idempotency: skip if the table is already loaded in global scope.
            try:
                info = await get_json(table_path, client)
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    return {
                        "status": "not_found",
                        "table": f"{caslib_name}.{table_name}",
                        "message": (
                            f"No table '{table_name}' in caslib '{caslib_name}'. "
                            "Use list_source_tables to find loadable source tables."
                        ),
                    }
                raise
            if info.get("state") == "loaded" and info.get("scope") == "global":
                return {
                    "status": "already_global",
                    "table": f"{caslib_name}.{table_name}",
                    "state": "loaded",
                    "scope": "global",
                }

            # Load from source and promote to global scope. The updateTableState
            # endpoint responds with text/plain (the new state), not JSON.
            resp = await client.put(
                f"{VIYA_ENDPOINT}{table_path}/state",
                params={"value": "loaded", "scope": "global"},
                headers={"Accept": "*/*"},
            )
            resp.raise_for_status()
            return {
                "status": "promoted",
                "table": f"{caslib_name}.{table_name}",
                "state": resp.text.strip() or "loaded",
                "scope": "global",
            }

    @mcp.tool()
    async def list_files(ctx: Context, limit: int = 50, filter_name: str | None = None) -> list[dict[str, Any]]:
        """List files in the Viya Files Service.

        Args:
            limit: Maximum files to return (default 50).
            filter_name: Optional name filter (substring match).
        """
        filters = f"contains(name,'{filter_name}')" if filter_name else None
        async with viya_session("list_files", ctx) as client:
            items, _ = await get_paged_items("/files/files", client, limit=limit, filters=filters)
            return return_items(items, ["id", "name", "contentType", "size"])

    @mcp.tool()
    async def upload_file(
        file_name: str, content: str, ctx: Context, content_type: str = "text/plain"
    ) -> dict[str, Any]:
        """Upload a file to the Viya Files Service.

        Args:
            file_name: Name for the file.
            content: File content as a string.
            content_type: MIME type (default 'text/plain').
        """
        async with viya_session("upload_file", ctx) as client:
            resp = await client.post(
                f"{VIYA_ENDPOINT}/files/files",
                content=content.encode("utf-8"),
                headers={
                    "Content-Type": content_type,
                    "Content-Disposition": f'attachment; filename="{file_name}"',
                    "Accept": "application/json",
                },
            )
            resp.raise_for_status()
            return resp.json()

    @mcp.tool()
    async def download_file(file_id: str, ctx: Context) -> str:
        """Download file content from the Viya Files Service.

        Args:
            file_id: ID of the file to download.
        """
        async with viya_session("download_file", ctx) as client:
            resp = await client.get(f"{VIYA_ENDPOINT}/files/files/{file_id}/content")
            resp.raise_for_status()
            return resp.text

    # ------------------------------------------------------------------
    # Tier 3 — Reports & Visualization
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_reports(ctx: Context, limit: int = 50, filter_name: str | None = None) -> list[dict[str, Any]]:
        """List Visual Analytics reports.

        Args:
            limit: Maximum reports to return (default 50).
            filter_name: Optional name filter (substring match).
        """
        filters = f"contains(name,'{filter_name}')" if filter_name else None
        async with viya_session("list_reports", ctx) as client:
            items, _ = await get_paged_items("/reports/reports", client, limit=limit, filters=filters)
            return return_items(items, ["id", "name", "description", "createdBy"])

    @mcp.tool()
    async def get_report(report_id: str, ctx: Context) -> dict[str, Any]:
        """Get a Visual Analytics report's metadata and definition.

        Args:
            report_id: ID of the report.
        """
        async with viya_session("get_report", ctx) as client:
            return await get_json(f"/reports/reports/{report_id}", client)

    @mcp.tool()
    async def export_report(
        report_id: str,
        export_format: str,
        ctx: Context,
        report_objects: list[str] | None = None,
        image_size: str | None = None,
        options: dict[str, Any] | None = None,
    ):
        """Export a Visual Analytics report (or specific report objects) in any
        format the VA service exposes, via its synchronous export endpoints.

        Formats (``export_format``):
          * ``package`` — full report bundle as a ``.zip`` (source files, query
            results, and rendered content); whole report or selected objects.
          * ``pdf`` — rendered PDF; whole report or selected objects. Pass
            rendering overrides (e.g. ``orientation``, ``paperSize``, ``margin``,
            ``includeCoverPage``) via ``options``.
          * ``png`` / ``svg`` — image of the report or a single object;
            ``image_size`` is required, e.g. ``"1200px,800px"``.
          * ``csv`` / ``tsv`` / ``xlsx`` — the data behind a single report
            object; exactly one object label is required.
          * ``summary`` — the report's text summary.

        Args:
            report_id: ID of the report.
            export_format: One of package, pdf, png, svg, csv, tsv, xlsx, summary.
            report_objects: Report object labels to export. ``package``/``pdf``
                accept several; image and data formats accept exactly one;
                ``summary`` accepts none. Omit to export the whole report where
                the format allows it.
            image_size: Required for ``png``/``svg``; format ``"<w>px,<h>px"``.
            options: Optional ``pdf`` rendering overrides, passed through as query
                parameters (e.g. ``{"orientation": "landscape"}``).

        Returns text inline for text formats, image content for ``png``, and an
        embedded binary file (carrying the right MIME type) for ``package`` /
        ``pdf`` / ``xlsx``. Binary results larger than ``MAX_EXPORT_INLINE_BYTES``
        are refused with guidance rather than streamed through the model context.
        """
        req = report_export_helpers.ReportExportRequest(
            report_id=report_id,
            export_format=export_format,
            report_objects=report_objects,
            image_size=image_size,
            options=options,
        )
        error = report_export_helpers.validate_export_request(req)
        if error is not None:
            return error
        async with viya_session("export_report", ctx) as client:
            return await report_export_helpers.execute_export(req, client)

    # ------------------------------------------------------------------
    # Tier 4 — Batch Jobs & Async Execution
    # ------------------------------------------------------------------

    @mcp.tool()
    async def submit_batch_job(sas_code: str, ctx: Context, job_name: str | None = None) -> dict[str, Any]:
        """Submit a SAS job for asynchronous execution via the Job Execution service.

        Args:
            sas_code: SAS code to execute.
            job_name: Optional descriptive name for the job.
        """
        body = {
            "name": job_name or "mcp-batch-job",
            "jobDefinition": {
                "type": "Compute",
                "code": sas_code,
            },
            "arguments": {
                "_contextName": CONTEXT_NAME,
            },
        }
        async with viya_session("submit_batch_job", ctx) as client:
            return await post_json("/jobExecution/jobs", client, body=body)

    @mcp.tool()
    async def get_job_status(job_id: str, ctx: Context) -> dict[str, Any]:
        """Check the status of a submitted job.

        Args:
            job_id: ID of the job.
        """
        async with viya_session("get_job_status", ctx) as client:
            return await get_json(f"/jobExecution/jobs/{job_id}", client)

    @mcp.tool()
    async def list_jobs(ctx: Context, limit: int = 20) -> list[dict[str, Any]]:
        """List recent jobs from the Job Execution service.

        Args:
            limit: Maximum jobs to return (default 20).
        """
        async with viya_session("list_jobs", ctx) as client:
            items, _ = await get_paged_items("/jobExecution/jobs", client, limit=limit)
            return return_items(items, ["id", "name", "state", "creationTimeStamp"])

    @mcp.tool()
    async def cancel_job(job_id: str, ctx: Context) -> str:
        """Cancel a running job.

        Args:
            job_id: ID of the job to cancel.
        """
        async with viya_session("cancel_job", ctx) as client:
            await delete_resource(f"/jobExecution/jobs/{job_id}", client)
            return f"Job {job_id} cancelled."

    @mcp.tool()
    async def get_job_log(job_id: str, ctx: Context) -> str:
        """Retrieve the log of a completed job.

        Args:
            job_id: ID of the job.
        """
        async with viya_session("get_job_log", ctx) as client:
            data = await get_json(f"/jobExecution/jobs/{job_id}", client)
            results = data.get("results", {})

            log_uri = None
            for key, value in results.items():
                if key.endswith(".log.txt"):
                    log_uri = value
                    break
            if not log_uri:
                for key, value in results.items():
                    if key.endswith(".log"):
                        log_uri = value
                        break

            if not log_uri:
                state = data.get("state", "unknown")
                error = data.get("error", {})
                if error:
                    return f"Job {state}: {error.get('message', 'No error details')}"
                return f"No log available. Job state: {state}"

            resp = await client.get(f"{VIYA_ENDPOINT}{log_uri}/content")
            resp.raise_for_status()
            return resp.text

    # ------------------------------------------------------------------
    # Tier 5 — Model Management & Scoring
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_ml_projects(ctx: Context, limit: int = 50) -> list[dict[str, Any]]:
        """List AutoML pipeline automation projects.

        Args:
            limit: Maximum projects to return (default 50).
        """
        async with viya_session("list_ml_projects", ctx) as client:
            items, _ = await get_paged_items("/mlPipelineAutomation/projects", client, limit=limit)
            return return_items(items, ["id", "name", "state", "description"])

    @mcp.tool()
    async def create_ml_project(
        project_name: str,
        caslib_name: str,
        table_name: str,
        target_variable: str,
        ctx: Context,
        server_id: str = "cas-shared-default",
        description: str = "",
        prediction_type: str = "binary",
        target_event_level: str = "1",
        auto_run: bool = True,
    ) -> dict[str, Any]:
        """Create a new AutoML pipeline automation project from a CAS table.

        The training table must already be loaded into CAS memory at **global**
        scope. This tool verifies that first and returns an actionable error
        otherwise (use ``promote_table_to_memory`` to load + promote a source
        table, and ``list_source_tables`` to find one). The data-table URI is
        built from ``server_id``/``caslib_name``/``table_name``.

        Args:
            project_name: Name for the project.
            caslib_name: Caslib containing the training table.
            table_name: Name of the (loaded, global) training table.
            target_variable: Name of the target/response variable.
            server_id: CAS server name or ID (default 'cas-shared-default').
            description: Optional project description.
            prediction_type: 'binary', 'interval', or 'nominal' (default 'binary').
            target_event_level: Target event level for binary/nominal classification (default '1').
            auto_run: Whether to automatically run pipelines after creation (default True).
        """
        table_path = f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}"
        data_table_uri = f"/dataTables/dataSources/cas~fs~{server_id}~fs~{caslib_name}/tables/{table_name}"
        analytics_attrs: dict[str, Any] = {
            "targetVariable": target_variable,
            "targetLevel": prediction_type,
            "partitionEnabled": True,
            "classSelectionStatistic": ("ks" if prediction_type in ("binary", "nominal") else "ase"),
        }
        if prediction_type in ("binary", "nominal"):
            analytics_attrs["targetEventLevel"] = target_event_level
        body = {
            "name": project_name,
            "description": description,
            "type": "predictive",
            "dataTableUri": data_table_uri,
            "pipelineBuildMethod": "automatic",
            "settings": {
                "applyGlobalMetadata": True,
                "autoRun": auto_run,
                "numberOfModels": 5,
            },
            "analyticsProjectAttributes": analytics_attrs,
        }
        async with viya_session("create_ml_project", ctx) as client:
            # Pre-flight: the training table must be loaded in global scope, or
            # mlPipelineAutomation fails opaquely later.
            try:
                info = await get_json(table_path, client)
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    return {
                        "status": "table_not_found",
                        "table": f"{caslib_name}.{table_name}",
                        "message": (
                            f"Table '{table_name}' not found in caslib '{caslib_name}' on "
                            f"server '{server_id}'. Load and promote it with "
                            "promote_table_to_memory (see list_source_tables)."
                        ),
                    }
                raise
            if not (info.get("state") == "loaded" and info.get("scope") == "global"):
                return {
                    "status": "table_not_global",
                    "table": f"{caslib_name}.{table_name}",
                    "state": info.get("state"),
                    "scope": info.get("scope"),
                    "message": (
                        "The training table must be loaded in global scope before "
                        "creating an ML project. Use promote_table_to_memory to load "
                        "and promote it."
                    ),
                }
            return await post_json("/mlPipelineAutomation/projects", client, body=body)

    @mcp.tool()
    async def list_publishing_destinations(
        ctx: Context, limit: int = 50, start: int = 0, filter_name: str | None = None
    ) -> list[dict[str, Any]]:
        """List available publishing destinations.

        Args:
            ctx: FastMCP context.
            limit: Maximum destinations to return (default 50).
            start: Row offset (default 0).
            filter_name: Optional filter for destination names.
        """
        async with viya_session("list_publishing_destinations", ctx) as client:
            items, _ = await get_paged_items(
                "/modelPublish/destinations",
                client,
                limit=limit,
                start=start,
                filters=f"contains(name,'{filter_name}')" if filter_name else None,
            )
            return return_items(items, ["id", "name", "description", "destinationType"])

    @mcp.tool()
    async def register_ml_champion_model(project_id: str, ctx: Context) -> dict[str, Any]:
        """Register the champion model from an AutoML pipeline automation project to the Model Repository.

        Args:
            project_id: ID of the ML pipeline automation project.
        """
        async with viya_session("register_ml_champion_model", ctx) as client:
            props = auto_ml_helpers.MLRegisterProps(project_id=project_id)
            return await auto_ml_helpers.ml_register_publish(props, client)

    @mcp.tool()
    async def publish_ml_champion_model(project_id: str, destination_name: str, ctx: Context) -> dict[str, Any]:
        """Publish the champion model from an AutoML pipeline automation project to the Model Repository.

        Args:
            project_id: ID of the ML pipeline automation project.
            destination_name: Name of the destination to publish to.
        """
        async with viya_session("publish_ml_champion_model", ctx) as client:
            props = auto_ml_helpers.MLPublishProps(project_id=project_id, destination_name=destination_name)
            return await auto_ml_helpers.ml_register_publish(props, client)

    @mcp.tool()
    async def run_ml_project(project_id: str, ctx: Context) -> dict[str, Any]:
        """Run an AutoML pipeline automation project.

        Args:
            project_id: ID of the project to run.
        """
        mlpa_type = "application/vnd.sas.analytics.ml.pipeline.automation.project+json"
        async with viya_session("run_ml_project", ctx) as client:
            get_resp = await client.get(
                f"{VIYA_ENDPOINT}/mlPipelineAutomation/projects/{project_id}",
                headers={"Accept": mlpa_type},
            )
            get_resp.raise_for_status()
            project_body = get_resp.json()
            etag = get_resp.headers.get("etag", "")
            resp = await client.put(
                f"{VIYA_ENDPOINT}/mlPipelineAutomation/projects/{project_id}",
                params={"action": "retrainProject"},
                content=json.dumps(project_body).encode(),
                headers={
                    "Content-Type": mlpa_type,
                    "Accept": mlpa_type,
                    "If-Match": etag,
                    "Accept-Language": "en",
                },
            )
            resp.raise_for_status()
            if resp.status_code == 204 or not resp.content:
                return {"status": "running", "projectId": project_id}
            return resp.json()

    @mcp.tool()
    async def list_registered_models(ctx: Context, limit: int = 50) -> list[dict[str, Any]]:
        """List models in the Model Repository.

        Args:
            limit: Maximum models to return (default 50).
        """
        async with viya_session("list_registered_models", ctx) as client:
            items, _ = await get_paged_items("/modelRepository/models", client, limit=limit)
            return return_items(items, ["id", "name", "description", "modelVersionName"])

    @mcp.tool()
    async def list_models_and_decisions(ctx: Context, limit: int = 50) -> list[dict[str, Any]]:
        """List published scoring models and decisions (MAS modules).

        Args:
            limit: Maximum modules to return (default 50).
        """
        async with viya_session("list_models_and_decisions", ctx) as client:
            items, _ = await get_paged_items("/microanalyticScore/modules", client, limit=limit)
            return return_items(items, ["id", "name", "description"])

    @mcp.tool()
    async def score_data(module_id: str, step_id: str, input_data: dict, ctx: Context) -> dict[str, Any]:
        """Score data against a published model or decision (MAS module).

        Args:
            module_id: MAS module ID.
            step_id: Step ID within the module (usually 'score' or 'execute').
            input_data: Dictionary of input variable name-value pairs.
        """
        body = {"inputs": [{"name": k, "value": v} for k, v in input_data.items()]}
        async with viya_session("score_data", ctx) as client:
            return await post_json(
                f"/microanalyticScore/modules/{module_id}/steps/{step_id}",
                client,
                body=body,
            )

    # ------------------------------------------------------------------
    # Tier 6 — Compute Contexts & Code Execution
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_compute_contexts(
        ctx: Context, limit: int = 50, start: int = 0, filter_name: str | None = None
    ) -> list[dict[str, Any]]:
        """List available compute contexts on the Viya environment."""
        async with viya_session("list_compute_contexts", ctx) as client:
            filters = f"contains(name,'{filter_name}')" if filter_name else None
            items, _ = await get_paged_items("/compute/contexts", client, limit=limit, start=start, filters=filters)
            return return_items(items, ["name", "description"])

    @mcp.tool()
    async def list_compute_libraries(
        compute_context_name: str,
        ctx: Context,
        limit: int = 50,
        start: int = 0,
        filter_name: str | None = None,
    ) -> list[dict[str, Any]]:
        """List the SAS libraries (librefs) assigned in a compute context.

        Runs in the reusable per-user compute session for the context, so it
        also sees libraries created by prior ``execute_sas_code`` calls.

        Args:
            compute_context_name: Name of the compute context (see list_compute_contexts).
            limit: Maximum number of libraries to return (default 50).
            start: Offset of the first library to return (default 0).
            filter_name: Optional name filter (substring match).
        """
        async with compute_tool_session("list_compute_libraries", ctx, compute_context_name) as (client, session_id):
            filters = f"contains(name,'{filter_name}')" if filter_name else None
            items, _ = await get_paged_items(
                f"/compute/sessions/{session_id}/data",
                client,
                limit=limit,
                start=start,
                filters=filters,
            )
            return return_items(items, ["name", "description"])

    @mcp.tool()
    async def list_compute_tables(
        compute_context_name: str,
        library_name: str,
        ctx: Context,
        limit: int = 50,
        start: int = 0,
        filter_name: str | None = None,
    ) -> list[dict[str, Any]]:
        """List the tables in a SAS library within a compute context.

        These are SAS/Compute tables (e.g. WORK or an assigned libref), distinct
        from in-memory CAS tables (see list_castables). Runs in the reusable
        per-user compute session for the context.

        Args:
            compute_context_name: Name of the compute context (see list_compute_contexts).
            library_name: Name of the SAS library/libref (e.g. 'WORK', 'SASHELP').
            limit: Maximum number of tables to return (default 50).
            start: Offset of the first table to return (default 0).
            filter_name: Optional name filter (substring match).
        """
        async with compute_tool_session("list_compute_tables", ctx, compute_context_name) as (client, session_id):
            filters = f"contains(name,'{filter_name}')" if filter_name else None
            items, _ = await get_paged_items(
                f"/compute/sessions/{session_id}/data/{library_name}",
                client,
                limit=limit,
                start=start,
                filters=filters,
            )
            return return_items(items, ["name", "description"])

    @mcp.tool()
    async def list_compute_columns(
        compute_context_name: str,
        library_name: str,
        table_name: str,
        ctx: Context,
        limit: int = 50,
        start: int = 0,
        filter_name: str | None = None,
    ) -> list[dict[str, Any]]:
        """List the columns of a table in a SAS library within a compute context.

        Runs in the reusable per-user compute session for the context.

        Args:
            compute_context_name: Name of the compute context (see list_compute_contexts).
            library_name: Name of the SAS library/libref (e.g. 'WORK', 'SASHELP').
            table_name: Name of the table within the library.
            limit: Maximum number of columns to return (default 50).
            start: Offset of the first column to return (default 0).
            filter_name: Optional name filter (substring match).
        """
        async with compute_tool_session("list_compute_columns", ctx, compute_context_name) as (client, session_id):
            filters = f"contains(name,'{filter_name}')" if filter_name else None
            items, _ = await get_paged_items(
                f"/compute/sessions/{session_id}/data/{library_name}/{table_name}/columns",
                client,
                limit=limit,
                start=start,
                filters=filters,
            )
            return return_items(items, ["id", "name", "label", "type", "length"])

    @mcp.tool()
    async def reset_compute_session(ctx: Context, compute_context_name: str | None = None) -> dict[str, str]:
        """Reset (delete) the cached compute session for a compute context.

        The server keeps one reusable SAS compute session per user and compute
        context so repeat calls skip the slow session spin-up; SAS state (WORK
        tables, macro variables, assigned librefs) therefore persists across
        ``execute_sas_code`` and ``list_compute_*`` calls. Call this to discard
        that state — the next compute tool call transparently creates a fresh
        session.

        Args:
            compute_context_name: Compute context whose session to reset.
                Defaults to the server's configured execution context (the one
                ``execute_sas_code`` uses).
        """
        context_name = compute_context_name or CONTEXT_NAME
        logger.info("--- TOOL USED: reset_compute_session ---")
        token = await get_token(ctx)
        async with make_client(token) as client:
            sid = await reset_cached_session(client, context_name, token)
        if sid is None:
            return {
                "status": "no_active_session",
                "compute_context": context_name,
                "message": "No cached compute session to reset for this context.",
            }
        return {
            "status": "reset",
            "compute_context": context_name,
            "deleted_session": sid,
        }

    # ------------------------------------------------------------------
    # Tier 7 — Information Catalog (metadata discovery & profiling)
    # ------------------------------------------------------------------

    catalog = "/catalog"
    search_collection_type = "application/vnd.sas.metadata.search.collection+json"
    # The adhoc job's status lives only in the full representation; the summary
    # (application/json) omits it.
    adhoc_media = "application/vnd.sas.metadata.bot.adhoc+json"
    profile_levels = ("dataDictionary", "dataDictionaryAndProfile", "detailedMetrics")

    def resource_uri_of(item: dict[str, Any]) -> str:
        """Pull the source-asset URI (rel='resource') from a catalog item's links."""
        for link in item.get("links", []) or []:
            if link.get("rel") == "resource":
                return link.get("href", "") or link.get("uri", "")
        return ""

    async def instance_for_resource_uri(client: httpx.AsyncClient, resource_uri: str) -> dict[str, Any] | None:
        """Resolve the catalog instance for a source-asset URI, or None if absent.

        Filters ``/catalog/instances`` by ``resourceId`` — the reliable way to
        locate the instance that profiling writes its results onto, rather than
        assuming the instance id equals a search hit's id.
        """
        data = await get_json(
            f"{catalog}/instances",
            client,
            params={"filter": f'eq(resourceId,"{resource_uri}")'},
        )
        items = data.get("items", []) or []
        return items[0] if items else None

    @mcp.tool()
    async def catalog_search(
        query: str,
        ctx: Context,
        indices: str = "catalog",
        limit: int = 20,
        start: int = 0,
    ) -> dict[str, Any]:
        """Search the SAS Information Catalog for assets (tables, columns, reports, ...).

        The catalog is a metadata index across the whole Viya environment, so this
        finds assets without needing to know their server/library first. Each hit
        includes the asset's ``resource_uri`` — the URI you can hand to the matching
        tool (e.g. get_report, get_castable_data) to act on the live asset — and an
        ``attributes`` map with whatever metadata the catalog holds for it (commonly
        ``library``, ``rowCount``, ``columnCount``, ``completenessPercent``,
        ``reviewStatus``, ``informationPrivacy``, and ``analysisTimeStamp``).

        The ``query`` uses the SAS catalog search grammar:
          * Free text matches names, with wildcards ``*`` (0+ chars) and ``?`` (1 char): ``cust*``.
          * Facets constrain fields, e.g. ``AssetType:Report``, ``Name:sales``,
            ``Library.name:PUBLIC``, ``Column.informationPrivacy:Sensitive``.
          * Ranges ``DateModified:[2024-01-01 TO 2024-12-31]`` and ``+`` to require a term.
            Combine freely: ``AssetType:"CAS Table" +Name:cust*``.
        Use ``catalog_search_helper`` to discover valid facet names and values.

        Args:
            query: The catalog search query (see grammar above). Use ``*`` to match all names.
            indices: Comma-separated index name(s) to search (default 'catalog').
            limit: Maximum hits to return (default 20).
            start: Offset of the first hit (default 0).
        """
        async with viya_session("catalog_search", ctx) as client:
            data = await get_json(
                f"{catalog}/search",
                client,
                params={"q": query, "indices": indices, "start": start, "limit": limit},
                accept=search_collection_type,
            )
            raw_items = data.get("items", [])
            items = return_items(
                raw_items,
                [
                    "id",
                    "type",
                    "typeLabel",
                    "label",
                    "name",
                    "description",
                    "score",
                    "attributes",
                ],
            )
            # resource_uri is derived from the item's links, not a flat field.
            for out, src in zip(items, raw_items, strict=True):
                out["resource_uri"] = resource_uri_of(src)
            return {
                "count": data.get("count", len(items)),
                "start": data.get("start", start),
                "limit": data.get("limit", limit),
                "items": items,
            }

    @mcp.tool()
    async def catalog_search_helper(
        ctx: Context, facet: str | None = None, query: str = "", limit: int = 50
    ) -> dict[str, Any]:
        """Discover how to search the catalog: list facets, or values for one facet.

        Call with no ``facet`` to list the available facets — the fields you can
        constrain in a ``catalog_search`` query. Call with a ``facet`` name to get the
        suggested/valid values for that facet (e.g. the asset types or review
        statuses that actually exist). Use the results to build precise
        ``catalog_search`` queries.

        Args:
            facet: Facet name to get suggested values for (e.g. 'AssetType'). If
                omitted, returns the list of available facets instead.
            query: Optional filter — when listing facets, matches facet names; when
                listing values, matches value prefixes.
            limit: Maximum entries to return (default 50).
        """
        async with viya_session("catalog_search_helper", ctx) as client:
            if facet:
                data = await get_json(
                    f"{catalog}/search/suggestions",
                    client,
                    params={"facet": facet, "q": query, "limit": limit},
                )
                return {"facet": facet, "values": data.get("items", [])}
            data = await get_json(
                f"{catalog}/search/facets",
                client,
                params={"q": query, "start": 0, "limit": limit},
            )
            facets = return_items(data.get("items", []), ["name", "type", "indices"])
            return {"facets": facets}

    @mcp.tool()
    async def catalog_find_instance(resource_uri: str, ctx: Context) -> dict[str, Any]:
        """Resolve the catalog instance for a source-asset URI.

        ``catalog_search`` finds assets by free text and facets, but the
        profiling and download tools key off a catalog *instance id*. When you
        already hold a resource URI — the ``resource_uri`` from a search hit, or
        a CAS table path — this looks the instance up directly by ``resourceId``
        (the same filter the profiling workflow uses) and returns its id plus
        the key profile attributes. Use it to tell at a glance whether the asset
        has been profiled (``analysisTimeStamp``) and what semantic metadata it
        carries (``informationPrivacy``, ``nlpTerms``, ``nlpTags``,
        ``mostImportantFields``) before calling ``catalog_download_table_profile``.

        Args:
            resource_uri: Source URI of the asset (e.g.
                '/dataTables/dataSources/cas~fs~.../tables/MYTABLE').
        """
        async with viya_session("catalog_find_instance", ctx) as client:
            inst = await instance_for_resource_uri(client, resource_uri)
            if inst is None:
                return {
                    "status": "not_found",
                    "resource_uri": resource_uri,
                    "message": (
                        "No catalog instance indexes that URI yet. Confirm the URI "
                        "with catalog_search, or run a discovery agent "
                        "(catalog_run_agent) to populate it."
                    ),
                }
            attrs = inst.get("attributes", {}) or {}
            return {
                "status": "ok",
                "instance_id": inst.get("id"),
                "name": inst.get("name", ""),
                "type": inst.get("type", ""),
                "resource_uri": inst.get("resourceId", resource_uri),
                "profiled": bool(attrs.get("analysisTimeStamp")),
                "attributes": attrs,
            }

    @mcp.tool()
    async def catalog_list_agents(
        ctx: Context, limit: int = 50, start: int = 0, filter_name: str | None = None
    ) -> list[dict[str, Any]]:
        """List SAS Information Catalog discovery agents.

        Agents crawl a data source (server/library) to discover assets and collect
        their metadata into the catalog. Use ``catalog_run_agent`` to start one and
        ``catalog_get_agent_history`` to see what a run produced.

        Args:
            limit: Maximum agents to return (default 50).
            start: Offset of the first agent (default 0).
            filter_name: Optional name filter (substring match).
        """
        params: dict[str, Any] = {"start": start, "limit": limit}
        if filter_name:
            params["filter"] = f"contains(name,'{filter_name}')"
        async with viya_session("catalog_list_agents", ctx) as client:
            data = await get_json(f"{catalog}/bots", client, params=params)
            return return_items(
                data.get("items", []),
                ["id", "name", "description", "agentType", "provider"],
            )

    @mcp.tool()
    async def catalog_run_agent(agent_id: str, ctx: Context) -> dict[str, str]:
        """Start a catalog discovery agent run (asynchronous).

        Triggers the agent to crawl its data source and populate/refresh catalog
        metadata. The run is asynchronous — results are applied to the catalog in
        the background; poll ``catalog_get_agent_history`` to track completion.
        Note: the Catalog API can only *start* an agent, not stop one already running.

        Args:
            agent_id: ID of the agent to run (see catalog_list_agents).
        """
        async with viya_session("catalog_run_agent", ctx) as client:
            resp = await client.put(
                f"{VIYA_ENDPOINT}{catalog}/bots/{agent_id}/state",
                params={"value": "running"},
                headers={"Accept": "text/plain"},
            )
            resp.raise_for_status()
            return {
                "status": resp.text.strip() or "running",
                "agent_id": agent_id,
                "message": (
                    "Agent started; metadata is applied to the catalog asynchronously. "
                    "Poll catalog_get_agent_history for completion."
                ),
            }

    @mcp.tool()
    async def catalog_get_agent_history(
        agent_id: str, ctx: Context, limit: int = 20, start: int = 0
    ) -> list[dict[str, Any]]:
        """Get the execution history of a catalog agent's runs.

        Each record reports a run's status and how much metadata it populated
        (tables enumerated/added/updated/removed), so you can confirm a run started
        by ``catalog_run_agent`` finished and what it changed.

        Args:
            agent_id: ID of the agent (see catalog_list_agents).
            limit: Maximum run records to return (default 20).
            start: Offset of the first record (default 0).
        """
        async with viya_session("catalog_get_agent_history", ctx) as client:
            data = await get_json(
                f"{catalog}/bots/{agent_id}/history",
                client,
                params={"start": start, "limit": limit},
            )
            return return_items(
                data.get("items", []),
                [
                    "id",
                    "status",
                    "creationTimeStamp",
                    "endTimeStamp",
                    "nEnumerated",
                    "nAdded",
                    "nUpdated",
                    "nRemoved",
                ],
            )

    @mcp.tool()
    async def catalog_run_adhoc_analysis(
        resource_uri: str,
        name: str,
        ctx: Context,
        resource_type: str = "",
        description: str = "",
        provider: str = "TABLE-BOT",
        identify_language: bool = True,
        analyze_sentiment: bool = True,
        get_nlp_semantic_id: bool = True,
    ) -> dict[str, Any]:
        """Submit an ad-hoc analysis (profiling) job for a table in the catalog.

        Profiles the table — computing the data dictionary, column statistics, and
        data-quality metrics that ``catalog_download_table_profile`` returns. The job
        runs asynchronously and may take a while; poll ``catalog_get_adhoc_analysis``
        with the returned job id until the profile is ready.

        The three NLP job parameters are enabled by default — they drive the
        semantic enrichment that populates an asset's ``informationPrivacy``,
        ``nlpTerms``, ``nlpTags``, and ``mostImportantFields`` (the privacy and
        keyword signals the catalog is most useful for). Leave them on unless you
        only need a plain column profile and want the job to finish faster.

        Args:
            resource_uri: Source URI of the table to analyze (the ``resource_uri`` from
                a catalog_search hit, e.g. '/dataTables/dataSources/cas~fs~.../tables/MYTABLE').
            name: A name for the analysis job.
            resource_type: Catalog entity type of the resource. Defaults to
                'CASMEMTable' when the URI is a CAS table (contains 'cas~fs~');
                pass it explicitly for other asset types.
            description: Optional description for the job.
            provider: Job provider (default 'TABLE-BOT').
            identify_language: Detect each text column's language (default True).
            analyze_sentiment: Score sentiment on text columns (default True).
            get_nlp_semantic_id: Derive semantic types / privacy classification
                (informationPrivacy, nlpTerms, nlpTags) (default True).
        """
        rtype = resource_type or ("CASMEMTable" if "cas~fs~" in resource_uri else "")
        if not rtype:
            return {
                "status": "missing_resource_type",
                "resource_uri": resource_uri,
                "message": (
                    "Could not infer resource_type from the URI. Pass resource_type "
                    "explicitly (e.g. 'CASMEMTable' for a CAS table)."
                ),
            }
        job_parameters: dict[str, str] = {}
        if identify_language:
            job_parameters["identifyLanguage"] = "1"
        if analyze_sentiment:
            job_parameters["analyzeSentiment"] = "1"
        if get_nlp_semantic_id:
            job_parameters["getNLPSemanticID"] = "1"
        body = {
            "provider": provider,
            "name": name,
            "description": description,
            "resources": [{"uri": resource_uri, "type": rtype}],
            "jobParameters": job_parameters,
        }
        async with viya_session("catalog_run_adhoc_analysis", ctx) as client:
            job = await post_json(
                f"{catalog}/bots/adhocAnalysisJobs",
                client,
                body=body,
                accept=adhoc_media,
            )
            return {
                "id": job.get("id"),
                "status": job.get("status", ""),
                "name": job.get("name", name),
                "message": (
                    "Analysis submitted. Poll catalog_get_adhoc_analysis until status "
                    "is 'completed', then catalog_download_table_profile."
                ),
            }

    @mcp.tool()
    async def catalog_get_adhoc_analysis(job_id: str, ctx: Context) -> dict[str, Any]:
        """Get the status of an ad-hoc analysis job, and whether its profile is ready.

        The job reaching a terminal ``status`` is *not* sufficient: the profile
        attributes are written onto the asset a little later, so a download fired
        the instant the job completes can come back empty. To close that gap, when
        the job carries a resource this also resolves the target catalog instance
        and reports ``profile_ready`` (the asset's ``analysisTimeStamp`` is
        populated — the same gate ``catalog_download_table_profile`` uses) and
        ``information_privacy`` (non-empty once the NLP semantic enrichment has
        landed). Poll until ``profile_ready`` is true, then download.

        Args:
            job_id: The analysis job id returned by catalog_run_adhoc_analysis.
        """
        async with viya_session("catalog_get_adhoc_analysis", ctx) as client:
            try:
                job = await get_json(
                    f"{catalog}/bots/adhocAnalysisJobs/{job_id}",
                    client,
                    accept=adhoc_media,
                )
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    # Adhoc jobs can be purged once terminal — report it as such
                    # rather than raising, so polling loops can stop cleanly.
                    return {
                        "id": job_id,
                        "status": "not_found",
                        "message": ("No such analysis job — it may have finished and been purged, or the id is wrong."),
                    }
                raise
            resources = job.get("resources", []) or []
            resource_uri = ""
            if resources:
                resource_uri = resources[0].get("uri", "") or resources[0].get("resourceId", "")
            # Cross-check the asset itself: the job can be terminal while the
            # profile is still being written onto the instance.
            instance_id = ""
            profile_ready = False
            information_privacy = ""
            if resource_uri:
                inst = await instance_for_resource_uri(client, resource_uri)
                if inst:
                    instance_id = inst.get("id", "")
                    inst_attrs = inst.get("attributes", {}) or {}
                    profile_ready = bool(inst_attrs.get("analysisTimeStamp"))
                    information_privacy = inst_attrs.get("informationPrivacy", "") or ""
            return {
                "id": job.get("id", job_id),
                "status": job.get("status", ""),
                "name": job.get("name", ""),
                "creationTimeStamp": job.get("creationTimeStamp", ""),
                "endTimeStamp": job.get("endTimeStamp", ""),
                "resources": resources,
                "instance_id": instance_id,
                "profile_ready": profile_ready,
                "information_privacy": information_privacy,
                "message": (
                    f"Profile ready — download with catalog_download_table_profile (instance_id='{instance_id}')."
                    if profile_ready
                    else "Profile not written to the asset yet — poll again before downloading."
                ),
            }

    @mcp.tool()
    async def catalog_download_table_profile(
        ctx: Context,
        instance_id: str = "",
        resource_uri: str = "",
        level: str = "dataDictionaryAndProfile",
    ) -> dict[str, Any]:
        """Download a catalog table's data dictionary and profile as CSV.

        Returns the table's column metadata plus, by default, its profile (column
        statistics and data-quality metrics). If the table has not been profiled yet,
        this returns a recommendation to run ``catalog_run_adhoc_analysis`` (pre-filled
        with the table's URI and type) instead of an empty profile.

        Identify the table by either ``instance_id`` or ``resource_uri`` (give one).
        Passing ``resource_uri`` lets you run search → profile → download without ever
        handling an instance id: the asset is resolved by ``resourceId`` the same way
        ``catalog_find_instance`` does. ``instance_id`` takes precedence if both are given.

        Args:
            instance_id: Catalog instance id of the table (the ``id`` from a catalog_search hit).
            resource_uri: Source URI of the table (the ``resource_uri`` from a search hit,
                e.g. '/dataTables/dataSources/cas~fs~.../tables/MYTABLE'). Used when
                ``instance_id`` is omitted.
            level: Detail level — 'dataDictionaryAndProfile' (default; columns + profile),
                'detailedMetrics' (full per-column metrics), or 'dataDictionary'
                (column metadata only).
        """
        if level not in profile_levels:
            return {
                "status": "invalid_level",
                "message": f"level must be one of {', '.join(profile_levels)}.",
            }
        if not instance_id and not resource_uri:
            return {
                "status": "missing_identifier",
                "message": "Pass either instance_id or resource_uri.",
            }
        async with viya_session("catalog_download_table_profile", ctx) as client:
            # Resolve the instance first to identify the asset and whether it is profiled.
            if instance_id:
                try:
                    inst = await get_json(
                        f"{catalog}/instances/{instance_id}",
                        client,
                        accept="application/vnd.sas.metadata.instance.entity+json",
                    )
                except httpx.HTTPStatusError as e:
                    if e.response.status_code == 404:
                        return {
                            "status": "not_found",
                            "instance_id": instance_id,
                            "message": (f"No catalog instance '{instance_id}'. Use catalog_search to find one."),
                        }
                    raise
            else:
                inst = await instance_for_resource_uri(client, resource_uri)
                if inst is None:
                    return {
                        "status": "not_found",
                        "resource_uri": resource_uri,
                        "message": (
                            f"No catalog instance indexes '{resource_uri}'. "
                            "Use catalog_search or catalog_find_instance to confirm it."
                        ),
                    }
                instance_id = inst.get("id", "")
            attrs = inst.get("attributes", {}) or {}
            resource_uri = inst.get("resourceId", "") or resource_uri
            resource_type = inst.get("type", "")
            wants_profile = level in ("dataDictionaryAndProfile", "detailedMetrics")
            if wants_profile and not attrs.get("analysisTimeStamp"):
                return {
                    "status": "not_profiled",
                    "instance_id": instance_id,
                    "resource_uri": resource_uri,
                    "resource_type": resource_type,
                    "message": (
                        "This table has no profile yet. Run catalog_run_adhoc_analysis "
                        f"with resource_uri='{resource_uri}' and "
                        f"resource_type='{resource_type}', poll catalog_get_adhoc_analysis "
                        "until completed, then retry."
                    ),
                }
            resp = await client.get(
                f"{VIYA_ENDPOINT}{catalog}/instances",
                params={"level": level, "filter": f"eq(id,'{instance_id}')"},
                headers={"Accept": "text/csv"},
                follow_redirects=True,
            )
            resp.raise_for_status()
            return {
                "status": "ok",
                "instance_id": instance_id,
                "resource_uri": resource_uri,
                "level": level,
                "csv": resp.text,
            }

    # ------------------------------------------------------------------
    # Tier 8 — SAS Analytics for IoT (AIoT)
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_data_selections_tool(
        ctx: Context,
        filter_query: str = None,
        start: int = 0,
        limit: int = 10,
        owner: str = None,
        owner_display_name: str = None,
        created_by: str = None,
        name: str = None,
        category: str = None,
        creation_type: str = None,
        attribute_filters: dict = None
    ) -> dict:
        """
        Lists all available SAS Analytics for IoT data selections.
        Supports filtering by any attribute (e.g., owner, owner_display_name) on the retrieved collection.

        Args:
            filter_query (str): Optional service-side filter string (e.g., "eq(createdBy,'Martin Schuetz')")
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 10)
            owner (str): Optional case-insensitive substring filter for owner username (e.g., 'germsz')
            owner_display_name (str): Optional case-insensitive substring filter for owner display name
                                      (e.g., 'Schuetz, Martin')
            created_by (str): Optional case-insensitive substring filter for creator name (e.g., 'Martin')
            name (str): Optional case-insensitive substring filter for data selection name (e.g., 'Chiller')
            category (str): Optional case-insensitive substring filter for category (e.g., 'SIMPLE')
            creation_type (str): Optional case-insensitive substring filter for creation type
                                 (e.g., 'DEFAULT')
            attribute_filters (dict): Optional dictionary mapping any attribute name to target value
                                      for dynamic filtering
        """
        logger.info(f"--- TOOL USED: list_data_selections (filter: {filter_query}) ---")
        token = await get_token(ctx)

        # To support local filtering across the entire collection, fetch all items in batches
        all_items = []
        current_start = 0
        fetch_limit = 100

        while True:
            raw_data = await list_data_selections(
                token,
                filter_query=filter_query,
                start=current_start,
                limit=fetch_limit
            )
            items = raw_data.get("items", [])
            all_items.extend(items)
            
            total_count = raw_data.get("count", 0)
            if len(items) < fetch_limit or len(all_items) >= total_count:
                break
            current_start += fetch_limit

        # Apply client-side attribute filtering
        filtered_items = all_items

        def matches_filter(item_val, filter_val) -> bool:
            if item_val is None:
                return False
            return str(filter_val).lower() in str(item_val).lower()

        if owner:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("owner"), owner)]
        if owner_display_name:
            filtered_items = [
                item for item in filtered_items
                if matches_filter(item.get("ownerDisplayName"), owner_display_name)
            ]
        if created_by:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("createdBy"), created_by)]
        if name:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("name"), name)]
        if category:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("category"), category)]
        if creation_type:
            filtered_items = [
                item for item in filtered_items
                if matches_filter(item.get("creationType"), creation_type)
            ]

        if attribute_filters:
            for attr, val in attribute_filters.items():
                filtered_items = [item for item in filtered_items if matches_filter(item.get(attr), val)]

        total_filtered_count = len(filtered_items)
        paginated_items = filtered_items[start : start + limit]

        # Prune response but include key attributes for transparency
        pruned_items = [
            {
                "id": item.get("id"),
                "name": item.get("name"),
                "createdBy": item.get("createdBy"),
                "creationTimeStamp": item.get("creationTimeStamp"),
                "owner": item.get("owner"),
                "ownerDisplayName": item.get("ownerDisplayName"),
                "category": item.get("category"),
                "creationType": item.get("creationType"),
                "description": item.get("description"),
            }
            for item in paginated_items
        ]

        return {
            "count": total_filtered_count,
            "items": pruned_items,
            "limit": limit,
            "start": start
        }

    @mcp.tool()
    async def get_data_selection_details(selection_id: str, ctx: Context) -> dict:
        """
        Retrieves detailed information and metadata for a specific SAS AIoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
        """
        logger.info(f"--- TOOL USED: get_data_selection_details ({selection_id}) ---")
        token = await get_token(ctx)
        return await get_data_selection(selection_id, token)

    @mcp.tool()
    async def update_data_selection_tool(selection_id: str, selection_data: dict, ctx: Context) -> dict:
        """
        Updates a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
            selection_data (dict): The complete data selection definition to update.
        """
        logger.info(f"--- TOOL USED: update_data_selection ({selection_id}) ---")
        token = await get_token(ctx)
        return await update_data_selection(selection_id, selection_data, token)

    @mcp.tool()
    async def delete_data_selection_tool(selection_id: str, ctx: Context) -> str:
        """
        Deletes a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
        """
        logger.info(f"--- TOOL USED: delete_data_selection ({selection_id}) ---")
        token = await get_token(ctx)
        await delete_data_selection(selection_id, token)
        return f"Data selection {selection_id} deleted successfully."

    @mcp.tool()
    async def set_data_selection_date_range_tool(selection_id: str, start_date: str, 
                                               end_date: str, ctx: Context) -> dict:
        """
        Updates the Measure Date Time filter for a data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
            start_date (str): The start date in ISO 8601 format (e.g., '2024-07-01T00:00:00Z').
            end_date (str): The end date in ISO 8601 format (e.g., '2024-09-30T23:59:59Z').
        """
        logger.info(f"--- TOOL USED: set_data_selection_date_range ({selection_id}) ---")
        token = await get_token(ctx)
        return await set_data_selection_date_range(selection_id, start_date, end_date, token)

    @mcp.tool()
    async def launch_data_selection_tool(selection_id: str, ctx: Context) -> dict:
        """
        Triggers a launch job for a specific data selection, loading the data into CAS for analysis.

        Args:
            selection_id (str): The unique identifier of the data selection to launch.
        """
        logger.info(f"--- TOOL USED: launch_data_selection ({selection_id}) ---")
        token = await get_token(ctx)
        return await launch_data_selection(selection_id, token)

    @mcp.tool()
    async def launch_data_selection_and_wait_tool(selection_id: str, ctx: Context) -> dict:
        """
        Launches a data selection and waits for the job to complete.

        Args:
            selection_id (str): The unique identifier of the data selection to launch.
        """
        logger.info(f"--- TOOL USED: launch_data_selection_and_wait ({selection_id}) ---")
        token = await get_token(ctx)
        return await launch_data_selection_and_wait(selection_id, token)

    @mcp.tool()
    async def copy_data_selection_tool(selection_id: str, new_name: str, 
                                       ctx: Context, new_description: str = "") -> dict:
        """
        Copies a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection to copy.
            new_name (str): The name for the new data selection.
            new_description (str): Optional description for the new data selection.
        """
        logger.info(f"--- TOOL USED: copy_data_selection ({selection_id} -> {new_name}) ---")
        token = await get_token(ctx)
        return await copy_data_selection(selection_id, new_name, token, new_description)

    @mcp.tool()
    async def copy_data_selections_tool(selection_ids: list[str], ctx: Context) -> dict:
        """
        Copies multiple SAS Analytics for IoT data selections.

        Args:
            selection_ids (list[str]): List of data selection identifiers to copy.
        """
        logger.info(f"--- TOOL USED: copy_data_selections ({len(selection_ids)} items) ---")
        token = await get_token(ctx)
        return await copy_data_selections(selection_ids, token)

    @mcp.tool()
    async def list_iot_projects_tool(ctx: Context) -> dict:
        """
        Lists all defined project instances in SAS Analytics for IoT.
        """
        logger.info("--- TOOL USED: list_iot_projects ---")
        token = await get_token(ctx)
        return await list_iot_projects(token)

    @mcp.tool()
    async def list_iot_analyses_tool(ctx: Context) -> dict:
        """
        Lists all defined SAS Analytics for IoT analyses.
        """
        logger.info("--- TOOL USED: list_iot_analyses ---")
        token = await get_token(ctx)
        return await list_iot_analyses(token)

    @mcp.tool()
    async def get_iot_analysis_details_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Retrieves the full definition of an IoT analysis, including steps and parameters.

        Args:
            analysis_id (str): The unique identifier of the analysis.
        """
        logger.info(f"--- TOOL USED: get_iot_analysis_details ({analysis_id}) ---")
        token = await get_token(ctx)
        return await get_iot_analysis(analysis_id, token)

    @mcp.tool()
    async def create_iot_analysis_tool(
        name: str,
        model_name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_instance_id: str = None,
        parent_step_id: str = None,
        subset_group_name: str = None,
        filter_criteria: list = None
    ) -> dict:
        """
        Creates a new IoT analysis instance.

        Args:
            name (str): Name for the new analysis.
            model_name (str): Name of the analysis model (e.g., 'EXPLORATION_ASSET').
            data_selection_id (str): ID of the data selection to associate.
            folder_id (str): Optional ID of the project folder to create the analysis in.
            parent_instance_id (str): Optional parent analysis instance ID for hierarchical linking.
            parent_step_id (str): Optional parent analysis step ID for hierarchical linking.
            subset_group_name (str): Optional subset group name (required if parent linking is used).
            filter_criteria (list): Optional filter criteria list (required if parent linking is used).
        """
        logger.info(f"--- TOOL USED: create_iot_analysis ({name}) ---")
        token = await get_token(ctx)
        return await create_iot_analysis(
            name, model_name, data_selection_id, token, folder_id,
            parent_instance_id, parent_step_id, subset_group_name, filter_criteria
        )

    @mcp.tool()
    async def delete_iot_analysis_tool(analysis_id: str, ctx: Context) -> str:
        """
        Deletes a specific SAS Analytics for IoT analysis.

        Args:
            analysis_id (str): The unique identifier of the analysis.
        """
        logger.info(f"--- TOOL USED: delete_iot_analysis ({analysis_id}) ---")
        token = await get_token(ctx)
        await delete_iot_analysis(analysis_id, token)
        return f"Analysis {analysis_id} deleted successfully."

    @mcp.tool()
    async def run_iot_analysis_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Submits a job to run a specific IoT analysis.

        Args:
            analysis_id (str): The unique identifier of the analysis to run.
        """
        logger.info(f"--- TOOL USED: run_iot_analysis ({analysis_id}) ---")
        token = await get_token(ctx)
        return await run_iot_analysis(analysis_id, token)

    @mcp.tool()
    async def run_iot_analysis_and_wait_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Runs a specific IoT analysis and waits for the job to complete.

        Args:
            analysis_id (str): The unique identifier of the analysis to run.
        """
        logger.info(f"--- TOOL USED: run_iot_analysis_and_wait ({analysis_id}) ---")
        token = await get_token(ctx)
        return await run_iot_analysis_and_wait(analysis_id, token)

    @mcp.tool()
    async def copy_iot_analyses_tool(analysis_ids: list[str], ctx: Context) -> dict:
        """
        Copies multiple SAS Analytics for IoT analyses.

        Args:
            analysis_ids (list[str]): List of analysis identifiers to copy.
        """
        logger.info(f"--- TOOL USED: copy_iot_analyses ({len(analysis_ids)} items) ---")
        token = await get_token(ctx)
        return await copy_iot_analyses(analysis_ids, token)

    @mcp.tool()
    async def get_iot_analysis_results(analysis_id: str, job_id: str, ctx: Context) -> dict:
        """
        Retrieves the status and results of a specific IoT analysis job.

        Args:
            analysis_id (str): The identifier of the analysis.
            job_id (str): The identifier of the specific job run.
        """
        logger.info(f"--- TOOL USED: get_iot_analysis_results ({analysis_id}, {job_id}) ---")
        token = await get_token(ctx)
        return await get_iot_analysis_job(analysis_id, job_id, token)

    @mcp.tool()
    async def get_iot_analysis_output_tables_tool(analysis_id: str, ctx: Context) -> list[str]:
        """
        Finds the names of CAS tables generated by an IoT analysis.

        Args:
            analysis_id (str): The unique identifier of the analysis.
        """
        logger.info(f"--- TOOL USED: get_iot_analysis_output_tables ({analysis_id}) ---")
        token = await get_token(ctx)
        analysis = await get_iot_analysis(analysis_id, token)
        
        tables = []
        for step in analysis.get("steps", []):
            for param in step.get("outputParameters", []):
                if param.get("parameterName") in ["OUTPUT_TABLE", "OUT_TABLE", "SC_TABLE"]:
                    val = param.get("parameterValue")
                    if val and val not in tables:
                        tables.append(val)
        return tables

    @mcp.tool()
    async def list_iot_models_tool(ctx: Context) -> dict:
        """
        Lists all registered models in SAS Analytics for IoT.
        """
        logger.info("--- TOOL USED: list_iot_models ---")
        token = await get_token(ctx)
        return await list_iot_models(token)

    @mcp.tool()
    async def get_iot_model_definition_tool(model_name: str, ctx: Context) -> dict:
        """
        Retrieves metadata and parameter definitions for a specific AIoT model.

        Args:
            model_name (str): The name/ID of the model (e.g., 'EXPLORATION_ASSET').
        """
        logger.info(f"--- TOOL USED: get_iot_model_definition ({model_name}) ---")
        token = await get_token(ctx)
        return await get_iot_model(model_name, token)

    @mcp.tool()
    async def list_emerging_issue_runs_tool(
        ctx: Context,
        start: int = 0,
        limit: int = 10,
        name: str = None,
        status: str = None,
        created_by: str = None,
        owner: str = None,
        attribute_filters: dict = None
    ) -> dict:
        """
        Lists all Emerging Issue analysis runs.
        Supports filtering by any attribute (e.g., name, status, owner, createdBy) on the retrieved collection.

        Args:
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 10)
            name (str): Optional case-insensitive substring filter for run name (e.g., 'Emerging')
            status (str): Optional case-insensitive substring filter for run status (e.g., 'Completed')
            created_by (str): Optional case-insensitive substring filter for creator name (e.g., 'germsz')
            owner (str): Optional case-insensitive substring filter for owner username or display name
            attribute_filters (dict): Optional dictionary mapping any attribute name to target value
                                      for dynamic filtering
        """
        logger.info("--- TOOL USED: list_emerging_issue_runs ---")
        token = await get_token(ctx)

        # Fetch all items in batches
        all_items = []
        current_start = 0
        fetch_limit = 100

        while True:
            raw_data = await list_iot_analyses(
                token,
                start=current_start,
                limit=fetch_limit
            )
            items = raw_data.get("items", [])
            all_items.extend(items)
            
            if len(items) < fetch_limit:
                break
            current_start += fetch_limit

        # Filter by Emerging Issues model types
        filtered_items = [
            item for item in all_items
            if "EI" in item.get("modelName", "").upper()
            or "EMERGING" in item.get("modelName", "").upper()
            or "EMERGING" in item.get("name", "").upper()
        ]

        def matches_filter(item_val, filter_val) -> bool:
            if item_val is None:
                return False
            return str(filter_val).lower() in str(item_val).lower()

        if name:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("name"), name)]
        if status:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("status"), status)]
        if created_by:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("createdBy"), created_by)]
        if owner:
            filtered_items = [
                item for item in filtered_items
                if matches_filter(item.get("currentOwner"), owner)
                or matches_filter(item.get("currentOwnerDisplayName"), owner)
            ]

        if attribute_filters:
            for attr, val in attribute_filters.items():
                filtered_items = [item for item in filtered_items if matches_filter(item.get(attr), val)]

        total_filtered_count = len(filtered_items)
        paginated_items = filtered_items[start : start + limit]

        pruned_items = [
            {
                "id": item.get("id"),
                "name": item.get("name"),
                "modelName": item.get("modelName"),
                "status": item.get("status"),
                "displayStatus": item.get("displayStatus"),
                "lastRunDate": item.get("lastRunDate"),
                "createdBy": item.get("createdBy"),
                "currentOwner": item.get("currentOwner"),
                "currentOwnerDisplayName": item.get("currentOwnerDisplayName"),
                "dataSelectionId": item.get("dataSelectionId"),
                "description": item.get("description"),
            }
            for item in paginated_items
        ]

        return {
            "items": pruned_items,
            "total": total_filtered_count,
            "start": start,
            "limit": limit
        }

    @mcp.tool()
    async def list_alerts_for_run_tool(
        analysis_id: str,
        ctx: Context,
        start: int = 0,
        limit: int = 20,
        alert_id: str = None,
        alert_type: str = None,
        model_cd: str = None,
        cstmr_country_cd: str = None,
        seasonal_flag: str = None,
        display_status_cd: str = None,
        attribute_filters: dict = None
    ) -> dict:
        """
        Retrieves the list of alerts generated by a completed Emerging Issue analysis run.
        Supports case-insensitive filtering on any alert attribute.

        Args:
            analysis_id (str): The unique ID of the Emerging Issue analysis/run.
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 20)
            alert_id (str): Optional case-insensitive filter for alert ID
            alert_type (str): Optional case-insensitive filter for alert type (e.g., 'PRODUCTIONPERIOD')
            model_cd (str): Optional case-insensitive filter for model code (e.g., 'Beta', 'Abyss')
            cstmr_country_cd (str): Optional case-insensitive filter for customer country code (e.g., '840')
            seasonal_flag (str): Optional case-insensitive filter for seasonal flag (e.g., 'N', 'Y')
            display_status_cd (str): Optional case-insensitive filter for display status code (e.g., 'Active')
            attribute_filters (dict): Optional dictionary of additional attribute-value filters
        """
        logger.info(f"--- TOOL USED: list_alerts_for_run ({analysis_id}) ---")
        token = await get_token(ctx)

        # 1. Retrieve the analysis definition to check its shortId
        analysis = await get_iot_analysis(analysis_id, token)
        short_id = analysis.get("shortId")
        if not short_id:
            short_id = analysis_id.split("-")[0]

        model_name = analysis.get("modelName", "EIENTERPRISE_PRODUCT")
        prefix = model_name.split("_")[0] if "_" in model_name else model_name

        # 2. Query CAS server to find the exact alerts table name
        cas_code = """
        cas mySession;
        caslib _all_ assign;
        proc cas;
          table.tableInfo / caslib="QASANLOUT";
        quit;
        """
        
        res = await run_one_snippet(cas_code, "find_alerts_table", token)
        listing = res.get("listing", "")
        
        import re
        table_pattern = rf"([A-Za-z0-9_]+_ALERTS_{short_id})"
        matches = re.findall(table_pattern, listing, re.IGNORECASE)
        
        if matches:
            matched_table = matches[0].upper()
            logger.info(f"Dynamically discovered alerts table name: {matched_table}")
        else:
            matched_table = f"{prefix}_ALERTS_{short_id}".upper()
            logger.warning(
                "Could not discover alerts table name via tableInfo. "
                f"Falling back to default: {matched_table}"
            )

        # 3. Export discovered table to JSON using SAS PROC JSON in a compute session
        export_code = f"""
        cas mySession;
        caslib _all_ assign;
        libname mycas cas caslib="QASANLOUT" sessref=mySession;

        filename myjson temp;
        proc json out=myjson pretty;
          export mycas.{matched_table};
        run;

        data _null_;
          infile myjson;
          input;
          put "JSON_OUT: " _infile_;
        run;
        """
        
        export_res = await run_one_snippet(export_code, "export_alerts", token)
        export_log = export_res.get("log", "")
        
        # 4. Extract and parse JSON data
        json_lines = []
        for line in export_log.splitlines():
            if line.startswith("JSON_OUT: "):
                json_lines.append(line[len("JSON_OUT: "):])
        
        json_str = "\n".join(json_lines)
        if not json_str.strip():
            logger.error(f"No JSON output from PROC JSON. Check log: {export_log}")
            return {
                "items": [],
                "total": 0,
                "start": start,
                "limit": limit,
                "message": (
                    f"No alerts found for run '{analysis_id}'. It might not "
                    f"have generated any alerts or table '{matched_table}' is empty."
                )
            }

        try:
            parsed_data = json.loads(json_str)
            alerts = []
            for key, val in parsed_data.items():
                if key.startswith("SASTableData"):
                    alerts = val
                    break
        except Exception as e:
            logger.exception("Failed to parse PROC JSON output from SAS log")
            return {
                "items": [],
                "total": 0,
                "start": start,
                "limit": limit,
                "error": f"Failed to parse alerts data from SAS log: {str(e)}"
            }

        # 5. Apply filtering on retrieved alerts
        def matches_filter(item_val, filter_val) -> bool:
            if item_val is None:
                return False
            return str(filter_val).lower() in str(item_val).lower()

        filtered_alerts = alerts

        if alert_id:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("alert_id"), alert_id)]
        if alert_type:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("alert_type"), alert_type)]
        if model_cd:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("model_cd"), model_cd)]
        if cstmr_country_cd:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(a.get("cstmr_country_cd"), cstmr_country_cd)
            ]
        if seasonal_flag:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("seasonal_flag"), seasonal_flag)]
        if display_status_cd:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(a.get("display_status_cd"), display_status_cd)
            ]

        if attribute_filters:
            for attr, val in attribute_filters.items():
                filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get(attr), val)]

        total_count = len(filtered_alerts)
        paginated_alerts = filtered_alerts[start : start + limit]

        return {
            "items": paginated_alerts,
            "total": total_count,
            "start": start,
            "limit": limit
        }

    @mcp.tool()
    async def list_folders_and_projects_tool(folder_id: str = None, ctx: Context = None) -> dict:
        """
        Lists folders, projects, and other members within a parent folder.
        If no folder_id is specified, lists root level folders and the user's home folder.

        Args:
            folder_id (str): Optional parent folder ID or URI.
        """
        logger.info(f"--- TOOL USED: list_folders_and_projects (folder_id={folder_id}) ---")
        token = await get_token(ctx)
        return await list_folders_and_projects(token, folder_id)

    @mcp.tool()
    async def create_folder_tool(
        name: str,
        parent_folder_id: str = "@myFolder",
        description: str = None,
        ctx: Context = None
    ) -> dict:
        """
        Creates a new folder inside a parent folder.

        Args:
            name (str): Name of the new folder.
            parent_folder_id (str): Parent folder ID or shortcut (defaults to '@myFolder').
            description (str): Optional folder description.
        """
        logger.info(f"--- TOOL USED: create_folder (name={name}, parent={parent_folder_id}) ---")
        token = await get_token(ctx)
        return await create_folder(name, token, parent_folder_id, description)

    @mcp.tool()
    async def create_project_tool(
        name: str,
        folder_id: str = "@myFolder",
        description: str = None,
        ctx: Context = None
    ) -> dict:
        """
        Creates a new IoT project under a folder.

        Args:
            name (str): Name of the project.
            folder_id (str): Folder ID to place the project in (defaults to '@myFolder').
            description (str): Optional project description.
        """
        logger.info(f"--- TOOL USED: create_project (name={name}, folder={folder_id}) ---")
        token = await get_token(ctx)
        return await create_project(name, token, folder_id, description)

    @mcp.tool()
    async def delete_folder_tool(folder_id: str, ctx: Context = None) -> str:
        """
        Deletes an existing folder by its ID or URI.

        Args:
            folder_id (str): The ID of the folder to delete.
        """
        logger.info(f"--- TOOL USED: delete_folder (folder_id={folder_id}) ---")
        token = await get_token(ctx)
        await delete_folder(folder_id, token)
        return f"Folder {folder_id} deleted successfully."

    @mcp.tool()
    async def delete_project_tool(project_id: str, ctx: Context = None) -> str:
        """
        Deletes an existing IoT project by its ID.

        Args:
            project_id (str): The ID of the project to delete.
        """
        logger.info(f"--- TOOL USED: delete_project (project_id={project_id}) ---")
        token = await get_token(ctx)
        await delete_project(project_id, token)
        return f"Project {project_id} deleted successfully."

    @mcp.tool()
    async def run_pareto_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "CLAIM.EVENT_STATUS_CD",
        report_var: str = "PRODUCT.MODEL_CD",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        max_by_var: int = 20,
        num_bars: int = 20,
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = False,
        usage_profile: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        value_var: str = "ACTUAL_VALUE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Pareto Analysis instance on product/claim data.
        Exposes all standard variables and parameters for Pareto analysis.

        Args:
            name (str): Unique name for the Pareto analysis.
            data_selection_id (str): ID of the launched data selection to analyze.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable (default: 'CLAIM.EVENT_STATUS_CD').
            report_var (str): Report by variable (default: 'PRODUCT.MODEL_CD').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            max_by_var (int): Max by variable count (default: 20).
            num_bars (int): Number of bars to display (default: 20).
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: False).
            usage_profile (bool): Usage profile flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            value_var (str): Value variable (default: 'ACTUAL_VALUE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_pareto_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "MAXBYVAR": max_by_var,
            "NUMBARS": num_bars,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "VALUEVAR": value_var,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="PARETO_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_trend_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "",
        report_var: str = "PRODUCT.PRODUCTION_MONTH",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        max_by_var: int = 20,
        calc_method: str = "ASIS",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = True,
        usage_profile: bool = False,
        control_charts: bool = True,
        control_limits_type: str = "SYSTEM",
        display_grid: bool = False,
        ucl: str = "",
        lcl: str = "",
        horiz_ref_value: bool = False,
        horiz_ref_label: bool = False,
        vert_ref_value: bool = False,
        vert_ref_label: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Trend & Control Analysis instance on product/claim data.
        Exposes all variables and parameters for Trend & Control analysis.

        Args:
            name (str): Unique name for the Trend analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable.
            report_var (str): Report by variable (default: 'PRODUCT.PRODUCTION_MONTH').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            max_by_var (int): Max by variable count (default: 20).
            calc_method (str): Calculation method (default: 'ASIS').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            control_charts (bool): Display control charts (default: True).
            control_limits_type (str): Control limits type (default: 'SYSTEM').
            display_grid (bool): Display chart grid (default: False).
            ucl (str): Upper control limit.
            lcl (str): Lower control limit.
            horiz_ref_value (bool): Horizontal reference value flag (default: False).
            horiz_ref_label (bool): Horizontal reference label flag (default: False).
            vert_ref_value (bool): Vertical reference value flag (default: False).
            vert_ref_label (bool): Vertical reference label flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_trend_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "MAXBYVAR": max_by_var,
            "CALCMETHOD": calc_method,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "CONTROLCHARTS": "TRUE" if control_charts else "FALSE",
            "CONTROLLIMITSTYPE": control_limits_type,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "UCL": ucl,
            "LCL": lcl,
            "HORIZREFVALUE": "TRUE" if horiz_ref_value else "FALSE",
            "HORIZREFLABEL": "TRUE" if horiz_ref_label else "FALSE",
            "VERTREFVALUE": "TRUE" if vert_ref_value else "FALSE",
            "VERTREFLABEL": "TRUE" if vert_ref_label else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TREND_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_trend_by_exposure_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "",
        report_var: str = "PRODUCT.PRODUCTION_MONTH",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        max_by_var: int = 20,
        calc_method: str = "ASIS",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = True,
        usage_profile: bool = False,
        control_charts: bool = True,
        control_limits_type: str = "SYSTEM",
        display_grid: bool = False,
        ucl: str = "",
        lcl: str = "",
        horiz_ref_value: bool = False,
        horiz_ref_label: bool = False,
        vert_ref_value: bool = False,
        vert_ref_label: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Trend by Exposure Analysis instance on product/claim data.

        Args:
            name (str): Unique name for the Trend by Exposure analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable.
            report_var (str): Report by variable (default: 'PRODUCT.PRODUCTION_MONTH').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            max_by_var (int): Max by variable count (default: 20).
            calc_method (str): Calculation method (default: 'ASIS').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            control_charts (bool): Display control charts (default: True).
            control_limits_type (str): Control limits type (default: 'SYSTEM').
            display_grid (bool): Display chart grid (default: False).
            ucl (str): Upper control limit.
            lcl (str): Lower control limit.
            horiz_ref_value (bool): Horizontal reference value flag (default: False).
            horiz_ref_label (bool): Horizontal reference label flag (default: False).
            vert_ref_value (bool): Vertical reference value flag (default: False).
            vert_ref_label (bool): Vertical reference label flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_trend_by_exposure_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "MAXBYVAR": max_by_var,
            "CALCMETHOD": calc_method,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "CONTROLCHARTS": "TRUE" if control_charts else "FALSE",
            "CONTROLLIMITSTYPE": control_limits_type,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "UCL": ucl,
            "LCL": lcl,
            "HORIZREFVALUE": "TRUE" if horiz_ref_value else "FALSE",
            "HORIZREFLABEL": "TRUE" if horiz_ref_label else "FALSE",
            "VERTREFVALUE": "TRUE" if vert_ref_value else "FALSE",
            "VERTREFLABEL": "TRUE" if vert_ref_label else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TRENDEXP_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_detail_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "",
        report_var: str = (
            "PRODUCT.PRODUCTION_DATE,PRODUCT.INSERVICE_DATE,"
            "PRODUCT.SELLING_DEALER_CD,CLAIM.USAGE,"
            "CLAIM.PRIM_LABOR_CD,CLAIM.PRIM_REPL_PART_CD"
        ),
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        comment_vars: str = "",
        min_num_comments: int = 25,
        num_similar_comments: str = "5 10 25 50",
        max_num_svd_dimensions: int = 50,
        find_similar_comments: bool = False,
        include_nc_products: bool = False,
        language: str = "english",
        run_on_transposed: str = "N",
        usage_type: str = "",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        display_type: str = "CODE",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Detail Analysis instance on product/claim data.
        Exposes all variables and parameters for Detail analysis.

        Args:
            name (str): Unique name for the Detail analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable.
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            comment_vars (str): Comment variables.
            min_num_comments (int): Min comments (default: 25).
            num_similar_comments (str): Num similar comments (default: '5 10 25 50').
            max_num_svd_dimensions (int): Max SVD dimensions (default: 50).
            find_similar_comments (bool): Find similar comments (default: False).
            include_nc_products (bool): Include non-conforming products (default: False).
            language (str): Comment analysis language (default: 'english').
            run_on_transposed (str): Run on transposed flag (default: 'N').
            usage_type (str): Usage measurement type.
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            display_type (str): Display type (default: 'CODE').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_detail_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "COMMENTVARS": comment_vars,
            "MINNUMCOMMENTS": min_num_comments,
            "NUMSIMILARCOMMENTS": num_similar_comments,
            "MAXNUMSVDDIMENSIONS": max_num_svd_dimensions,
            "FINDSIMILARCOMMENTS": "TRUE" if find_similar_comments else "FALSE",
            "INCLUDENCPRODUCTS": "TRUE" if include_nc_products else "FALSE",
            "LANGUAGE": language,
            "RUNONTRANSPOSED": run_on_transposed,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "DISPLAYTYPE": display_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="DETAIL_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )
    @mcp.tool()
    async def run_statistical_driver_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "",
        report_var: str = (
            "PRODUCT.SELLING_DEALER_COUNTRY_CD,PRODUCT.CSTMR_COUNTRY_CD,"
            "CLAIM.EVENT_TYPE_CD,CLAIM.EVENT_STATUS_CD"
        ),
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        alpha_level: float = 0.05,
        max_report_level: int = 500,
        area_of_opportunity_unit: int = 1,
        display_grid: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        display_type: str = "CODE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Statistical Drivers Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable.
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            alpha_level (float): Alpha significance level (default: 0.05).
            max_report_level (int): Max report level (default: 500).
            area_of_opportunity_unit (int): Area of opportunity unit (default: 1).
            display_grid (bool): Display grid lines (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            display_type (str): Display type (default: 'CODE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_statistical_driver_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "ALPHALEVEL": alpha_level,
            "MAXREPORTLEVEL": max_report_level,
            "AREAOFOPPORTUNITYUNIT": area_of_opportunity_unit,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "DISPLAYTYPE": display_type,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="STATDRIVER_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_decision_tree_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "",
        report_var: str = (
            "PRODUCT.SELLING_DEALER_COUNTRY_CD,PRODUCT.CSTMR_COUNTRY_CD,"
            "CLAIM.EVENT_TYPE_CD,CLAIM.EVENT_STATUS_CD"
        ),
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        max_branch: int = 2,
        max_depth: int = 5,
        leaf_size: float = 0.01,
        alpha_level: float = 0.05,
        min_num_obs: int = 10,
        max_report_level: int = 100,
        max_report_var: int = 25,
        area_of_opportunity_unit: int = 1,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = False,
        usage_profile: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        display_type: str = "CODE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Decision Tree Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable.
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            max_branch (int): Maximum branches (default: 2).
            max_depth (int): Maximum depth (default: 5).
            leaf_size (float): Leaf size proportion (default: 0.01).
            alpha_level (float): Alpha significance level (default: 0.05).
            min_num_obs (int): Minimum observations in leaf (default: 10).
            max_report_level (int): Maximum report level (default: 100).
            max_report_var (int): Maximum report variables (default: 25).
            area_of_opportunity_unit (int): Area of opportunity unit (default: 1).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: False).
            usage_profile (bool): Usage profile flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            display_type (str): Display type (default: 'CODE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_decision_tree_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "MAXBRANCH": max_branch,
            "MAXDEPTH": max_depth,
            "LEAFSIZE": leaf_size,
            "ALPHALEVEL": alpha_level,
            "MINNUMOBS": min_num_obs,
            "MAXREPORTLEVEL": max_report_level,
            "MAXREPORTVAR": max_report_var,
            "AREAOFOPPORTUNITYUNIT": area_of_opportunity_unit,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "DISPLAYTYPE": display_type,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="MULTIVARIATE_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_event_forecasting_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOUNT",
        by_var: str = "",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        forecast_periods: int = 0,
        forecast_interval: str = "MONTH",
        forecast_model_type: str = "RepeatEvent",
        forecast_model: str = "MCF",
        confidence: float = 0.95,
        wrty_time_length: int = 36,
        fore_wrty_length: str = "",
        fore_wrty_usage_mileage: str = "",
        fore_wrty_usage_hours: str = "",
        fore_wrty_usage_km: str = "",
        pct_pts: str = "95",
        sales_forecast_source: str = "",
        sales_forecast_calc: str = "",
        sales_forecast_alloc: str = "P",
        sales_forecast_n: int = 0,
        sales_forecast: str = "",
        seas_interval: str = "days10",
        seas_sle: float = 0.05,
        seas_sls: float = 0.05,
        seaseps: float = 1.0e-3,
        seasfreqs: int = 24,
        seasjmax: int = 15,
        seasmintime: int = 0,
        target_num_intervals: int = 1500,
        seasonal_nhpp: bool = False,
        include_model_eqn: bool = True,
        apply_war_date: str = "Y",
        apply_war_usage: str = "Y",
        censor_date_source: str = "D",
        censor_date: str = "",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        exposure_type: str = "TIS",
        max_by_var: int = 20,
        max_interval_size: int = 10,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs an Event Forecasting Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOUNT').
            by_var (str): Group by variable.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            forecast_periods (int): Forecast periods count (default: 0).
            forecast_interval (str): Forecast interval (default: 'MONTH').
            forecast_model_type (str): Forecast model type (default: 'RepeatEvent').
            forecast_model (str): Forecast model (default: 'MCF').
            confidence (float): Confidence level (default: 0.95).
            wrty_time_length (int): Warranty time length (default: 36).
            fore_wrty_length (str): Forecast warranty length.
            fore_wrty_usage_mileage (str): Forecast warranty max mileage.
            fore_wrty_usage_hours (str): Forecast warranty max hours.
            fore_wrty_usage_km (str): Forecast warranty max km.
            pct_pts (str): Percentile points (default: '95').
            sales_forecast_source (str): Sales forecast source.
            sales_forecast_calc (str): Sales forecast calculation method.
            sales_forecast_alloc (str): Sales forecast allocation (default: 'P').
            sales_forecast_n (int): Sales forecast N value.
            sales_forecast (str): Sales forecast.
            seas_interval (str): Seasonal interval (default: 'days10').
            seas_sle (float): Seasonal entry significance (default: 0.05).
            seas_sls (float): Seasonal stay significance (default: 0.05).
            seaseps (float): Seasonal convergence epsilon (default: 1.0e-3).
            seasfreqs (int): Seasonal frequency (default: 24).
            seasjmax (int): Seasonal JMax value (default: 15).
            seasmintime (int): Seasonal minimum time.
            target_num_intervals (int): Target intervals (default: 1500).
            seasonal_nhpp (bool): Seasonal NHPP model flag (default: False).
            include_model_eqn (bool): Include model equation flag (default: True).
            apply_war_date (str): Apply warranty date flag (default: 'Y').
            apply_war_usage (str): Apply warranty usage flag (default: 'Y').
            censor_date_source (str): Censor date source (default: 'D').
            censor_date (str): Censor date value.
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            exposure_type (str): Exposure type (default: 'TIS').
            max_by_var (int): Max by variable count (default: 20).
            max_interval_size (int): Max interval size (default: 10).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_event_forecasting_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "DATADOMAIN": data_domain,
            "FORECASTPERIODS": forecast_periods,
            "FORECAST_INTERVAL": forecast_interval,
            "FORECASTMODELTYPE": forecast_model_type,
            "FORECASTMODEL": forecast_model,
            "CONFIDENCE": confidence,
            "WRTYTIMELENGTH": wrty_time_length,
            "FOREWRTYLENGTH": fore_wrty_length,
            "FOREWRTYUSAGEMILEAGE": fore_wrty_usage_mileage,
            "FOREWRTYUSAGEHOURS": fore_wrty_usage_hours,
            "FOREWRTYUSAGEKM": fore_wrty_usage_km,
            "PCTLPTS": pct_pts,
            "SALESFORECASTSOURCE": sales_forecast_source,
            "SALESFORECASTCALC": sales_forecast_calc,
            "SALESFORECASTALLOC": sales_forecast_alloc,
            "SALESFORECASTN": sales_forecast_n,
            "SALESFORECAST": sales_forecast,
            "SEAS_INTERVAL": seas_interval,
            "SEAS_SLE": seas_sle,
            "SEAS_SLS": seas_sls,
            "SEASEPS": seaseps,
            "SEASFREQS": seasfreqs,
            "SEASJMAX": seasjmax,
            "SEASMINTIME": seasmintime,
            "TARGETNUMINTERVALS": target_num_intervals,
            "SEASONALNHPP": "TRUE" if seasonal_nhpp else "FALSE",
            "INCLUDEMODELEQN": "TRUE" if include_model_eqn else "FALSE",
            "APPLYWARDATE": apply_war_date,
            "APPLYWARUSAGE": apply_war_usage,
            "CENSORDATESOURCE": censor_date_source,
            "CENSORDATE": censor_date,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "EXPOSURETYPE": exposure_type,
            "MAXBYVAR": max_by_var,
            "MAXINTERVALSIZE": max_interval_size,
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="FORECASTING_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_summary_tables_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOUNT",
        report_var: str = "PRODUCT.MODEL_CD,PRODUCT.PRODUCTION_YEAR",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        subtotals: bool = True,
        use_exposure_type: bool = False,
        exposure_type: str = "TIS",
        tis_point_of_view: str = "frombuild",
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        find_exp_measurement: bool = True,
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        unique_value: bool = True,
        usage_profile: bool = False,
        usage_bins_to_display: str = "500,1000,1500,2000",
        tis_bins_to_display: str = "0,1,2,3,4,5,6",
        bin_increment: int = 0,
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        claim_submit_lag: bool = True,
        display_type: str = "CODE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Summary Tables (Crosstab) Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOUNT').
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            subtotals (bool): Display subtotals (default: True).
            use_exposure_type (bool): Use exposure type (default: False).
            exposure_type (str): Exposure type (default: 'TIS').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            find_exp_measurement (bool): Find exposure measurement (default: True).
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            usage_bins_to_display (str): Bins to display for usage.
            tis_bins_to_display (str): Bins to display for TIS.
            bin_increment (int): Bin increment size (default: 0).
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            claim_submit_lag (bool): Claim submit lag flag (default: True).
            display_type (str): Display type (default: 'CODE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_summary_tables_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "SUBTOTALS": "TRUE" if subtotals else "FALSE",
            "USEEXPOSURETYPE": "TRUE" if use_exposure_type else "FALSE",
            "EXPOSURETYPE": exposure_type,
            "TISPOINTOFVIEW": tis_point_of_view,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USAGEBINSTODISPLAY": usage_bins_to_display,
            "TISBINSTODISPLAY": tis_bins_to_display,
            "BININCREMENT": bin_increment,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "CLAIMSUBMITLAG": "TRUE" if claim_submit_lag else "FALSE",
            "DISPLAYTYPE": display_type,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="CROSSTAB_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_text_mining_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.TOTAL_EVENT_AMT",
        report_var: str = "PRODUCT.MODEL_CD,CLAIM.EVENT_STATUS_CD",
        text_var: str = "CLAIM.CSTMR_COMMENT",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        language: str = "Auto",
        custom_category: bool = True,
        num_topics: int = 10,
        num_terms: int = 10,
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Text Mining Analysis on product/claim comment data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.TOTAL_EVENT_AMT').
            report_var (str): Report by variables.
            text_var (str): Target text column containing comments (default: 'CLAIM.CSTMR_COMMENT').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            language (str): Comment language (default: 'Auto').
            custom_category (bool): Custom category analysis flag (default: True).
            num_topics (int): Number of topics to discover (default: 10).
            num_terms (int): Number of terms per topic to return (default: 10).
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_text_mining_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "TEXTVAR": text_var,
            "DATADOMAIN": data_domain,
            "LANGUAGE": language,
            "CUSTOM_CATEGORY": "TRUE" if custom_category else "FALSE",
            "NUMTOPICS": num_topics,
            "NUMTERMS": num_terms,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TEXTANALYSIS_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_exposure_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exposure_type: str = "TIS",
        tis_point_of_view: str = "frombuild",
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        find_exp_measurement: bool = True,
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "Y",
        unique_value: bool = True,
        usage_profile: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        claim_submit_lag: bool = True,
        display_type: str = "CODE",
        display_grid: bool = False,
        bin_increment: int = 0,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs an Exposure Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exposure_type (str): Exposure type (default: 'TIS').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            find_exp_measurement (bool): Find exposure measurement (default: True).
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'Y').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            claim_submit_lag (bool): Claim submit lag flag (default: True).
            display_type (str): Display type (default: 'CODE').
            display_grid (bool): Display grid lines (default: False).
            bin_increment (int): Bin increment size (default: 0).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_exposure_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "DATADOMAIN": data_domain,
            "EXPOSURETYPE": exposure_type,
            "TISPOINTOFVIEW": tis_point_of_view,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "CLAIMSUBMITLAG": "TRUE" if claim_submit_lag else "FALSE",
            "DISPLAYTYPE": display_type,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "BININCREMENT": bin_increment,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="EXPOSURE_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_failure_relationships_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "PART.REPL_PART_AMT",
        report_var: str = "PART.REPL_PART_CD",
        data_domain: str = "PRODUCT,CLAIM,PART",
        rv_dim_column: str = "PART.REPL_PART_CD",
        threshold_slider_variable: str = "CONF",
        xvar1: str = "iotIncr",
        dmdb_max_lev: int = 100001,
        chart_scaling_factor: int = 400,
        node_tip: str = "CODE",
        node_size: str = "UNIFORM",
        bin_increment: int = 500,
        rv_table_name_key: str = "PART.REPL_PART_CD",
        rv_table_name_value: str = "PART.REPL_PART_CD",
        rv_table_name: str = "PART.REPL_PART_CD",
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        link_tip: str = "DESC",
        link_value_variable: str = "conf",
        link_width: str = "UNIFORM",
        link_width_variable: str = "count",
        max_link_number: int = 2000,
        max_link_width: int = 3,
        max_node_number: int = 300,
        min_items: int = 2,
        nodesize_variable: str = "count",
        min_conf_passoc: float = 1.0,
        bin_length: int = 30,
        onetrvruledsflag: int = 0,
        pseudoliftincludeflag: str = "N",
        sas_file: int = 1,
        seq_proc_threshold: int = 301,
        show_immature_exposure: str = "N",
        threshold_slider_scale_type: str = "PERCENTILE",
        assoc_table_threshold: int = 100,
        trule_end_start_flag: str = "ALL",
        uniform_link_width: int = 1,
        rule_type: str = "TYPE4",
        perform_repeat_repair: bool = False,
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        max_inter_oc_time: int = 3,
        min_conf_p: str = "",
        min_lift: str = "",
        min_cost: int = 15000,
        no_rules_to_display: str = "",
        yvar2: str = "CONF",
        yvar1: str = "SUPPORT",
        xvar2: str = "iotIncr",
        rule_filter_criteria: str = "support",
        tis_point_of_view: str = "frombuild",
        apply_int_oc_time_incr: bool = False,
        apply_rule_st_criteria: bool = True,
        min_support_type: str = "percent",
        rule_size: str = "1-1,1-2,2-1,2-2",
        min_support_p: float = 0.01,
        min_support_c: int = 1,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Failure Relationships Analysis on product/claim/part data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'PART.REPL_PART_AMT').
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,PART').
            rv_dim_column (str): RV dimension column.
            threshold_slider_variable (str): Threshold slider variable.
            xvar1 (str): X variable 1 (default: 'iotIncr').
            dmdb_max_lev (int): DMDB maximum level (default: 100001).
            chart_scaling_factor (int): Chart scaling factor (default: 400).
            node_tip (str): Node tooltip display type (default: 'CODE').
            node_size (str): Node sizing logic (default: 'UNIFORM').
            bin_increment (int): Bin increment size (default: 500).
            rv_table_name_key (str): RV table name key.
            rv_table_name_value (str): RV table name value.
            rv_table_name (str): RV table name.
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            link_tip (str): Link tooltip type (default: 'DESC').
            link_value_variable (str): Link value variable.
            link_width (str): Link width (default: 'UNIFORM').
            link_width_variable (str): Link width variable (default: 'count').
            max_link_number (int): Maximum links (default: 2000).
            max_link_width (int): Maximum link width (default: 3).
            max_node_number (int): Maximum nodes (default: 300).
            min_items (int): Minimum items in association rules (default: 2).
            nodesize_variable (str): Node sizing variable (default: 'count').
            min_conf_passoc (float): Minimum confidence passoc (default: 1.0).
            bin_length (int): Bin length (default: 30).
            onetrvruledsflag (int): One transaction rule dataset flag (default: 0).
            pseudoliftincludeflag (str): Include pseudo lift flag (default: 'N').
            sas_file (int): SAS file number (default: 1).
            seq_proc_threshold (int): Sequence process threshold (default: 301).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            threshold_slider_scale_type (str): Scale type (default: 'PERCENTILE').
            assoc_table_threshold (int): Association table threshold (default: 100).
            trule_end_start_flag (str): Rule start/end flag (default: 'ALL').
            uniform_link_width (int): Uniform link width (default: 1).
            rule_type (str): Association rule type (default: 'TYPE4').
            perform_repeat_repair (bool): Perform repeat repair analysis (default: False).
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            max_inter_oc_time (int): Maximum inter-event occurrence time.
            min_conf_p (str): Minimum confidence percentage.
            min_lift (str): Minimum lift.
            min_cost (int): Minimum cost limit (default: 15000).
            no_rules_to_display (str): Number of rules to display.
            yvar2 (str): Y variable 2 (default: 'CONF').
            yvar1 (str): Y variable 1 (default: 'SUPPORT').
            xvar2 (str): X variable 2 (default: 'iotIncr').
            rule_filter_criteria (str): Rule filtering criteria (default: 'support').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            apply_int_oc_time_incr (bool): Apply interval time increment.
            apply_rule_st_criteria (bool): Apply rule constraint criteria (default: True).
            min_support_type (str): Minimum support type (default: 'percent').
            rule_size (str): Rule size filter (default: '1-1,1-2,2-1,2-2').
            min_support_p (float): Minimum support percentage (default: 0.01).
            min_support_c (int): Minimum support count (default: 1).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_failure_relationships_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "RVDIMCOLUMN": rv_dim_column,
            "THRESHOLDSLIDERVARIABLE": threshold_slider_variable,
            "XVAR1": xvar1,
            "DMDBMAXLEV": dmdb_max_lev,
            "CHARTSCALINGFACTOR": chart_scaling_factor,
            "NODETIP": node_tip,
            "NODESIZE": node_size,
            "BININCREMENT": bin_increment,
            "RVTABLEVALUE": rv_table_name_value,
            "RVTABLENAMEKEY": rv_table_name_key,
            "RVTABLENAMEVALUE": rv_table_name_value,
            "RVTABLENAME": rv_table_name,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "LINKTIP": link_tip,
            "LINKVALUEVARIABLE": link_value_variable,
            "LINKWIDTH": link_width,
            "LINKWIDTHVARIABLE": link_width_variable,
            "MAXLINKNUMBER": max_link_number,
            "MAXLINKWIDTH": max_link_width,
            "MAXNODENUMBER": max_node_number,
            "MINITEMS": min_items,
            "NODESIZEVARIABLE": nodesize_variable,
            "MINCONFPASSOC": min_conf_passoc,
            "BINLENGTH": bin_length,
            "ONETRVRULEDSFLAG": onetrvruledsflag,
            "PSEUDOLIFTINCLUDEFLAG": pseudoliftincludeflag,
            "SASFILE": sas_file,
            "SEQPROCTHRESHOLD": seq_proc_threshold,
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "THRESHOLDSLIDERSCALETYPE": threshold_slider_scale_type,
            "ASSOCTABLETHRESHOLD": assoc_table_threshold,
            "TRULEENDSTARTFLAG": trule_end_start_flag,
            "UNIFORMLINKWIDTH": uniform_link_width,
            "RULETYPE": rule_type,
            "PERFORMREPEATREPAIR": "TRUE" if perform_repeat_repair else "FALSE",
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MAXINTEROCTIME": max_inter_oc_time,
            "MINCONFP": min_conf_p,
            "MINLIFT": min_lift,
            "MINCOST": min_cost,
            "NORULESTODISPLAY": no_rules_to_display,
            "YVAR2": yvar2,
            "YVAR1": yvar1,
            "XVAR2": xvar2,
            "RULEFILTERCRITERIA": rule_filter_criteria,
            "TISPOINTOFVIEW": tis_point_of_view,
            "APPLYINTOCTIMEINCR": "TRUE" if apply_int_oc_time_incr else "FALSE",
            "APPLYRULESTCRITERIA": "TRUE" if apply_rule_st_criteria else "FALSE",
            "MINSUPPORTTYPE": min_support_type,
            "RULESIZE": rule_size,
            "MINSUPPORTP": min_support_p,
            "MINSUPPORTC": min_support_c,
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="FAILREL_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_geographic_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOST",
        report_var: str = "PRODUCT.SELLING_DEALER_COUNTRY_CD",
        color_var: str = "CLAIM.CLAIMCOUNT",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exposure_type: str = "TIS",
        tis_point_of_view: str = "frombuild",
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        find_exp_measurement: bool = True,
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        unique_value: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        claim_submit_lag: bool = True,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Geographic Analysis on product/claim geographic data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            report_var (str): Report by variables.
            color_var (str): Variable to determine map region colors.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exposure_type (str): Exposure type (default: 'TIS').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            find_exp_measurement (bool): Find exposure measurement (default: True).
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            unique_value (bool): Force unique value (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            claim_submit_lag (bool): Claim submit lag flag (default: True).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_geographic_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "COLORVAR": color_var,
            "DATADOMAIN": data_domain,
            "EXPOSURETYPE": exposure_type,
            "TISPOINTOFVIEW": tis_point_of_view,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "CLAIMSUBMITLAG": "TRUE" if claim_submit_lag else "FALSE",
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="GEOGRAPHIC_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_time_of_event_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "CLAIM.CLAIMCOST",
        report_var: str = "CLAIM.EVENT_PAID_MONTH",
        by_var: str = "",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        exp_measurement_type: int = 1,
        unique_value: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        wrty_time_length: int = 12,
        usage_profile: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        horiz_ref_value: bool = False,
        horiz_ref_label: bool = False,
        vert_ref_value: bool = False,
        vert_ref_label: bool = False,
        display_grid: bool = False,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Time of Event (Time of Claim) Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            report_var (str): Report by variables.
            by_var (str): Group by variable.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            exp_measurement_type (int): Exposure measurement type (default: 1).
            unique_value (bool): Force unique value (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            wrty_time_length (int): Warranty time length (default: 12).
            usage_profile (bool): Usage profile flag (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            horiz_ref_value (bool): Horizontal reference value flag (default: False).
            horiz_ref_label (bool): Horizontal reference label flag (default: False).
            vert_ref_value (bool): Vertical reference value flag (default: False).
            vert_ref_label (bool): Vertical reference label flag (default: False).
            display_grid (bool): Display grid lines (default: False).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_time_of_event_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "BYVAR": by_var,
            "DATADOMAIN": data_domain,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "WRTYTIMELENGTH": wrty_time_length,
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "HORIZREFVALUE": "TRUE" if horiz_ref_value else "FALSE",
            "HORIZREFLABEL": "TRUE" if horiz_ref_label else "FALSE",
            "VERTREFVALUE": "TRUE" if vert_ref_value else "FALSE",
            "VERTREFLABEL": "TRUE" if vert_ref_label else "FALSE",
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TIMEOFCLAIM_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_reliability_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
        analysis_var: str = "RELIABILITYCLAIMCOUNT",
        report_var: str = "",
        by_var: str = "",
        reliab_var: str = "TIS",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exp_chart_type: str = "INCREMENTAL",
        projected_values_hours: str = "100,200,300,400,500,600,700,800,900,1000",
        confidence: float = 0.95,
        bin_increment: int = 500,
        display_grid: bool = False,
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_exp_measurement: bool = False,
        show_immature_exposure: str = "N",
        seas_sale_lag: bool = False,
        max_by_var: int = 20,
        find_first_fail_flag: bool = True,
        wrty_usage_max_km: str = "",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Reliability Analysis on product/claim reliability data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'RELIABILITYCLAIMCOUNT').
            report_var (str): Report by variables.
            by_var (str): Group by variable.
            reliab_var (str): Reliability variable (default: 'TIS').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exp_chart_type (str): Exposure chart type (default: 'INCREMENTAL').
            projected_values_hours (str): Projected values hours list.
            confidence (float): Confidence level (default: 0.95).
            bin_increment (int): Bin increment size (default: 500).
            display_grid (bool): Display grid lines (default: False).
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_exp_measurement (bool): Find exposure measurement (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            seas_sale_lag (bool): Seasonal sale lag (default: False).
            max_by_var (int): Max by variable count (default: 20).
            find_first_fail_flag (bool): Find first fail flag (default: True).
            wrty_usage_max_km (str): Warranty max km.
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info(f"--- TOOL USED: run_reliability_analysis ({name}) ---")
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "BYVAR": by_var,
            "RELIABVAR": reliab_var,
            "DATADOMAIN": data_domain,
            "EXPCHARTTYPE": exp_chart_type,
            "PROJECTEDVALUESHOURS": projected_values_hours,
            "CONFIDENCE": confidence,
            "BININCREMENT": bin_increment,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "SEASSALELAG": "TRUE" if seas_sale_lag else "FALSE",
            "MAXBYVAR": max_by_var,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="RELIABILITY_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def drop_table_from_memory(
        caslib_name: str, table_name: str, ctx: Context
    ) -> dict[str, Any]:
        """Drop a CAS table from memory in the specified caslib.

        Drops both session-scope and global-scope versions of the table from CAS memory,
        which is useful for cleaning up temporary tables or freeing up RAM.

        Args:
            caslib_name: The name of the caslib.
            table_name: The table to drop.
        """
        logger.info(f"--- TOOL USED: drop_table_from_memory ({caslib_name}.{table_name}) ---")
        token = await get_token(ctx)
        code = f"""
        cas mySession;
        proc cas;
          table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
        quit;
        """
        res = await run_one_snippet(code, "drop_table", token)
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": f"Table {caslib_name}.{table_name} dropped from CAS memory."
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to drop table. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def reload_table_to_memory(
        caslib_name: str, table_name: str, ctx: Context
    ) -> dict[str, Any]:
        """Cleanly reload a table from its caslib data source and promote it to global scope.

        Drops any existing session/global scope instances of the table from memory,
        finds its source file (e.g. sashdat) dynamically, and reloads/promotes it to global scope.
        This is highly useful for restoring a clean CAS environment after table corruption or unloading.

        Args:
            caslib_name: The name of the caslib.
            table_name: The table to reload.
        """
        logger.info(f"--- TOOL USED: reload_table_to_memory ({caslib_name}.{table_name}) ---")
        token = await get_token(ctx)
        code = f"""
        cas mySession;
        proc cas;
          table.fileInfo r=f / caslib="{caslib_name}";
          src_file = "";
          do row over f.FileInfo;
            if (upcase(scan(row.Name, 1, '.')) == upcase("{table_name}")) then do;
              src_file = row.Name;
            end;
          end;
          if (src_file == "") then src_file = "{table_name}.sashdat";
          
          table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
          table.loadTable / 
            caslib="{caslib_name}" 
            path=src_file 
            casout={{caslib="{caslib_name}" name="{table_name}" promote=true}};
        quit;
        """
        res = await run_one_snippet(code, "reload_table", token)
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": f"Table {caslib_name}.{table_name} successfully reloaded and promoted in CAS."
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to reload table. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def reload_fqa_metadata_tool(
        fqa_base_path: str,
        ctx: Context
    ) -> dict[str, Any]:
        """
        Reloads the FQA metadata configuration (e.g., column_parameters.csv, analysis_param.csv) 
        into the SAS Analytics for IoT Postgres database without reloading the underlying CAS data.
        This is useful after modifying FQA configuration files.
        Note: This tool may take several minutes to run and could exceed standard tool timeouts, 
        but it will successfully trigger the load in the background.
        
        Args:
            fqa_base_path (str): The absolute Linux path on the CAS server where the FQA Demo_Data_transformed directory resides 
                                 (e.g., "/export/sas-viya/homes/germsz/AIoT/FQA/Demo_Data_transformed").
        """
        logger.info(f"--- TOOL USED: reload_fqa_metadata_tool ({fqa_base_path}) ---")
        token = await get_token(ctx)
        
        code = f"""
        /* Ensure etl=N so we don't wipe data and only load config */
        data _null_;
          infile '{fqa_base_path}/Load_Demo_Data_params.txt' truncover;
          file '{fqa_base_path}/Load_Demo_Data_params.tmp';
          input line $32767.;
          if index(line, 'etl=Y') > 0 or index(line, 'etl = Y') > 0 then line = 'etl=N';
          put line;
        run;

        data _null_;
          infile '{fqa_base_path}/Load_Demo_Data_params.tmp' truncover;
          file '{fqa_base_path}/Load_Demo_Data_params.txt';
          input line $32767.;
          put line;
        run;

        /* Execute the dataload macro */
        %include '{fqa_base_path}/Load_Demo_Data.sas';
        """
        
        res = await run_one_snippet(code, "reload_fqa_metadata", token)
        
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": "FQA Metadata configuration successfully reloaded.",
                "log": res.get("log")
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to reload FQA metadata. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def remediate_high_cardinality_tool(
        caslib_name: str,
        table_name: str,
        column_name: str,
        strategy: str,
        ctx: Context,
        target_column: str | None = None,
    ) -> dict[str, Any]:
        """Remediates high-cardinality columns in a CAS table to make them suitable for standard analyses.

        Supports three strategies:
        - 'binning': Groups the top 10 values by frequency and bins the rest as -99 ('OTHER').
        - 'temporal': Extracts Year-Month and relative age offsets (requires target_column representing inservice_date).
        - 'target_encoding': Calculates target encoding using the mean of target_column.

        Args:
            caslib_name: Name of the caslib containing the table.
            table_name: Name of the CAS table.
            column_name: Name of the high-cardinality column to remediate.
            strategy: Remediation strategy ('binning', 'temporal', or 'target_encoding').
            target_column: Name of the target variable for target encoding or target inservice_date for temporal.
        """
        logger.info(f"--- TOOL USED: remediate_high_cardinality ({caslib_name}.{table_name}.{column_name}) ---")
        token = await get_token(ctx)
        
        column_name = column_name.upper()
        table_name = table_name.upper()
        caslib_name = caslib_name.upper()
        if target_column:
            target_column = target_column.upper()
            
        strategy = strategy.lower()
        if strategy not in ["binning", "temporal", "target_encoding"]:
            return {
                "status": "failed",
                "message": f"Unsupported strategy '{strategy}'. Use 'binning', 'temporal', or 'target_encoding'."
            }
            
        code = f"""
        cas mySession;
        libname mycas CAS sessref=mySession caslib="{caslib_name}";
        """
        
        new_col = ""
        new_desc = ""
        new_label = ""
        new_type = 3
        
        if strategy == "binning":
            new_col = f"{column_name}_BINNED"
            new_desc = f"Binned {column_name} (Top 10 + Other)"
            new_label = f"Binned {column_name}"
            new_type = 3
            
            code += f"""
            proc freq data=mycas.{table_name} order=freq;
                tables {column_name} / out=work.freq_out;
            run;
            
            data mycas.freq_out_top10;
                set work.freq_out(obs=10);
            run;
            
            proc fedsql sessref=mySession;
                create table {caslib_name}.{table_name}_new as
                select t1.*, 
                       case when t2.{column_name} is not null then t1.{column_name}
                            else -99
                       end as {new_col}
                from {caslib_name}.{table_name} as t1
                left join {caslib_name}.freq_out_top10 as t2
                on t1.{column_name} = t2.{column_name};
            quit;
            
            proc cas;
                table.dropTable / caslib="{caslib_name}" name="freq_out_top10" quiet=true;
                table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
                table.promote / caslib="{caslib_name}" name="{table_name}_new" target="{table_name}";
            quit;
            """
            
        elif strategy == "temporal":
            if not target_column:
                return {
                    "status": "failed",
                    "message": "Strategy 'temporal' requires 'target_column' (the inservice_date column name)."
                }
            new_col = f"{column_name}_AGE_MONTHS"
            new_desc = f"Age in Months from {target_column} to {column_name}"
            new_label = "Age in Months"
            new_type = 4
            
            code += f"""
            data mycas.{table_name}_new(promote=yes);
                set mycas.{table_name};
                length {new_col} 8;
                if {column_name} ne . and {target_column} ne . then do;
                    {new_col} = ({column_name} - {target_column}) / 30.4375;
                end;
                else do;
                    {new_col} = .;
                end;
            run;
            
            proc cas;
                table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
                table.promote / caslib="{caslib_name}" name="{table_name}_new" target="{table_name}";
            quit;
            """
            
        elif strategy == "target_encoding":
            if not target_column:
                return {
                    "status": "failed",
                    "message": "Strategy 'target_encoding' requires 'target_column' (the dependent/target variable)."
                }
            new_col = f"{column_name}_TE"
            new_desc = f"Target encoded {column_name} against {target_column}"
            new_label = f"Target encoded {column_name}"
            new_type = 4
            
            code += f"""
            proc summary data=mycas.{table_name} nway;
                class {column_name};
                var {target_column};
                output out=work.te_lookup(drop=_type_ _freq_) mean=te_val;
            run;
            
            data mycas.te_lookup;
                set work.te_lookup;
            run;
            
            proc fedsql sessref=mySession;
                create table {caslib_name}.{table_name}_new as
                select t1.*, coalesce(t2.te_val, 0) as {new_col}
                from {caslib_name}.{table_name} as t1
                left join {caslib_name}.te_lookup as t2
                on t1.{column_name} = t2.{column_name};
            quit;
            
            proc cas;
                table.dropTable / caslib="{caslib_name}" name="te_lookup" quiet=true;
                table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
                table.promote / caslib="{caslib_name}" name="{table_name}_new" target="{table_name}";
            quit;
            """

        code += f"""
        libname metapg CAS caslib="AIoTPgMeta" sessref=mySession;
        %macro update_metadata;
            %if %sysfunc(exist(metapg.TABLECOLUMN_META_PG)) and
                %sysfunc(exist(metapg.TABLECOLUMN_ATTRIBUTES_PG))
                %then %do;
                
                /* 1. Copy promoted tables to local WORK tables */
                data work.table_meta_temp;
                    set metapg.TABLECOLUMN_META_PG;
                run;
                data work.table_attr_temp;
                    set metapg.TABLECOLUMN_ATTRIBUTES_PG;
                run;
                
                /* 2. Perform deletes and inserts on local WORK tables */
                proc sql;
                    delete from work.table_meta_temp where column_id = "{new_col}_F999";
                    insert into work.table_meta_temp
                    (column_id, column_nm, table_id, column_data_type_cd,
                     column_desc, column_label_txt, solution_cd, column_fmt_nm)
                    values ("{new_col}_F999", "{new_col}", "{table_name}",
                            {new_type}, "{new_desc}", "{new_label}", "FQA", "");
                    
                    delete from work.table_attr_temp where column_id = "{new_col}_F999";
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values ("{new_col}_F999_RV", "{new_col}_F999", "REQVAR", "Y", 2);
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values (
                        "{new_col}_F999_AV", 
                        "{new_col}_F999", 
                        "REPORTVAR", 
                        "CROSSTAB,DETAIL,MULTIVARIATE,PARETO,STATDRIVER,TEXTANALYSIS", 
                        2
                    );
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values ("{new_col}_F999_FT", "{new_col}_F999", "FACT_TABLE", "{table_name}", 2);
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values ("{new_col}_F999_FC", "{new_col}_F999", "FACT_COLUMN", "{new_col}", 2);
                quit;
                
                /* 3. Upload modified WORK tables to CAS session-scope */
                data metapg.TABLECOLUMN_META_PG_new;
                    set work.table_meta_temp;
                run;
                data metapg.TABLECOLUMN_ATTRIBUTES_PG_new;
                    set work.table_attr_temp;
                run;
                
                /* 4. Drop old promoted tables and promote new ones */
                proc cas;
                    table.dropTable / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_META_PG" 
                        quiet=true;
                    table.dropTable / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_ATTRIBUTES_PG" 
                        quiet=true;
                    table.promote / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_META_PG_new" 
                        target="TABLECOLUMN_META_PG";
                    table.promote / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_ATTRIBUTES_PG_new" 
                        target="TABLECOLUMN_ATTRIBUTES_PG";
                quit;
            %end;
        %mend update_metadata;
        %update_metadata;
        """
        
        res = await run_one_snippet(code, "remediate", token)
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": (
                    f"Successfully remediated column {column_name} in "
                    f"{caslib_name}.{table_name} using strategy "
                    f"'{strategy}'. Created column {new_col}."
                ),
                "log": res.get("log")[:1000]
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to remediate column. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def create_child_data_selection_and_launch_tool(
        parent_data_selection_id: str,
        new_name: str,
        new_filters: list[dict],
        parent_analysis_id: str,
        ctx: Context,
        folder_id: str | None = None,
    ) -> dict[str, Any]:
        """Creates a child data selection from a parent data selection with new filters and parent links, and launches it in CAS.

        Args:
            parent_data_selection_id (str): The ID of the parent data selection to copy.
            new_name (str): Name for the new child data selection.
            new_filters (list[dict]): List of additional filter criteria to append.
            parent_analysis_id (str): The ID of the parent Decision Tree or analysis to link this child to.
            folder_id (str, optional): The ID of the project folder to add this data selection to.
        """
        import uuid
        async with viya_session("create_child_data_selection_and_launch", ctx) as client:
            logger.info(f"Copying parent data selection {parent_data_selection_id} to '{new_name}'")
            copy_url = f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{parent_data_selection_id}/copies?name={new_name}"
            resp_copy = await client.post(copy_url)
            resp_copy.raise_for_status()
            new_ds = resp_copy.json()
            new_ds_id = new_ds["id"]
            
            resp_get = await client.get(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}",
                headers={"Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_get.raise_for_status()
            ds_details = resp_get.json()
            etag = resp_get.headers.get("ETag", "")
            
            filter_criteria = ds_details.get("filterCriteria", {})
            group_0 = filter_criteria.get("0", [])
            
            for f in new_filters:
                new_f = {
                    "id": str(uuid.uuid4()),
                    "criteriaGroupId": new_ds_id,
                    "columnName": f.get("columnName"),
                    "operatorCode": f.get("operatorCode", "IN"),
                    "excludeFlag": f.get("excludeFlag", False),
                    "componentTypeCode": f.get("componentTypeCode", f.get("component", "PRODUCT")),
                    "component": f.get("component", "PRODUCT"),
                    "filterAttributeId": f.get("filterAttributeId", f"{f.get('columnName')}_{f.get('component', 'PRODUCT')}"),
                    "groupId": "0",
                    "uiDisplay": False,
                    "values": f.get("values", [])
                }
                group_0.append(new_f)
            
            ds_details["filterCriteria"] = {"0": group_0}
            ds_details["additionalAttributes"] = [
                {"name": "parentAnalysisId", "value": parent_analysis_id},
                {"name": "PARENT_ANALYSIS_ID", "value": parent_analysis_id}
            ]
            
            headers_put = {
                "Content-Type": "application/vnd.sas.data.selection+json",
                "Accept": "application/vnd.sas.data.selection+json",
                "If-Match": etag
            }
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}",
                json=ds_details,
                headers=headers_put
            )
            resp_put.raise_for_status()
            
            cols = [
                {"columnName": "PRODUCTION_DATE", "columnNameLabel": "Production Date", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnNameLabel": "Selling Dealer Country", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "MODEL_CD", "columnNameLabel": "Model Code", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_CD", "columnNameLabel": "Selling Dealer Code", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "INSERVICE_DATE", "columnNameLabel": "In Service Date", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "CSTMR_STATE_CD", "columnNameLabel": "Customer State", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "PRIM_REPL_PART_CD", "columnNameLabel": "Primary Part Code", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "CLAIMCOST", "columnNameLabel": "Total Claim Cost", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "PRIM_LABOR_CD", "columnNameLabel": "Primary Labor Code", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "EVENT_SUBMIT_DATE", "columnNameLabel": "Claim Submit Date", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "REPL_PART_CD", "columnNameLabel": "Replaced Part Code", "columnTableName": "PART", "columnTableNameLabel": "Parts"}
            ]
            
            launch_body = {
                "tableName": f"DS_{new_ds_id.replace('-', '_')[:24]}",
                "launchAppName": "CAS",
                "transposeFlag": 0,
                "launchKeyDim": "PRODUCT",
                "launchColumnTables": ["CLAIM", "PART", "PRODUCT"],
                "launchColumns": cols
            }
            
            resp_launch = await client.post(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches",
                json=launch_body,
                headers={
                    "Content-Type": "application/vnd.sas.data.selection.launch+json",
                    "Accept": "application/vnd.sas.data.selection.launch+json"
                }
            )
            resp_launch.raise_for_status()
            launch_id = resp_launch.json()["id"]
            
            import asyncio
            while True:
                resp_status = await client.get(
                    f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches/{launch_id}",
                    headers={"Accept": "application/vnd.sas.data.selection.launch+json"}
                )
                launch_status = resp_status.json().get("status", "")
                if launch_status == "COMPLETED":
                    break
                elif launch_status in ("FAILED", "ERROR"):
                    raise RuntimeError(f"Data selection launch failed with status {launch_status}")
                await asyncio.sleep(5)
                
            if folder_id:
                member_body = {
                    "name": new_name,
                    "uri": f"/dataSelection/dataSelections/{new_ds_id}",
                    "contentType": "application/vnd.sas.data.selection",
                    "type": "reference"
                }
                await client.post(
                    f"{VIYA_ENDPOINT}/folders/folders/{folder_id}/members",
                    json=member_body,
                    headers={
                        "Content-Type": "application/vnd.sas.drive.member+json",
                        "Accept": "application/vnd.sas.drive.member+json"
                    }
                )
            
            return {
                "status": "success",
                "data_selection_id": new_ds_id,
                "launch_id": launch_id,
                "message": f"Successfully created and launched child data selection '{new_name}' (ID: {new_ds_id})"
            }

    @mcp.tool()
    async def create_child_analysis_and_run_tool(
        name: str,
        model_name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str | None = None,
        parameter_overrides: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Creates a child analysis instance, configures step parameters with overrides, runs the job, and links it in a project folder.

        Args:
            name (str): The name for the new analysis instance.
            model_name (str): The type of analysis model (e.g. `DETAIL_PRODUCT`, `PARETO_PRODUCT`).
            data_selection_id (str): The ID of the data selection to run the analysis on.
            folder_id (str, optional): The ID of the project folder to add this analysis to.
            parameter_overrides (dict, optional): Parameter overrides to update in the analysis step.
        """
        async with viya_session("create_child_analysis_and_run", ctx) as client:
            logger.info(f"Creating new analysis '{name}' on data selection {data_selection_id}")
            analysis_body = {
                "name": name,
                "modelName": model_name,
                "dataSelectionId": data_selection_id
            }
            if folder_id:
                analysis_body["folderID"] = folder_id
                
            collection_body = {
                "name": "analysis",
                "items": [analysis_body]
            }
            
            resp_create = await client.post(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses",
                json=collection_body,
                headers={"Accept": "application/json", "Content-Type": "application/json"}
            )
            resp_create.raise_for_status()
            created_analysis = resp_create.json()["items"][0]
            analysis_id = created_analysis["id"]
            
            resp_full = await client.get(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}",
                headers={"Accept": "application/vnd.sas.iot.analysis+json"}
            )
            resp_full.raise_for_status()
            full_analysis = resp_full.json()
            analysis_etag = resp_full.headers.get("ETag", "")
            
            steps = full_analysis.get("steps", [])
            if not steps:
                raise RuntimeError("No steps found in the created analysis details")
            step = steps[0]
            step_id = step["id"]
            
            if parameter_overrides:
                params = step.get("inputParameters", [])
                for p in params:
                    pname = p.get("parameterName")
                    if pname in parameter_overrides:
                        p["parameterValue"] = parameter_overrides[pname]
                step["inputParameters"] = params
                full_analysis["steps"] = [step]
                
                resp_put = await client.put(
                    f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}",
                    json=full_analysis,
                    headers={
                        "Content-Type": "application/vnd.sas.iot.analysis+json",
                        "Accept": "application/vnd.sas.iot.analysis+json",
                        "If-Match": analysis_etag
                    }
                )
                resp_put.raise_for_status()
                
            logger.info("Submitting step run job...")
            resp_run = await client.post(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs",
                headers={"Accept": "application/json"}
            )
            resp_run.raise_for_status()
            job_link = resp_run.json()["links"][0]["href"]
            
            import asyncio
            while True:
                resp_job = await client.get(f"{VIYA_ENDPOINT}{job_link}")
                job_status = resp_job.json().get("state", "")
                if job_status == "completed":
                    break
                elif job_status in ("failed", "error", "canceled"):
                    try:
                        log_resp = await client.get(f"{VIYA_ENDPOINT}{job_link}/log?limit=1000")
                        log_lines = [item.get("line") for item in log_resp.json().get("items", [])]
                        logger.error(f"Job log output:\n" + "\n".join(log_lines))
                    except Exception:
                        pass
                    raise RuntimeError(f"Analysis job failed with status {job_status}")
                await asyncio.sleep(5)
                
            if folder_id:
                member_body = {
                    "name": name,
                    "uri": f"/iotAnalysis/analyses/{analysis_id}",
                    "contentType": "application/vnd.sas.iot.analysis",
                    "type": "reference"
                }
                await client.post(
                    f"{VIYA_ENDPOINT}/folders/folders/{folder_id}/members",
                    json=member_body,
                    headers={
                        "Content-Type": "application/vnd.sas.drive.member+json",
                        "Accept": "application/vnd.sas.drive.member+json"
                    }
                )
                
            return {
                "status": "success",
                "analysis_id": analysis_id,
                "step_id": step_id,
                "message": f"Successfully created and ran child analysis '{name}' (ID: {analysis_id})"
            }





    # ------------------------------------------------------------------
    # Visual Forecasting Tools
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_forecasting_data_definitions(limit: int = 10, start: int = 0, ctx: Context = None) -> dict:
        """List Visual Forecasting data definitions."""
        async with viya_session("list_forecasting_data_definitions", ctx) as client:
            return await get_paged_items(client, "/dataDefinitions", limit, start)

    @mcp.tool()
    async def get_forecasting_data_definition(data_definition_id: str, ctx: Context = None) -> dict:
        """Get details of a specific Visual Forecasting data definition."""
        async with viya_session("get_forecasting_data_definition", ctx) as client:
            return await get_json(client, f"/dataDefinitions/{data_definition_id}")

    @mcp.tool()
    async def create_forecasting_data_definition(body: str, ctx: Context = None) -> dict:
        """Create a new Visual Forecasting data definition (pass configuration as a JSON string)."""
        async with viya_session("create_forecasting_data_definition", ctx) as client:
            return await post_json(client, "/dataDefinitions", json.loads(body))

    @mcp.tool()
    async def delete_forecasting_data_definition(data_definition_id: str, ctx: Context = None) -> str:
        """Delete a Visual Forecasting data definition."""
        async with viya_session("delete_forecasting_data_definition", ctx) as client:
            await delete_resource(client, f"/dataDefinitions/{data_definition_id}")
            return f"Deleted data definition {data_definition_id}"

    @mcp.tool()
    async def run_final_forecast(data_definition_id: str, ctx: Context = None) -> dict:
        """Run the final forecast for a data definition."""
        async with viya_session("run_final_forecast", ctx) as client:
            return await post_json(client, f"/dataDefinitions/{data_definition_id}/finalForecast", {})

    @mcp.tool()
    async def list_forecasting_filters(limit: int = 10, start: int = 0, ctx: Context = None) -> dict:
        """List Visual Forecasting filters."""
        async with viya_session("list_forecasting_filters", ctx) as client:
            return await get_paged_items(client, "/filters", limit, start)

    @mcp.tool()
    async def get_forecasting_filter(filter_id: str, ctx: Context = None) -> dict:
        """Get details of a specific Visual Forecasting filter."""
        async with viya_session("get_forecasting_filter", ctx) as client:
            return await get_json(client, f"/filters/{filter_id}")


    @mcp.tool()
    async def get_forecasting_pipeline_results(pipeline_id: str, component_id: str, ctx: Context = None) -> dict:
        """Get the results of a specific component within a forecasting pipeline."""
        async with viya_session("get_forecasting_pipeline_results", ctx) as client:
            return await get_json(client, f"/pipelines/{pipeline_id}/components/{component_id}/results")

    @mcp.tool()
    async def run_forecasting_comparison(body: str, ctx: Context = None) -> dict:
        """Run a forecasting pipeline comparison (pass configuration as a JSON string)."""
        async with viya_session("run_forecasting_comparison", ctx) as client:
            return await post_json(client, "/comparison", json.loads(body))

    @mcp.tool()
    async def get_forecasting_comparison_results(ctx: Context = None) -> dict:
        """Get forecasting comparison results."""
        async with viya_session("get_forecasting_comparison_results", ctx) as client:
            return await get_json(client, "/comparison/results")

    @mcp.tool()
    async def generate_forecasting_timeseries_plot(body: str, ctx: Context = None) -> dict:
        """Generate a time series plot for exploration (pass configuration as a JSON string)."""
        async with viya_session("generate_forecasting_timeseries_plot", ctx) as client:
            return await post_json(client, "/timeSeriesPlot", json.loads(body))

    @mcp.tool()
    async def generate_forecast_plot(body: str, ctx: Context = None) -> dict:
        """Generate a forecast plot for exploration (pass configuration as a JSON string)."""
        async with viya_session("generate_forecast_plot", ctx) as client:
            return await post_json(client, "/forecastPlot", json.loads(body))
