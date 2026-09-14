# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""Interactive views (MCP Apps): wiring, resources, and the assembled HTML.

The browser side has no harness here — it is exercised in an MCP Apps host.
What these tests pin is everything the server is responsible for: which tools
advertise a view, that each advertised view is a resource the host can read,
that the switch really removes both, and that the HTML is self-contained.
"""

from __future__ import annotations

import json
import re

import pytest
from fastmcp import Client, FastMCP
from fastmcp.apps import UI_MIME_TYPE

from sas_mcp_server import tools, ui
from sas_mcp_server.tools._access import READ_ONLY_TOOLS, WRITE_TOOLS


async def _server(**kwargs) -> FastMCP:
    mcp = FastMCP("ui-test")

    async def get_token(ctx):
        return "t"

    tools.register_tools(mcp, get_token, **kwargs)
    return mcp


async def _listing(mcp: FastMCP):
    async with Client(mcp) as client:
        return await client.list_tools(), await client.list_resources()


def _view_uri(tool) -> str | None:
    meta = tool.meta or {}
    ui_meta = meta.get("ui") if isinstance(meta, dict) else None
    return ui_meta.get("resourceUri") if isinstance(ui_meta, dict) else None


# --- the mapping itself --------------------------------------------------------


def test_every_view_tool_is_a_real_classified_tool():
    """A view for a tool that no tier registers would be dead metadata."""
    known = READ_ONLY_TOOLS | WRITE_TOOLS
    for view in ui.VIEWS:
        for tool in view.tools:
            assert tool in known, f"{view.key} names unknown tool {tool!r}"


def test_every_declared_call_is_a_real_tool():
    """A view calls these of its own accord; a renamed tool would fail in the
    browser, where nothing here would notice."""
    known = READ_ONLY_TOOLS | WRITE_TOOLS
    for view in ui.VIEWS:
        for tool in view.calls:
            assert tool in known, f"{view.key} calls unknown tool {tool!r}"


def test_declared_calls_cover_what_the_views_actually_call():
    """The stamp is what `sas.can` reads, so an undeclared call is a control
    the deployment can never switch off."""
    for view in ui.VIEWS:
        source = ui._read(f"views/{view.template}")
        for tool in re.findall(r'sas\.call\("([a-z_]+)"', source):
            assert tool in view.calls, f"{view.key} calls {tool!r} without declaring it"
        for tool in re.findall(r'sas\.can\("([a-z_]+)"', source):
            assert tool in view.calls, f"{view.key} asks about undeclared {tool!r}"


def test_a_tool_has_at_most_one_view():
    seen: dict[str, str] = {}
    for view in ui.VIEWS:
        for tool in view.tools:
            assert tool not in seen, f"{tool} is claimed by {seen[tool]} and {view.key}"
            seen[tool] = view.key


def test_every_view_has_a_template():
    for view in ui.VIEWS:
        assert ui._read(f"views/{view.template}").strip(), view.key


def test_resource_uri_is_per_tool_under_the_prefix():
    assert ui.resource_uri("query_data") == "ui://sas-viya/data-grid/query_data.html"
    assert ui.resource_uri("get_castable_data") != ui.resource_uri("query_data")


def test_app_config_is_none_for_tools_without_a_view_or_when_off():
    assert ui.app_config("list_caslibs", enabled=True) is None
    assert ui.app_config("query_data", enabled=False) is None
    cfg = ui.app_config("query_data", enabled=True)
    assert cfg is not None
    assert cfg.resource_uri == ui.resource_uri("query_data")


# --- what a host sees -----------------------------------------------------------


async def test_view_tools_advertise_a_resource_that_exists():
    listed_tools, resources = await _listing(await _server(apps=True))
    by_uri = {str(r.uri): r for r in resources}
    advertised = {t.name: _view_uri(t) for t in listed_tools if _view_uri(t)}

    assert set(advertised) == set(ui.VIEW_FOR_TOOL), "every view tool advertises, nothing else does"
    for tool, uri in advertised.items():
        assert uri in by_uri, f"{tool} points at {uri}, which is not a resource"
        assert by_uri[uri].mime_type == UI_MIME_TYPE
    assert {str(r.uri) for r in resources} == set(advertised.values())


async def test_switch_off_removes_metadata_and_resources():
    listed_tools, resources = await _listing(await _server(apps=False))
    assert not [t.name for t in listed_tools if _view_uri(t)]
    assert not [r for r in resources if str(r.uri).startswith(ui.URI_PREFIX)]


async def test_env_var_drives_the_default(monkeypatch):
    monkeypatch.setattr(tools, "MCP_APPS", False)
    _, resources = await _listing(await _server())
    assert not resources
    monkeypatch.setattr(tools, "MCP_APPS", True)
    _, resources = await _listing(await _server())
    assert resources


async def test_read_only_mode_registers_views_only_for_tools_it_kept():
    """A view whose tool was withheld would advertise something the host cannot call."""
    listed_tools, resources = await _listing(await _server(read_only=True, apps=True))
    names = {t.name for t in listed_tools}
    uris = {str(r.uri) for r in resources}
    assert ui.resource_uri("get_castable_data") in uris  # read-only tool, kept
    assert "import_glossary_terms" not in names
    assert ui.resource_uri("import_glossary_terms") not in uris
    # query_data runs a compute job, so read-only mode withholds it — and its view.
    assert "query_data" not in names
    assert ui.resource_uri("query_data") not in uris
    assert ui.resource_uri("execute_sas_code") not in uris


async def test_the_stamp_lists_only_companion_tools_the_deployment_kept():
    """`sas.can` gates a view's own controls. Read-only keeps the glossary
    browser but not the tool that publishes a draft from it, so the button
    must not be offered rather than offered and refused."""
    async def stamped(**kwargs) -> set[str]:
        mcp = await _server(apps=True, **kwargs)
        async with Client(mcp) as client:
            text = (await client.read_resource(ui.resource_uri("list_glossary_terms")))[0].text
        # The stamp, not the page: the view's own source names the tool too.
        stamp = re.search(r"globalThis\.SAS_VIEW = (\{.*?\});", text, re.S)
        assert stamp, "no SAS_VIEW stamp"
        return set(json.loads(stamp.group(1))["can"])

    locked = await stamped(read_only=True)
    assert "list_term_assets" in locked, "a read-only companion survives"
    assert "update_glossary_term" not in locked, "the write companion must not be offered"
    assert "update_glossary_term" in await stamped()


async def test_tier_selection_limits_views_the_same_way():
    _, resources = await _listing(await _server(tiers="1", apps=True))
    uris = {str(r.uri) for r in resources}
    assert ui.resource_uri("query_data") in uris
    assert ui.resource_uri("execute_sas_code") not in uris  # tier 0
    assert ui.resource_uri("list_glossary_terms") not in uris  # tier 9


async def test_view_tools_are_still_ordinary_tools():
    """The view is metadata; the tool's result is what it always was."""
    listed_tools, _ = await _listing(await _server(apps=True))
    grid = next(t for t in listed_tools if t.name == "get_castable_data")
    assert grid.annotations is not None and grid.annotations.read_only_hint is True
    assert "table_name" in grid.input_schema["properties"]


