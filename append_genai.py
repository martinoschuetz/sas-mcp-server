import sys

with open('tests/test_integration.py', 'a') as f:
    f.write('''

@pytest.mark.asyncio
@respx.mock
async def test_genai_workflow(integration_mcp_server):
    viya_url = os.getenv("VIYA_ENDPOINT", "").rstrip("/")
    
    # Mock endpoints
    respx.get(f"{viya_url}/retrievalAgentManager/agents").mock(
        return_value=httpx.Response(200, json={"items": [{"id": "agent-123"}]})
    )
    respx.get(f"{viya_url}/retrievalAgentManager/agents/agent-123").mock(
        return_value=httpx.Response(200, json={"id": "agent-123", "name": "Agent"})
    )
    respx.get(f"{viya_url}/retrievalAgentManager/sources").mock(
        return_value=httpx.Response(200, json={"items": [{"id": "source-123"}]})
    )
    respx.get(f"{viya_url}/retrievalAgentManager/llms").mock(
        return_value=httpx.Response(200, json={"items": [{"id": "llm-123"}]})
    )
    respx.post(f"{viya_url}/retrievalAgentManager/query").mock(
        return_value=httpx.Response(200, json={"text": "Here is your answer."})
    )

    async with Client(integration_mcp_server) as client:
        # test list agents
        agents = await client.call_tool("list_genai_agents", {})
        assert agents.data["items"][0]["id"] == "agent-123"

        # test get agent
        agent = await client.call_tool("get_genai_agent", {"agent_id": "agent-123"})
        assert agent.data["id"] == "agent-123"

        # test list sources
        sources = await client.call_tool("list_genai_sources", {})
        assert sources.data["items"][0]["id"] == "source-123"

        # test list llms
        llms = await client.call_tool("list_genai_llms", {})
        assert llms.data["items"][0]["id"] == "llm-123"

        # test query agent
        result = await client.call_tool("query_genai_agent", {"agent_id": "agent-123", "query": "Hello"})
        assert result.data["text"] == "Here is your answer."
''')
