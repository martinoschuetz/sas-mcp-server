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


def test_sort_and_paginate_top_10_helpers():
    from sas_mcp_server.tools.iot import _annotate_fqa_alert, _paginate_sorted_items

    raw_alerts = [
        {"alert_id": f"alert_{i}", "score": float(i * 10), "Events": i, "Acceleration_AP": 1.35}
        for i in range(1, 16)
    ]
    annotated = [_annotate_fqa_alert(a) for a in raw_alerts]
    page1 = _paginate_sorted_items(
        annotated, start=0, limit=10, sort_by="score", sort_order="desc", item_label="alerts"
    )
    assert page1["total"] == 15
    assert page1["returned_count"] == 10
    assert len(page1["items"]) == 10
    assert page1["items"][0]["alert_id"] == "alert_15"
    assert page1["items"][0]["score"] == 150.0
    assert page1["items"][0]["failure_mode_hint"] == "wear_out_aging_accumulation"
    assert page1["items"][9]["alert_id"] == "alert_6"
    assert page1["has_more"] is True
    assert page1["remaining_count"] == 5
    assert page1["next_start"] == 10
    assert "5 more available" in page1["pagination_hint"]

    page2 = _paginate_sorted_items(
        annotated, start=10, limit=10, sort_by="score", sort_order="desc", item_label="alerts"
    )
    assert len(page2["items"]) == 5
    assert page2["has_more"] is False
    assert page2["remaining_count"] == 0
    assert page2["next_start"] is None