async def test_landing_page_marks_view_tools_as_interactive():
    from sas_mcp_server.landing import collect_facts, render_page

    facts = await collect_facts(
        await _server(apps=True),
        server_name="s",
        mcp_url="http://h/mcp",
        viya_endpoint="https://v",
        auth_enabled=True,
        allow_raw_bearer=False,
        read_only=False,
        enabled_tiers=tools.ALL_TIERS,
    )
    flagged = {t.name for g in facts.tiers for t in g.tools if t.interactive}
    assert flagged == set(ui.VIEW_FOR_TOOL)
    page = render_page(facts, nonce="n")
    assert '<em class="view">interactive</em>' in page
    assert "MCP Apps" in page

    facts_off = await collect_facts(
        await _server(apps=False),
        server_name="s",
        mcp_url="http://h/mcp",
        viya_endpoint="https://v",
        auth_enabled=True,
        allow_raw_bearer=False,
        read_only=False,
        enabled_tiers=tools.ALL_TIERS,
    )
    assert not [t for g in facts_off.tiers for t in g.tools if t.interactive]
    assert '<em class="view">' not in render_page(facts_off, nonce="n")


async def test_reading_the_resource_returns_the_document():
    mcp = await _server(apps=True)
    async with Client(mcp) as client:
        content = await client.read_resource(ui.resource_uri("execute_sas_code"))
    text = content[0].text  # type: ignore[union-attr]
    assert text.startswith("<!doctype html>")
    assert '"tool": "execute_sas_code"' in text
    assert content[0].mime_type == UI_MIME_TYPE


# --- the document ---------------------------------------------------------------


@pytest.mark.parametrize("tool", sorted(ui.VIEW_FOR_TOOL))
def test_document_is_self_contained(tool):
    """Hosts build the iframe CSP from what we declare, and Claude.ai ignores
    the declaration; only an inline page renders everywhere."""
    html = ui.render_view(ui.VIEW_FOR_TOOL[tool].key, tool, "1.0-test")
    assert not re.search(r'(src|href)\s*=\s*"https?://', html), "external asset"
    assert "@import" not in html
    assert html.count('<script type="module">') == 3, "bridge, shell, view"
    assert "globalThis.__MCP_EXT_APPS__" in html, "vendored bridge exposes App"
    assert "globalThis.sas = sas" in html, "shell runtime"
    assert f'"tool": "{tool}"' in html, "tool stamped for re-invocation"
    assert '"version": "1.0-test"' in html
    assert "export " not in html.split('<script type="module">')[1].split("</script>")[0][-400:], (
        "the bridge's export block must be rewritten, not left as ESM exports"
    )


def test_fullscreen_is_the_shells_and_every_view_can_use_it():
    """One toggle, one `data-display` attribute, one `fill` rule. A view
    talking to the display API on its own would have a second, drifting copy."""
    shell = ui._read("shell.js")
    assert "toggleFullscreen" in shell and 'availableDisplayModes: ["inline", "fullscreen"]' in shell
    assert ':root[data-display="fullscreen"] #root > .fill' in ui._read("shell.css")
    for view in ui.VIEWS:
        page = ui._read("views/" + view.template)
        assert "requestDisplayMode" not in page, f"{view.key} bypasses the shell"
        assert 'id="fullscreen"' not in page, f"{view.key} keeps its own button"
        assert '<div id="root">' in page and 'class="head"' in page, f"{view.key} has nowhere to mount the toggle"
        if view.key != "term-editor":  # a form scrolls with the page; nothing to fill
            assert 'class="scroll fill"' in page or 'class="fill"' in page, f"{view.key} has no fill region"


def test_document_is_cached_per_pair():
    a = ui.render_view("data-grid", "query_data", "v")
    b = ui.render_view("data-grid", "query_data", "v")
    assert a is b
    assert ui.render_view("data-grid", "get_castable_data", "v") is not a


def test_vendored_bridge_is_pinned():
    assert re.fullmatch(r"\d+\.\d+\.\d+", ui.bridge_version())
    assert ui.bridge_version() in ui._read("vendor/ext-apps.js")[:300]
    assert "Apache License" in ui._read("vendor/ext-apps.LICENSE")
