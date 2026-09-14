# Copyright a 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tier 12 - Event Stream Processing (ESP) tools."""

from collections.abc import Awaitable, Callable
from typing import Any

from fastmcp import Context, FastMCP

from ..viya_client import (
    delete_resource,
    get_json,
)
from ._common import make_session_helpers


def register(mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]) -> None:
    """Register Tier 12 (ESP) tools on *mcp*."""

    viya_session, _ = make_session_helpers(get_token)

    @mcp.tool()
    async def esp_deploy_project(project_name: str, xml_content: str, ctx: Context) -> dict[str, Any]:
        """Deploys raw ESP XML to the Viya ESP Studio.

        Args:
            project_name: Name of the ESP project.
            xml_content: Raw XML string of the project configuration.
        """
        async with viya_session("esp_deploy_project", ctx) as client:
            # 1. Attempt to delete existing project (ignore 404)
            try:
                resp_del = await client.delete(f"/SASEventStreamProcessingStudio/v4/projects/{project_name}")
                if resp_del.status_code != 404:
                    resp_del.raise_for_status()
            except Exception:
                pass

            # 2. Construct JSON dictionary
            body = {"name": project_name, "projectName": project_name, "friendlyName": project_name, "xml": xml_content}

            # 3. Issue POST
            resp = await client.post(
                "/SASEventStreamProcessingStudio/v4/projects",
                json=body,
                headers={"Content-Type": "application/vnd.sas.esp.espproject+json"},
            )
            resp.raise_for_status()
            if resp.status_code == 204 or not resp.content:
                return {"status": "success", "message": "Project deployed but no content returned."}
            return resp.json()

    @mcp.tool()
    async def esp_get_project_xml(project_name: str, ctx: Context) -> str:
        """Retrieves the raw XML for an existing ESP project.

        Args:
            project_name: Name of the ESP project.
        """
        async with viya_session("esp_get_project_xml", ctx) as client:
            data = await get_json(f"/SASEventStreamProcessingStudio/v4/projects/{project_name}", client)
            return data.get("xml", "")

    @mcp.tool()
    async def esp_delete_project(project_name: str, ctx: Context) -> str:
        """Deletes a project from ESP Studio.

        Args:
            project_name: Name of the ESP project.
        """
        async with viya_session("esp_delete_project", ctx) as client:
            await delete_resource(f"/SASEventStreamProcessingStudio/v4/projects/{project_name}", client)
            return f"ESP Project {project_name} deleted."