@pytest.mark.asyncio
@respx.mock
async def test_bundled_fqa_tools_single_backend_calls(mock_env_vars):
    from unittest.mock import AsyncMock, patch

    from fastmcp import Client, FastMCP

    from sas_mcp_server.tools.iot import register

    mcp = FastMCP("iot-bundled-test")

    async def fake_token(ctx):  # noqa: ARG001
        return "fake_token"

    register(mcp, fake_token)

    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses").mock(
        return_value=Response(
            200,
            json={
                "items": [
                    {
                        "id": "run-low",
                        "name": "EI Run Low",
                        "modelName": "EIENTERPRISE_PRODUCT",
                        "status": "Completed",
                        "lastRunDate": "2026-01-01",
                    },
                    {
                        "id": "run-high",
                        "name": "EI Run High",
                        "modelName": "EIENTERPRISE_PRODUCT",
                        "status": "Completed",
                        "lastRunDate": "2026-01-02",
                    },
                ]
            },
        )
    )
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/run-low").mock(
        return_value=Response(
            200,
            json={"id": "run-low", "shortId": "low1", "name": "EI Run Low", "modelName": "EIENTERPRISE_PRODUCT"},
        )
    )
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/run-high").mock(
        return_value=Response(
            200,
            json={"id": "run-high", "shortId": "high1", "name": "EI Run High", "modelName": "EIENTERPRISE_PRODUCT"},
        )
    )

    high_alerts = [
        {
            "alert_id": f"alert_{idx}",
            "alert_type": "PRODUCTIONPERIOD",
            "score": float(idx * 50),
            "cost_score": float(idx * 500),
            "Events": idx + 5,
            "Acceleration_AP": 1.4 if idx % 2 == 0 else 0.7,
            "T05": 90,
            "T10": 150,
        }
        for idx in range(1, 15)
    ]
    low_payload = {"SASTableData+EIENTERPRISE_ALERTS_LOW1": [{"alert_id": "alert_1", "score": 42.5, "Events": 8}]}
    bundled_log = (
        "BUNDLE_RUN_START:0:EIENTERPRISE_ALERTS_LOW1\n"
        f"BUNDLE_JSON:0: {json.dumps(low_payload)}\n"
        "BUNDLE_RUN_START:1:EIENTERPRISE_ALERTS_HIGH1\n"
        f'BUNDLE_JSON:1: {json.dumps({"SASTableData+EIENTERPRISE_ALERTS_HIGH1": high_alerts})}\n'
    )

    ctx_log = (
        f'CTX_ALERTS: {json.dumps({"SASTableData+ALERTS": high_alerts})}\n'
        'CTX_DETAILS: {"SASTableData+DETAILS": [{"alert_id": "alert_14", "lag": 1, "actual": 12, "C_ijk": 5.2}]}\n'
        'CTX_WUMKR: {"SASTableData+WUMKR": [{"alert_id": "alert_14", "Events": 19, "TIS": 3}]}\n'
        'CTX_BASELINE: {"SASTableData+BASELINE": [{"alert_id": "alert_14", "TIS": 1, "expected": 0.01}]}\n'
    )

    preflight_log = (
        "PREFLIGHT_META:TOTAL_ROWS=1250\n"
        "PREFLIGHT_META:DISTINCT_UNITS=420\n"
        "PREFLIGHT_VAR:MODEL_CD|1|0\n"
        "PREFLIGHT_VAR:PLANT_CD|12|0\n"
        "PREFLIGHT_VAR:DEALER_CD|650|5\n"
        "PREFLIGHT_FR:400|240\n"
        "PREFLIGHT_TM:85\n"
    )

    single_run_log = "\n".join(
        f"JSON_OUT: {line}"
        for line in json.dumps({"SASTableData+EIENTERPRISE_ALERTS_HIGH1": high_alerts}, indent=2).splitlines()
    )

    mock_snippet = AsyncMock(
        side_effect=[
            {"log": bundled_log, "listing": ""},
            {"log": ctx_log, "listing": ""},
            {"log": preflight_log, "listing": ""},
            {"log": single_run_log, "listing": ""},
        ]
    )

    with patch("sas_mcp_server.tools.iot.run_one_snippet", mock_snippet):
        async with Client(mcp) as client:
            # 1. Bundled multi-run triage executes in a single SAS snippet call
            triage_res = (await client.call_tool("triage_emerging_issue_runs_tool", {})).data
            assert mock_snippet.call_count == 1
            assert triage_res["top_run"]["id"] == "run-high"
            assert triage_res["top_run"]["max_score"] == 700.0
            alerts_page = triage_res["selected_run_alerts"]
            assert len(alerts_page["items"]) == 10
            assert alerts_page["items"][0]["alert_id"] == "alert_14"
            assert alerts_page["items"][0]["score"] == 700.0
            assert alerts_page["has_more"] is True
            assert alerts_page["remaining_count"] == 4
            assert alerts_page["next_start"] == 10

            # 2. Bundled 4-question alert context inspection executes in a single SAS snippet call
            ctx_res = (
                await client.call_tool("inspect_emerging_issue_alert_context_tool", {"analysis_id": "run-high"})
            ).data
            assert mock_snippet.call_count == 2
            assert ctx_res["alert_id"] == "alert_14"
            assert (
                ctx_res["triage_4_questions"]["q2_third_time_dimension_sales_lag"]["verdict"]
                == "manufacturing_or_early_release_spike_confirmed"
            )
            assert ctx_res["details_sales_lag"]["total"] == 1

            # 3. Bundled preflight checks execute in a single SAS snippet call
            pf_res = (
                await client.call_tool("run_fqa_preflight_checks_tool", {"table_name": "CLAIM_SELECTION_1"})
            ).data
            assert mock_snippet.call_count == 3
            assert pf_res["population_summary"]["total_rows"] == 1250
            assert "MODEL_CD" in pf_res["population_summary"]["pinned_single_level_columns"]
            assert "DEALER_CD" in pf_res["population_summary"]["high_cardinality_over_500_columns"]
            assert pf_res["failure_relationships_gate"]["ready"] is True
            assert pf_res["text_mining_gate"]["ready_recommended_50"] is True

            # 4. Bundled Common Cause 4-quadrant screening
            cc_res = (
                await client.call_tool("screen_common_cause_candidates_tool", {"analysis_id": "run-high"})
            ).data
            assert mock_snippet.call_count == 4
            assert cc_res["candidates"]["returned_count"] == 10
            assert cc_res["candidates"]["has_more"] is True
            assert "HIGH_RATE_WEARING_OUT" in cc_res["quadrant_counts"]


