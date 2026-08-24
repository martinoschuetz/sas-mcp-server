# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Generative AI (Retrieval Agent) tools."""

from collections.abc import Awaitable, Callable
from typing import Any

from fastmcp import Context, FastMCP

from .. import config
from ..viya_client import logger
from ._common import make_session_helpers


def register(
    mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]
) -> None:
    """Register Generative AI tools."""

    viya_session, _ = make_session_helpers(get_token)

    @mcp.tool()
    async def list_genai_agents(ctx: Context) -> dict[str, Any]:
        """List available Generative AI retrieval agents."""
        logger.info("--- TOOL USED: list_genai_agents ---")
        async with viya_session("list_genai_agents", ctx) as client:
            resp = await client.get(f"{config.VIYA_ENDPOINT}/retrievalAgentManager/agents")
            resp.raise_for_status()
            return resp.json()

    @mcp.tool()
    async def get_genai_agent(agent_id: str, ctx: Context) -> dict[str, Any]:
        """Get details for a specific Generative AI retrieval agent."""
        logger.info(f"--- TOOL USED: get_genai_agent ({agent_id}) ---")
        async with viya_session("get_genai_agent", ctx) as client:
            resp = await client.get(f"{config.VIYA_ENDPOINT}/retrievalAgentManager/agents/{agent_id}")
            resp.raise_for_status()
            return resp.json()

    @mcp.tool()
    async def list_genai_sources(ctx: Context) -> dict[str, Any]:
        """List available data sources for Generative AI agents."""
        logger.info("--- TOOL USED: list_genai_sources ---")
        async with viya_session("list_genai_sources", ctx) as client:
            resp = await client.get(f"{config.VIYA_ENDPOINT}/retrievalAgentManager/sources")
            resp.raise_for_status()
            return resp.json()

    @mcp.tool()
    async def list_genai_llms(ctx: Context) -> dict[str, Any]:
        """List available Large Language Models (LLMs) configured in Viya."""
        logger.info("--- TOOL USED: list_genai_llms ---")
        async with viya_session("list_genai_llms", ctx) as client:
            resp = await client.get(f"{config.VIYA_ENDPOINT}/retrievalAgentManager/llms")
            resp.raise_for_status()
            return resp.json()

    @mcp.tool()
    async def query_genai_agent(
        agent_id: str,
        query: str,
        ctx: Context,
        session_id: str | None = None
    ) -> dict[str, Any]:
        """
        Query a Generative AI retrieval agent.
        
        Args:
            agent_id: ID of the agent to query.
            query: The user prompt or question to send.
            session_id: Optional ID for continuing an existing query session.
        """
        logger.info(f"--- TOOL USED: query_genai_agent (agent: {agent_id}) ---")
        payload = {
            "agentId": agent_id,
            "content": query,
        }
        if session_id:
            payload["querySessionId"] = session_id

        async with viya_session("query_genai_agent", ctx) as client:
            resp = await client.post(f"{config.VIYA_ENDPOINT}/retrievalAgentManager/query", json=payload)
            resp.raise_for_status()
            return resp.json()
