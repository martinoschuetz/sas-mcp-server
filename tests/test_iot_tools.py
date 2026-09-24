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
