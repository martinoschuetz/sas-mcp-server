# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import json

import pytest
import respx
from httpx import Response

from sas_mcp_server.config import (
    AIOT_LAUNCH_KEY_DIM,
    AIOT_LAUNCH_TRANSPOSE,
    VIYA_ENDPOINT,
)
from sas_mcp_server.tools.iot import (
    get_data_selection,
    get_iot_analysis_job,
    launch_data_selection,
    launch_data_selection_and_wait,
    list_data_selections,
    list_iot_analyses,
    list_iot_models,
    run_iot_analysis,
)


@pytest.mark.asyncio
@respx.mock
async def test_list_data_selections(mock_env_vars):
    respx.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections").mock(
        return_value=Response(200, json={"items": [{"id": "1", "name": "Selection 1"}]})
    )
    result = await list_data_selections("fake_token")
    assert "items" in result
    assert result["items"][0]["name"] == "Selection 1"

@pytest.mark.asyncio
@respx.mock
async def test_get_data_selection(mock_env_vars):
    respx.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/1").mock(
        return_value=Response(200, json={"id": "1", "name": "Selection 1"})
    )
    result = await get_data_selection("1", "fake_token")
    assert result["id"] == "1"
    assert result["name"] == "Selection 1"

@pytest.mark.asyncio
@respx.mock
async def test_launch_data_selection(mock_env_vars):
    respx.post(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/1/launches").mock(
        return_value=Response(201, json={"id": "job_1", "status": "pending"})
    )
    result = await launch_data_selection("1", "fake_token")
    assert result["id"] == "job_1"

@pytest.mark.asyncio
@respx.mock
async def test_launch_data_selection_sends_launch_payload(mock_env_vars):
    route = respx.post(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/1/launches").mock(
        return_value=Response(201, json={"id": "launch_1", "jobId": "job_1"})
    )
    await launch_data_selection("1", "fake_token", launch_key_dim="BATCH")
    body = json.loads(route.calls.last.request.content)
    assert body["tableName"]
    assert body["launchAppName"] == "CAS"
    assert body["launchKeyDim"] == "BATCH"

@pytest.mark.asyncio
@respx.mock
async def test_launch_data_selection_defaults_key_dim(mock_env_vars):
    """A caller that names no key dimension still sends one -- omitting it 400s."""
    route = respx.post(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/1/launches").mock(
        return_value=Response(201, json={"id": "launch_1", "jobId": "job_1"})
    )
    await launch_data_selection("1", "fake_token")
    body = json.loads(route.calls.last.request.content)
    assert body["launchKeyDim"] == AIOT_LAUNCH_KEY_DIM
    assert body["transposeFlag"] == int(AIOT_LAUNCH_TRANSPOSE)

@pytest.mark.asyncio
@respx.mock
async def test_launch_data_selection_and_wait_polls_job_id(mock_env_vars):
    respx.post(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/1/launches").mock(
        return_value=Response(201, json={"id": "launch_1", "jobId": "job_1"})
    )
    job_route = respx.get(f"{VIYA_ENDPOINT}/jobExecution/jobs/job_1").mock(
        return_value=Response(200, json={"id": "job_1", "state": "completed"})
    )
    result = await launch_data_selection_and_wait("1", "fake_token")
    assert job_route.called
    assert result["state"] == "completed"

@pytest.mark.asyncio
@respx.mock
async def test_list_iot_analyses(mock_env_vars):
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses").mock(
        return_value=Response(200, json={"items": [{"id": "a1", "name": "Analysis 1"}]})
    )
    result = await list_iot_analyses("fake_token")
    assert result["items"][0]["id"] == "a1"

@pytest.mark.asyncio
@respx.mock
async def test_run_iot_analysis(mock_env_vars):
    respx.post(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/a1/jobs").mock(
        return_value=Response(201, json={"id": "job_a1"})
    )
    result = await run_iot_analysis("a1", "fake_token")
    assert result["id"] == "job_a1"

@pytest.mark.asyncio
@respx.mock
async def test_get_iot_analysis_job(mock_env_vars):
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/a1/jobs/job_a1").mock(
        return_value=Response(200, json={"id": "job_a1", "status": "completed"})
    )
    result = await get_iot_analysis_job("a1", "job_a1", "fake_token")
    assert result["status"] == "completed"

@pytest.mark.asyncio
@respx.mock
async def test_list_iot_models(mock_env_vars):
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysisModels/models").mock(
        return_value=Response(200, json={"items": [{"id": "m1", "name": "Model 1"}]})
    )
    result = await list_iot_models("fake_token")
    assert result["items"][0]["id"] == "m1"


