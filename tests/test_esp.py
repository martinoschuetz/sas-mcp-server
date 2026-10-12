import httpx
import pytest
from fastmcp import Client, FastMCP
from fastmcp.exceptions import ToolError

import sas_mcp_server.tools._common as common
from sas_mcp_server.tools.esp import register

VIYA = "https://viya.example.com"
BASE = "/SASEventStreamProcessingStudio/v4/projects"


@pytest.mark.asyncio
async def test_register():
    mcp = FastMCP("test")
    register(mcp, lambda ctx: "token")
    tools = await mcp.list_tools()
    tool_names = [t.name for t in tools]
    assert "esp_deploy_project" in tool_names
    assert "esp_get_project_xml" in tool_names
    assert "esp_delete_project" in tool_names


def _client_for(handler, monkeypatch):
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(common, "make_client", lambda token=None: httpx.AsyncClient(transport=transport, base_url=VIYA))
    mcp = FastMCP("esp-test")

    async def get_token(ctx):  # noqa: ARG001
        return "t"

    register(mcp, get_token)
    return Client(mcp)


async def test_deploy_ignores_404_and_posts_wrapper(monkeypatch):
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        if request.method == "DELETE":
            return httpx.Response(404)
        return httpx.Response(201, json={"friendlyName": "P1", "type": "ESP Project"})

    async with _client_for(handler, monkeypatch) as client:
        res = await client.call_tool("esp_deploy_project", {"project_name": "P1", "xml_content": "<project/>"})

    assert [r.method for r in seen] == ["DELETE", "POST"]
    post = seen[1]
    assert post.url.path == BASE
    assert post.headers["content-type"] == "application/vnd.sas.esp.espproject+json"
    body = httpx.Response(200, content=post.content).json()
    assert body["friendlyName"] == "P1"
    assert body["xml"] == "<project/>"
    assert "ESP Project" in res.content[0].text


async def test_deploy_surfaces_delete_auth_error_without_posting(monkeypatch):
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request.method)
        return httpx.Response(403, json={"message": "forbidden"})

    async with _client_for(handler, monkeypatch) as client:
        with pytest.raises(ToolError):
            await client.call_tool("esp_deploy_project", {"project_name": "P1", "xml_content": "<project/>"})

    assert seen == ["DELETE"]


async def test_get_project_xml_returns_only_xml(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == f"{BASE}/P1"
        return httpx.Response(200, json={"friendlyName": "P1", "xml": "<project name='P1'/>"})

    async with _client_for(handler, monkeypatch) as client:
        res = await client.call_tool("esp_get_project_xml", {"project_name": "P1"})

    assert res.content[0].text == "<project name='P1'/>"
