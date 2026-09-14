import pytest
from fastmcp import FastMCP

from sas_mcp_server.tools.esp import register


@pytest.mark.asyncio
async def test_register():
    mcp = FastMCP('test')
    register(mcp, lambda ctx: 'token')
    tools = await mcp.list_tools()
    tool_names = [t.name for t in tools]
    assert 'esp_deploy_project' in tool_names
    assert 'esp_get_project_xml' in tool_names
    assert 'esp_delete_project' in tool_names