@pytest.mark.asyncio
@respx.mock
async def test_data_selection_cache_isolated_by_user_and_invalidated_on_delete(mock_env_vars):
    from sas_mcp_server.tools.iot import data_selection_cache, delete_data_selection

    data_selection_cache.clear()
    route = respx.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections").mock(
        side_effect=[
            Response(200, json={"items": [{"id": "1", "name": "Alice DS"}]}),
            Response(200, json={"items": [{"id": "2", "name": "Bob DS"}]}),
            Response(200, json={"items": [{"id": "3", "name": "Alice DS Refreshed"}]}),
        ]
    )
    respx.delete(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/1").mock(
        return_value=Response(204)
    )

    r_alice = await list_data_selections("token_alice")
    r_bob = await list_data_selections("token_bob")
    assert r_alice["items"][0]["name"] == "Alice DS"
    assert r_bob["items"][0]["name"] == "Bob DS"
    assert route.call_count == 2

    await delete_data_selection("1", "token_alice")
    assert len(data_selection_cache) == 0
    r_alice_after = await list_data_selections("token_alice")
    assert r_alice_after["items"][0]["name"] == "Alice DS Refreshed"


@pytest.mark.asyncio
@respx.mock
async def test_poll_job_handles_canceled_and_timeout(mock_env_vars):
    from sas_mcp_server.tools.iot import poll_job

    respx.get(f"{VIYA_ENDPOINT}/jobExecution/jobs/j_canceled").mock(
        return_value=Response(200, json={"id": "j_canceled", "state": "canceled"})
    )
    res = await poll_job("/jobExecution/jobs/j_canceled", "fake_token")
    assert res["state"] == "canceled"

    respx.get(f"{VIYA_ENDPOINT}/jobExecution/jobs/j_stuck").mock(
        return_value=Response(200, json={"id": "j_stuck", "state": "running"})
    )
    with pytest.raises(TimeoutError):
        await poll_job("/jobExecution/jobs/j_stuck", "fake_token", poll_interval=0.01, timeout=0.0)


def test_validate_sas_identifier_and_safe_path():
    from sas_mcp_server.tools.iot import _validate_safe_path, _validate_sas_identifier

    assert _validate_sas_identifier("QASMartStore") == "QASMartStore"
    with pytest.raises(ValueError):
        _validate_sas_identifier('foo"; quit; data _null_;')
    assert _validate_safe_path("/export/sas-viya/homes/user/FQA") == "/export/sas-viya/homes/user/FQA"
    with pytest.raises(ValueError):
        _validate_safe_path("/export/../etc/passwd")
    with pytest.raises(ValueError):
        _validate_safe_path("/export/foo'; % abort;")


@pytest.mark.asyncio
@respx.mock
async def test_forecasting_and_fqa_tools_via_fastmcp(mock_env_vars):
    from fastmcp import Client, FastMCP
    from sas_mcp_server.tools.iot import register

    mcp = FastMCP("iot-test")

    async def fake_token(ctx):  # noqa: ARG001
        return "fake_token"

    register(mcp, fake_token)

    respx.get(f"{VIYA_ENDPOINT}/forecastingGateway/dataDefinitions").mock(
        return_value=Response(200, json={"items": [{"id": "dd1"}], "count": 1})
    )
    respx.get(f"{VIYA_ENDPOINT}/forecastingGateway/filters/f1").mock(
        return_value=Response(200, json={"id": "f1", "name": "Filter 1"})
    )
    respx.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/ds-1").mock(
        return_value=Response(
            200,
            json={
                "id": "ds-1",
                "launchColumns": [{"columnTableName": "PRODUCT", "columnName": "MODEL_CD"}],
            },
        )
    )
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses").mock(
        return_value=Response(
            200,
            json={"items": [{"id": "an-child", "dataSelectionId": "ds-1"}]},
        )
    )
    del_an = respx.delete(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/an-child").mock(
        return_value=Response(204)
    )
    del_ds = respx.delete(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/ds-1").mock(
        return_value=Response(204)
    )

    async with Client(mcp) as client:
        dd_res = (await client.call_tool("list_forecasting_data_definitions", {"limit": 5})).data
        assert dd_res["items"] == [{"id": "dd1"}]
        assert dd_res["count"] == 1

        flt_res = (await client.call_tool("get_forecasting_filter", {"filter_id": "f1"})).data
        assert flt_res["id"] == "f1"

        vars_res = (
            await client.call_tool(
                "list_fqa_data_model_variables_tool", {"data_selection_id": "ds-1"}
            )
        ).data
        assert "PRODUCT.MODEL_CD" in vars_res["variables"]

        force_res = (
            await client.call_tool(
                "force_delete_fqa_object_tool", {"data_selection_id": "ds-1"}
            )
        ).data
        assert force_res["status"] == "FORCE_DELETED"
        assert force_res["deleted_analyses"] == ["an-child"]
        assert del_an.called
        assert del_ds.called

