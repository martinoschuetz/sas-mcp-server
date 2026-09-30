# Copyright © 2026, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Name the SAS Viya user behind every tool call in the server log.

A shared HTTP deployment serves many people through one process, and its log
said which tool ran but not for whom, so a field report could not be matched
to the person who hit it. Each tool call now logs one line::

    Tool call: execute_sas_code (user: sasdemo)

The user id is the ``id`` field of ``GET /identities/users/@currentUser``,
asked with the caller's own Viya token, so it is exactly the identity Viya
checks the call against (for a client-credentials token, the client's id).

How it hooks in, and why there:

* Every tool awaits its ``get_token(ctx)`` exactly once. :func:`with_user_log`
  wraps that function, so the lookup runs right after the token exists, on
  both transports, without acquiring a second token — which under stdio could
  start a second device-code sign-in.
* The tool's name is not on its ``Context``; :class:`ToolNameMiddleware` puts
  it in a context variable for the wrapper to read, and makes sure a tool that
  fetched its token twice would still log once.
* The lookup is cached per token (a hash of it, never the token), so it costs
  one extra request per sign-in or token refresh, not one per tool call. A
  failed lookup is remembered briefly too, so an identities service that is
  down is not asked again on every call.
* Nothing here can fail a tool call: the lookup is bounded by a short timeout
  and any fault logs ``user: unknown``.
"""

from __future__ import annotations

import hashlib
import time
from collections.abc import Awaitable, Callable
from contextvars import ContextVar
from typing import Any

from fastmcp import Context, FastMCP
from fastmcp.server.middleware import CallNext, Middleware, MiddlewareContext

from .config import VIYA_ENDPOINT
from .viya_client import logger, make_client

__all__ = [
    "CURRENT_USER_PATH",
    "ToolNameMiddleware",
    "clear_user_cache",
    "install_user_log",
    "resolve_user_id",
    "with_user_log",
]

CURRENT_USER_PATH = "/identities/users/@currentUser"

# The lookup runs before the tool body, so it must never hold a call up for
# the full VIYA_CLIENT_TIMEOUT.
_LOOKUP_TIMEOUT = 10.0
# A failed lookup is retried after this long, not on every call.
_FAILURE_TTL = 300.0
# Distinct tokens remembered; the oldest is dropped past this.
_CACHE_SIZE = 512

# token hash -> (user id or None, monotonic time of the lookup)
_cache: dict[str, tuple[str | None, float]] = {}

# The tool call in progress: its name, and whether its line was logged.
_current_call: ContextVar[dict[str, Any] | None] = ContextVar(
    "sas_mcp_current_tool_call", default=None
)


def clear_user_cache() -> None:
    """Forget every resolved user (tests; a new token resolves anew anyway)."""
    _cache.clear()


def _key(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _remember(key: str, user_id: str | None) -> None:
    _cache.pop(key, None)
    while len(_cache) >= _CACHE_SIZE:
        _cache.pop(next(iter(_cache)))
    _cache[key] = (user_id, time.monotonic())


async def resolve_user_id(token: str | None) -> str | None:
    """The Viya user id the *token* belongs to, or ``None``. Never raises."""
    if not token:
        return None
    key = _key(token)
    hit = _cache.get(key)
    if hit is not None:
        user_id, when = hit
        if user_id is not None or time.monotonic() - when < _FAILURE_TTL:
            return user_id
    user_id: str | None = None
    try:
        async with make_client(token) as client:
            resp = await client.get(
                f"{VIYA_ENDPOINT}{CURRENT_USER_PATH}",
                headers={"Accept": "application/json"},
                timeout=_LOOKUP_TIMEOUT,
            )
        if resp.status_code == 200:
            found = resp.json().get("id")
            user_id = str(found) if found else None
        else:
            logger.debug("User lookup answered HTTP %s", resp.status_code)
    except Exception as exc:  # noqa: BLE001 - a log line must never fail a tool call
        logger.debug("User lookup failed: %s", exc)
    _remember(key, user_id)
    return user_id


class ToolNameMiddleware(Middleware):
    """Publish the running tool's name to :func:`with_user_log`'s wrapper."""

    async def on_call_tool(self, context: MiddlewareContext, call_next: CallNext) -> Any:
        name = getattr(context.message, "name", None)
        reset = _current_call.set({"tool": name, "logged": False})
        try:
            return await call_next(context)
        finally:
            _current_call.reset(reset)


def with_user_log(
    get_token: Callable[[Context], Awaitable[str]],
) -> Callable[[Context], Awaitable[str]]:
    """Wrap a server's ``get_token`` so each tool call logs its user."""

    async def get_token_and_log_user(ctx: Context) -> str:
        token = await get_token(ctx)
        call = _current_call.get()
        if call is None or not call["logged"]:
            if call is not None:
                call["logged"] = True
            user_id = await resolve_user_id(token)
            tool = call["tool"] if call is not None else None
            logger.info("Tool call: %s (user: %s)", tool or "unknown", user_id or "unknown")
        return token

    return get_token_and_log_user


def install_user_log(
    mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]
) -> Callable[[Context], Awaitable[str]]:
    """Add the tool-name middleware to *mcp* and return the wrapped getter to
    pass to ``register_tools``."""
    mcp.add_middleware(ToolNameMiddleware())
    return with_user_log(get_token)
