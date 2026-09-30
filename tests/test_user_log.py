# Copyright © 2026, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""The user id in the server log, and the VIYA_CLIENT_TIMEOUT setting.

The lookup's shape was probed against a live Viya: ``GET
/identities/users/@currentUser`` with ``Accept: application/json`` answers 200
with the user's ``id`` (for a client-credentials token, the client's id).
"""

from __future__ import annotations

import importlib
import logging
import sys
from contextlib import asynccontextmanager
from unittest.mock import patch

import httpx
import pytest
from fastmcp import Client, Context, FastMCP

from sas_mcp_server import user_log
from sas_mcp_server.exceptions import ConfigError
from sas_mcp_server.user_log import (
    CURRENT_USER_PATH,
    clear_user_cache,
    install_user_log,
    resolve_user_id,
    with_user_log,
)


@pytest.fixture(autouse=True)
def _fresh_cache():
    clear_user_cache()
    yield
    clear_user_cache()


class FakeIdentities:
    """Answers @currentUser; counts the calls and records what was asked."""

    def __init__(self, status: int = 200, user_id: str | None = "sasdemo", raises: bool = False):
        self.status = status
        self.user_id = user_id
        self.raises = raises
        self.calls: list[tuple[str, dict]] = []

    async def get(self, url, headers=None, timeout=None):
        self.calls.append((url, {"headers": headers, "timeout": timeout}))
        if self.raises:
            raise httpx.ConnectError("identities unreachable")
        body = {"id": self.user_id, "name": "SAS Demo", "type": "user"} if self.user_id else {}
        return httpx.Response(self.status, json=body, request=httpx.Request("GET", url))


def _patched(fake: FakeIdentities):
    @asynccontextmanager
    async def client(token):
        yield fake

    return patch("sas_mcp_server.user_log.make_client", client)


# --- the lookup ------------------------------------------------------------------


async def test_the_user_id_comes_from_current_user_as_json():
    fake = FakeIdentities()
    with _patched(fake):
        assert await resolve_user_id("tok-1") == "sasdemo"
    url, sent = fake.calls[0]
    assert url.endswith(CURRENT_USER_PATH)
    assert sent["headers"] == {"Accept": "application/json"}
    # Short, so a slow identities service never holds a tool call for the
    # full client timeout.
    assert sent["timeout"] is not None and sent["timeout"] <= 10


async def test_one_lookup_per_token_not_per_call():
    fake = FakeIdentities()
    with _patched(fake):
        for _ in range(5):
            assert await resolve_user_id("tok-1") == "sasdemo"
        assert await resolve_user_id("tok-2") == "sasdemo"
    assert len(fake.calls) == 2


async def test_the_cache_never_holds_the_token():
    with _patched(FakeIdentities()):
        await resolve_user_id("very-secret-token")
    assert all("very-secret-token" not in key for key in user_log._cache)


@pytest.mark.parametrize(
    "fake",
    [FakeIdentities(status=401), FakeIdentities(user_id=None), FakeIdentities(raises=True)],
    ids=["http-error", "no-id", "transport-error"],
)
async def test_a_failed_lookup_is_none_never_an_error(fake):
    with _patched(fake):
        assert await resolve_user_id("tok") is None


async def test_a_failure_is_retried_only_after_a_while():
    fake = FakeIdentities(raises=True)
    with _patched(fake), patch("sas_mcp_server.user_log.time.monotonic", return_value=1000.0):
        await resolve_user_id("tok")
        await resolve_user_id("tok")
    assert len(fake.calls) == 1
    fake.raises = False
    with _patched(fake), patch(
        "sas_mcp_server.user_log.time.monotonic", return_value=1000.0 + user_log._FAILURE_TTL + 1
    ):
        assert await resolve_user_id("tok") == "sasdemo"
    assert len(fake.calls) == 2


async def test_no_token_means_no_lookup():
    fake = FakeIdentities()
    with _patched(fake):
        assert await resolve_user_id("") is None
        assert await resolve_user_id(None) is None
    assert fake.calls == []


async def test_the_cache_is_bounded():
    with _patched(FakeIdentities()), patch.object(user_log, "_CACHE_SIZE", 3):
        for i in range(10):
            await resolve_user_id(f"tok-{i}")
    assert len(user_log._cache) == 3


# --- the log line ----------------------------------------------------------------


def _user_lines(caplog) -> list[str]:
    return [r.getMessage() for r in caplog.records if r.getMessage().startswith("Tool call:")]


async def test_each_tool_call_logs_its_name_and_user_once(caplog):
    """Through a real FastMCP server: the middleware names the tool, and a tool
    that fetched its token twice still logs one line."""
    fetched: list[str] = []

    async def get_token(ctx: Context) -> str:
        fetched.append("x")
        return "tok-1"

    mcp = FastMCP("t")
    wrapped = install_user_log(mcp, get_token)

    @mcp.tool
    async def run_things(ctx: Context) -> str:
        await wrapped(ctx)
        return await wrapped(ctx)

    @mcp.tool
    async def other_tool(ctx: Context) -> str:
        return await wrapped(ctx)

    with _patched(FakeIdentities()), caplog.at_level(logging.INFO):
        async with Client(mcp) as client:
            first = await client.call_tool("run_things", {})
            await client.call_tool("other_tool", {})
    assert first.data == "tok-1"  # the token is handed on unchanged
    assert len(fetched) == 3
    assert _user_lines(caplog) == [
        "Tool call: run_things (user: sasdemo)",
        "Tool call: other_tool (user: sasdemo)",
    ]


async def test_a_failed_lookup_logs_unknown_and_the_tool_still_runs(caplog):
    async def get_token(ctx):
        return "tok"

    mcp = FastMCP("t")
    wrapped = install_user_log(mcp, get_token)

    @mcp.tool
    async def probe(ctx: Context) -> str:
        await wrapped(ctx)
        return "ran"

    with _patched(FakeIdentities(status=500)), caplog.at_level(logging.INFO):
        async with Client(mcp) as client:
            result = await client.call_tool("probe", {})
    assert result.data == "ran"
    assert _user_lines(caplog) == ["Tool call: probe (user: unknown)"]


async def test_a_token_failure_propagates_without_a_line(caplog):
    async def get_token(ctx):
        raise RuntimeError("no credentials")

    with caplog.at_level(logging.INFO), pytest.raises(RuntimeError, match="no credentials"):
        await with_user_log(get_token)(None)  # type: ignore[arg-type]
    assert _user_lines(caplog) == []


async def test_outside_a_tool_call_the_line_still_names_the_user(caplog):
    async def get_token(ctx):
        return "tok"

    with _patched(FakeIdentities()), caplog.at_level(logging.INFO):
        assert await with_user_log(get_token)(None) == "tok"  # type: ignore[arg-type]
    assert _user_lines(caplog) == ["Tool call: unknown (user: sasdemo)"]


# --- VIYA_CLIENT_TIMEOUT ---------------------------------------------------------


def _reload_config(monkeypatch, value: str | None):
    monkeypatch.setenv("VIYA_ENDPOINT", "https://test.viya.com")
    if value is None:
        monkeypatch.delenv("VIYA_CLIENT_TIMEOUT", raising=False)
    else:
        monkeypatch.setenv("VIYA_CLIENT_TIMEOUT", value)
    with patch("dotenv.load_dotenv"):
        return importlib.reload(sys.modules["sas_mcp_server.config"])


@pytest.fixture
def _restore_config(monkeypatch):
    yield
    # A failed reload leaves the module half-initialised; put it back.
    monkeypatch.delenv("VIYA_CLIENT_TIMEOUT", raising=False)
    monkeypatch.setenv("VIYA_ENDPOINT", "https://test.viya.com")
    with patch("dotenv.load_dotenv"):
        importlib.reload(sys.modules["sas_mcp_server.config"])


@pytest.mark.usefixtures("_restore_config")
@pytest.mark.parametrize(("raw", "expected"), [(None, 300.0), ("", 300.0), ("45", 45.0), (" 7.5 ", 7.5)])
def test_client_timeout_default_and_override(monkeypatch, raw, expected):
    timeout = _reload_config(monkeypatch, raw).VIYA_CLIENT_TIMEOUT
    assert timeout == expected


@pytest.mark.usefixtures("_restore_config")
@pytest.mark.parametrize(
    ("raw", "message"),
    [("abc", "number of seconds"), ("0", "greater than 0"), ("-5", "greater than 0")],
)
def test_a_bad_client_timeout_stops_the_server_with_a_reason(monkeypatch, raw, message):
    with pytest.raises(ConfigError, match=message):
        _reload_config(monkeypatch, raw)


def test_every_viya_client_uses_the_configured_timeout():
    from sas_mcp_server import viya_client

    with patch.object(viya_client, "_CLIENT_TIMEOUT", 42.0):
        client = viya_client.make_client("tok")
    assert client.timeout == httpx.Timeout(42.0)
