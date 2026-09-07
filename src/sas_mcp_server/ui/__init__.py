# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""Interactive views for hosts that render MCP Apps.

Some results read badly as text however well the tool shapes them: a hundred
rows of a table, a SAS log, a form's worth of typed attributes. The MCP Apps
extension (``io.modelcontextprotocol/ui``) lets a tool also carry a small HTML
view that a supporting host — Claude, ChatGPT, Microsoft 365 Copilot, VS Code,
Cursor — renders in a sandboxed iframe beside the result, and that can call
the server's tools itself for the next page, a refresh, or a save.

The views here are **additive**. A tool's return value is exactly what it was;
the view is extra metadata (``_meta.ui.resourceUri``) plus a ``ui://`` resource
holding the HTML. A host without the extension never reads either, so Claude
Code and every other text-only client see nothing different. And every request
a view makes goes through the host to this server as an ordinary ``tools/call``
with the session's token: the browser never talks to Viya, and a tool a
deployment withholds (``MCP_TIERS``, ``MCP_READ_ONLY``) is withheld from the
views too.

Wiring is central, not per tool. :data:`VIEWS` says which tools carry which
view; :func:`app_config` hands the tier recorder the ``app=`` argument for a
tool as it registers, and :func:`register_views` publishes one resource per
registered tool afterwards. The HTML is assembled by :func:`render_view` from
three parts kept as files beside this module: the shell (theme tokens and the
runtime every view shares), the vendored ``@modelcontextprotocol/ext-apps``
bridge, and the view itself. Everything is inlined — no CDN, no external
stylesheet — because hosts build the iframe's CSP from what the server
declares and at least one ignores the declaration entirely; inline is the
one form that renders everywhere, including on an air-gapped Viya.
"""

from __future__ import annotations

import json
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from functools import cache
from importlib import resources
from typing import TYPE_CHECKING

from fastmcp.apps import UI_MIME_TYPE, AppConfig

from ..config import MCP_APPS

if TYPE_CHECKING:
    from fastmcp import FastMCP

# Every view URI starts with this; the rest is ``<view>/<tool>.html``.
URI_PREFIX = "ui://sas-viya/"


@dataclass(frozen=True)
class View:
    """One HTML view and the tools whose results it renders."""

    key: str
    title: str
    tools: tuple[str, ...]
    #: Other tools the view calls of its own accord — a next page, a lookup,
    #: an action offered on the result. A deployment can withhold any of them
    #: through ``MCP_TIERS`` or ``MCP_READ_ONLY`` while still registering the
    #: view, so which ones survived is stamped into the page and the view asks
    #: ``sas.can(...)`` before offering the control. Otherwise a read-only
    #: deployment shows a Publish button whose only possible outcome is an error.
    calls: tuple[str, ...] = ()

    @property
    def template(self) -> str:
        return f"{self.key}.html"


VIEWS: tuple[View, ...] = (
    View(
        key="data-grid",
        title="Data grid",
        tools=("query_data", "get_castable_data", "get_compute_table_data"),
    ),
    View(
        key="sas-log",
        title="SAS log",
        tools=("execute_sas_code", "get_job_log", "submit_batch_job"),
        calls=("get_job_status", "get_job_log"),
    ),
    View(
        key="term-editor",
        title="Glossary term editor",
        tools=("get_glossary_term_type", "get_glossary_term"),
        calls=("get_glossary_term_type", "create_glossary_term", "update_glossary_term"),
    ),
    View(
        key="term-tree",
        title="Glossary browser",
        tools=("list_glossary_terms",),
        calls=("list_glossary_terms", "list_term_assets", "update_glossary_term"),
    ),
    View(
        key="import-preview",
        title="Glossary import",
        tools=("import_glossary_terms",),
    ),
)

VIEW_FOR_TOOL: dict[str, View] = {tool: view for view in VIEWS for tool in view.tools}


def resource_uri(tool: str) -> str:
    """The ``ui://`` URI of *tool*'s view. One per tool, so the view knows
    which tool to call again for the next page without the host telling it."""
    return f"{URI_PREFIX}{VIEW_FOR_TOOL[tool].key}/{tool}.html"


def app_config(tool: str, *, enabled: bool | None = None) -> AppConfig | None:
    """The ``app=`` argument for *tool*'s registration, or ``None``.

    ``None`` when the tool has no view or views are switched off, which is
    what FastMCP takes to mean "an ordinary tool".
    """
    on = MCP_APPS if enabled is None else enabled
    if not on or tool not in VIEW_FOR_TOOL:
        return None
    return AppConfig(resource_uri=resource_uri(tool))


def _read(name: str) -> str:
    return resources.files(__package__).joinpath(name).read_text(encoding="utf-8")


def bridge_version() -> str:
    return _read("vendor/VERSION").strip()


@cache
def render_view(
    view_key: str, tool: str, version: str = "", available: tuple[str, ...] = ()
) -> str:
    """Assemble the complete HTML document for one (view, tool) pair.

    Cached: the document is fixed for the process lifetime and a host may
    read it on every render. The tool name is stamped into the page as
    ``SAS_VIEW`` so the view can re-invoke exactly the tool that produced
    its result (the extension does not pass the name along), and with it the
    subset of the view's :attr:`View.calls` this deployment actually
    registered, which :func:`sas.can` in the shell reads.
    """
    view = next(v for v in VIEWS if v.key == view_key)
    stamp = json.dumps(
        {
            "tool": tool,
            "view": view.key,
            "title": view.title,
            "version": version,
            "can": sorted(available),
        }
    )
    return (
        "<!doctype html>\n"
        '<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{view.title}</title>\n"
        f"<style>\n{_read('shell.css')}</style>\n</head>\n<body>\n"
        f'<script type="module">{_read("vendor/ext-apps.js")}</script>\n'
        f"<script>globalThis.SAS_VIEW = {stamp};</script>\n"
        f'<script type="module">\n{_read("shell.js")}</script>\n'
        f"{_read('views/' + view.template)}\n"
        "</body>\n</html>\n"
    )


def register_views(mcp: FastMCP, tools: Iterable[str], *, version: str = "") -> list[str]:
    """Publish a ``ui://`` resource for every registered tool that has a view.

    Only tools in *tools* get one — a view for a tool the deployment withheld
    would advertise something the host could never call. Returns the URIs
    registered, for logging.
    """
    present = set(tools)
    registered: list[str] = []
    for tool in sorted(present):
        view = VIEW_FOR_TOOL.get(tool)
        if view is None:
            continue
        uri = resource_uri(tool)
        # Only the companion tools this deployment kept, so a view offers no
        # control the server would refuse.
        available = tuple(sorted(c for c in view.calls if c in present))
        mcp.resource(
            uri,
            name=f"{view.key}:{tool}",
            description=f"{view.title} view for the {tool} tool (MCP Apps).",
            mime_type=UI_MIME_TYPE,
        )(_server_for(view.key, tool, version, available))
        registered.append(uri)
    return registered


def _server_for(
    view_key: str, tool: str, version: str, available: tuple[str, ...] = ()
) -> Callable[[], str]:
    """A zero-argument reader for one view. FastMCP takes any parameter on a
    resource function to mean a URI *template*, so the binding has to close
    over the values rather than take them as defaults."""

    def _serve() -> str:
        return render_view(view_key, tool, version, available)

    return _serve


__all__ = [
    "URI_PREFIX",
    "VIEWS",
    "VIEW_FOR_TOOL",
    "View",
    "app_config",
    "bridge_version",
    "register_views",
    "render_view",
    "resource_uri",
]
