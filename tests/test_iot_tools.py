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
async def test_launch_data_selection_sends_columns(mock_env_vars):
    """Viya rejects a launch without columns (errorCode 76010); the tables default to the columns' tables."""
    route = respx.post(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/1/launches").mock(
        return_value=Response(201, json={"id": "launch_1", "jobId": "job_1"})
    )
    cols = [{"columnName": "MODEL_CD", "columnTableName": "PRODUCT"},
            {"columnName": "PRIM_LABOR_CD", "columnTableName": "CLAIM"}]
    await launch_data_selection("1", "fake_token", launch_key_dim="PRODUCT", transpose_flag=False, launch_columns=cols)
    body = json.loads(route.calls.last.request.content)
    assert body["launchColumns"] == cols
    assert body["launchColumnTables"] == ["CLAIM", "PRODUCT"]
    assert body["transposeFlag"] == 0
    await launch_data_selection("1", "fake_token", launch_columns=cols, launch_column_tables=["PRODUCT", "CLAIM", "PART"])
    assert json.loads(route.calls.last.request.content)["launchColumnTables"] == ["PRODUCT", "CLAIM", "PART"]

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


@pytest.mark.asyncio
@respx.mock
async def test_rca_lift_dilution_tiebreaker_and_synthesis_tools(mock_env_vars):
    from unittest.mock import AsyncMock, patch

    from fastmcp import Client, FastMCP

    from sas_mcp_server.tools.iot import register

    mcp = FastMCP("iot-rca-synthesis-test")

    async def fake_token(ctx):  # noqa: ARG001
        return "fake_token"

    register(mcp, fake_token)

    # 1. Mock two Emerging Issue runs with the exact same max_score (796.410103) but different lastRunDate & createdBy
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses").mock(
        return_value=Response(
            200,
            json={
                "items": [
                    {
                        "id": "run-older",
                        "name": "Emerging_Issues_Prod_Last4Years_US",
                        "modelName": "EIENTERPRISE_PRODUCT",
                        "status": "Completed",
                        "createdBy": "germsz",
                        "lastRunDate": "2026-04-06T08:00:00Z",
                        "dataSelectionId": "shared-ds-1",
                    },
                    {
                        "id": "run-newer",
                        "name": "Emerging_Issues_Prod_Last4Years_US_2",
                        "modelName": "EIENTERPRISE_PRODUCT",
                        "status": "Completed",
                        "createdBy": "GMS",
                        "lastRunDate": "2026-04-06T12:00:00Z",
                        "dataSelectionId": "shared-ds-1",
                    },
                ]
            },
        )
    )
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/run-older").mock(
        return_value=Response(
            200,
            json={
                "id": "run-older",
                "shortId": "old1",
                "name": "Emerging_Issues_Prod_Last4Years_US",
                "modelName": "EIENTERPRISE_PRODUCT",
                "createdBy": "germsz",
                "lastRunDate": "2026-04-06T08:00:00Z",
                "dataSelectionId": "shared-ds-1",
            },
        )
    )
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/run-newer").mock(
        return_value=Response(
            200,
            json={
                "id": "run-newer",
                "shortId": "new2",
                "name": "Emerging_Issues_Prod_Last4Years_US_2",
                "modelName": "EIENTERPRISE_PRODUCT",
                "createdBy": "GMS",
                "lastRunDate": "2026-04-06T12:00:00Z",
                "dataSelectionId": "shared-ds-1",
            },
        )
    )

    tied_alerts = [{"alert_id": "alert_10", "score": 796.410103, "Events": 10, "Acceleration_AP": 1.19}]
    tied_bundle_log = (
        "BUNDLE_RUN_START:0:EIENTERPRISE_ALERTS_OLD1\n"
        f'BUNDLE_JSON:0: {json.dumps({"SASTableData+EIENTERPRISE_ALERTS_OLD1": tied_alerts})}\n'
        "BUNDLE_RUN_START:1:EIENTERPRISE_ALERTS_NEW2\n"
        f'BUNDLE_JSON:1: {json.dumps({"SASTableData+EIENTERPRISE_ALERTS_NEW2": tied_alerts})}\n'
    )

    lift_log = (
        "LIFT_MAIN:2772|10|44|7\n"
        "LIFT_BROAD:841|7\n"
        "LIFT_COL:MODEL_CD|1|Galacto\n"
        "LIFT_COL:ENGINE_MODEL|1|VE600\n"
        "LIFT_COL:CSTMR_STATE_CD|1|US-GA\n"
        "LIFT_COL:PRIM_LABOR_CD|2|0340G\n"
    )

    # Mocks for synthesize_root_cause_data_selection_tool
    respx.post(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/shared-ds-1/copy").mock(
        return_value=Response(201, json={"id": "rc-ds-final", "name": "Galacto_9-040_RootCause_Final"})
    )
    respx.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/rc-ds-final").mock(
        return_value=Response(
            200,
            headers={"ETag": '"etag-rc-1"'},
            json={"id": "rc-ds-final", "name": "Galacto_9-040_RootCause_Final", "filterCriteria": {"0": []}},
        )
    )
    respx.put(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/rc-ds-final").mock(
        return_value=Response(200, json={"id": "rc-ds-final"})
    )
    respx.post(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/rc-ds-final/launches").mock(
        return_value=Response(201, json={"id": "launch-rc-1", "status": "RUNNING"})
    )
    respx.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/rc-ds-final/launches/launch-rc-1").mock(
        return_value=Response(200, json={"id": "launch-rc-1", "status": "COMPLETED"})
    )
    respx.post(f"{VIYA_ENDPOINT}/folders/folders/folder-mcp-test/members").mock(
        return_value=Response(201, json={"id": "member-1"})
    )
    respx.post(f"{VIYA_ENDPOINT}/iotAnalysis/analyses").mock(
        return_value=Response(201, json={"items": [{"id": "anl-detail-verify", "name": "Detail_Verification"}]})
    )
    respx.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/anl-detail-verify").mock(
        return_value=Response(
            200,
            headers={"ETag": '"etag-anl-1"'},
            json={
                "id": "anl-detail-verify",
                "steps": [
                    {
                        "id": "step-detail-1",
                        "inputParameters": [{"parameterName": "DETAIL_TABLES", "parameterValue": "PRODUCT"}],
                    }
                ],
            },
        )
    )
    respx.put(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/anl-detail-verify").mock(
        return_value=Response(200, json={"id": "anl-detail-verify"})
    )
    respx.post(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/anl-detail-verify/steps/step-detail-1/jobs").mock(
        return_value=Response(201, json={"links": [{"rel": "job", "href": "/jobExecution/jobs/job-detail-1"}]})
    )
    respx.get(f"{VIYA_ENDPOINT}/jobExecution/jobs/job-detail-1").mock(
        return_value=Response(200, json={"id": "job-detail-1", "state": "completed"})
    )

    mock_snippet = AsyncMock(
        side_effect=[
            {"log": tied_bundle_log, "listing": ""},
            {"log": tied_bundle_log, "listing": ""},
            {"log": lift_log, "listing": ""},
        ]
    )

    with patch("sas_mcp_server.tools.iot.run_one_snippet", mock_snippet):
        async with Client(mcp) as client:
            # 1a. Tied max_score automatically picks the newest run (run-newer)
            triage_tied = (await client.call_tool("triage_emerging_issue_runs_tool", {})).data
            assert triage_tied["top_run"]["id"] == "run-newer"
            assert triage_tied["top_run"]["createdBy"] == "GMS"
            assert triage_tied["runs"]["items"][0]["id"] == "run-newer"
            assert triage_tied["runs"]["items"][1]["id"] == "run-older"

            # 1b. created_by_filter isolates runs created by 'germsz'
            triage_creator = (
                await client.call_tool("triage_emerging_issue_runs_tool", {"created_by_filter": "germsz"})
            ).data
            assert triage_creator["top_run"]["id"] == "run-older"
            assert triage_creator["runs"]["total"] == 1

            # 2. evaluate_subpopulation_lift_and_coverage_tool quantifies lift, >=25% gate, dilution, and co-linearity
            lift_res = (
                await client.call_tool(
                    "evaluate_subpopulation_lift_and_coverage_tool",
                    {
                        "table_name": "DS_ALERT_10",
                        "alert_where": "PRIM_REPL_PART_CD = '9-040'",
                        "hypothesis_where": "SELLING_DEALER_CD = 'A01103'",
                        "broad_1d_where": "CSTMR_STATE_CD = 'US-GA'",
                        "candidate_columns": ["MODEL_CD", "ENGINE_MODEL", "CSTMR_STATE_CD", "PRIM_LABOR_CD"],
                    },
                )
            ).data
            assert lift_res["hypothesis_metrics"]["cohort_failure_rate_pct"] == 15.91
            assert lift_res["hypothesis_metrics"]["alert_unit_coverage_pct"] == 70.0
            assert lift_res["hypothesis_metrics"]["passes_25pct_root_cause_gate"] is True
            assert lift_res["hypothesis_metrics"]["verdict"] == "PRIMARY_ROOT_CAUSE"
            assert lift_res["denominator_dilution_analysis"]["broad_1d_failure_rate_pct"] == 0.83
            assert lift_res["denominator_dilution_analysis"]["dilution_factor"] == 19.11
            pinned_names = [c["column"] for c in lift_res["co_linear_pinned_attributes"]]
            assert "ENGINE_MODEL" in pinned_names
            assert "CSTMR_STATE_CD" in pinned_names
            assert "PRIM_LABOR_CD" in lift_res["orthogonal_attributes"]

            # 3. synthesize_root_cause_data_selection_tool creates one consolidated DS + Detail verification
            synth_res = (
                await client.call_tool(
                    "synthesize_root_cause_data_selection_tool",
                    {
                        "parent_data_selection_id": "shared-ds-1",
                        "new_name": "Galacto_9-040_RootCause_Final",
                        "start_date": "2019-10-01",
                        "end_date": "2019-12-31",
                        "folder_id": "folder-mcp-test",
                        "filters": [
                            {"columnName": "MODEL_CD", "component": "PRODUCT", "values": ["Galacto"]},
                            {"columnName": "SELLING_DEALER_CD", "component": "PRODUCT", "values": ["A01103"]},
                            {"columnName": "PRIM_REPL_PART_CD", "component": "CLAIM", "values": ["9-040"]},
                        ],
                    },
                )
            ).data
            assert synth_res["status"] == "success"
            assert synth_res["data_selection_id"] == "rc-ds-final"
            assert synth_res["date_criteria"]["startDate"] == "2019-10-01"
            assert len(synth_res["applied_filters"]) == 3
            assert len(synth_res["verification_analyses"]) == 1
            assert synth_res["verification_analyses"][0]["type"] == "DETAIL_PRODUCT"



@pytest.mark.asyncio
@respx.mock
async def test_launch_data_selection_mcp_tools_schema_and_execution(mock_env_vars):
    """Deep test of launch_data_selection_tool and launch_data_selection_and_wait_tool:
    1. Verifies FastMCP list_tools exposes launch_columns and launch_column_tables as optional parameters.
    2. Verifies launch_data_selection_tool derives sorted launchColumnTables from 11 FQA columns and preserves optional labels.
    3. Verifies launch_data_selection_and_wait_tool forwards launch_columns and explicit launch_column_tables and polls jobId.
    4. Verifies backward-compatible invocation when launch_columns and launch_column_tables are omitted.
    """
    from fastmcp import Client, FastMCP
    from sas_mcp_server.tools.iot import register

    mcp = FastMCP("test-launch-columns")

    async def fake_token(ctx):  # noqa: ARG001
        return "fake_token"

    register(mcp, fake_token)

    launch_route = respx.post(
        f"{VIYA_ENDPOINT}/dataSelection/dataSelections/ds-wb1-12345678-90ab-cdef/launches"
    ).mock(return_value=Response(201, json={"id": "launch_wb1", "jobId": "job_wb1"}))

    job_route = respx.get(f"{VIYA_ENDPOINT}/jobExecution/jobs/job_wb1").mock(
        return_value=Response(200, json={"id": "job_wb1", "state": "completed"})
    )

    fqa_11_columns = [
        {"columnName": "PRODUCTION_DATE", "columnTableName": "PRODUCT", "columnNameLabel": "Production Date", "columnTableNameLabel": "Product"},
        {"columnName": "SALE_DATE", "columnTableName": "PRODUCT"},
        {"columnName": "MODEL_YEAR", "columnTableName": "PRODUCT"},
        {"columnName": "MODEL_CD", "columnTableName": "PRODUCT"},
        {"columnName": "ENGINE_MODEL", "columnTableName": "PRODUCT"},
        {"columnName": "ASSEMBLY_PLANT_CD", "columnTableName": "PRODUCT"},
        {"columnName": "SELLING_DEALER_CD", "columnTableName": "PRODUCT"},
        {"columnName": "CSTMR_STATE_CD", "columnTableName": "PRODUCT"},
        {"columnName": "PRIM_REPL_PART_CD", "columnTableName": "CLAIM"},
        {"columnName": "PRIM_LABOR_CD", "columnTableName": "CLAIM"},
        {"columnName": "REPL_PART_CD", "columnTableName": "PART"},
    ]

    async with Client(mcp) as client:
        # 1. Check MCP tool schema for both tools (Acceptance Check 1)
        tools = await client.list_tools()
        tools_by_name = {t.name: t for t in tools}
        for tool_name in ("launch_data_selection_tool", "launch_data_selection_and_wait_tool"):
            assert tool_name in tools_by_name
            schema = tools_by_name[tool_name].inputSchema
            props = schema.get("properties", {})
            required = schema.get("required", [])
            assert "launch_columns" in props
            assert "launch_column_tables" in props
            assert "launch_columns" not in required
            assert "launch_column_tables" not in required
            assert "76010" in props["launch_columns"].get("description", "")
            assert "launch_columns" in props["launch_column_tables"].get("description", "")

        # 2. Call launch_data_selection_tool with 11 FQA columns (derived launchColumnTables)
        res1 = (
            await client.call_tool(
                "launch_data_selection_tool",
                {
                    "selection_id": "ds-wb1-12345678-90ab-cdef",
                    "launch_key_dim": "PRODUCT",
                    "transpose_flag": False,
                    "launch_columns": fqa_11_columns,
                },
            )
        ).data
        assert res1["id"] == "launch_wb1"
        body1 = json.loads(launch_route.calls.last.request.content)
        assert body1["tableName"] == "DS_ds_wb1_12345678_90ab_cde"
        assert body1["launchAppName"] == "CAS"
        assert body1["transposeFlag"] == 0
        assert body1["launchKeyDim"] == "PRODUCT"
        assert body1["launchColumnTables"] == ["CLAIM", "PART", "PRODUCT"]
        assert body1["launchColumns"] == fqa_11_columns

        # 3. Call launch_data_selection_and_wait_tool with explicit launch_column_tables order and custom table_name
        res2 = (
            await client.call_tool(
                "launch_data_selection_and_wait_tool",
                {
                    "selection_id": "ds-wb1-12345678-90ab-cdef",
                    "table_name": "DS_CUSTOM_WB1",
                    "launch_key_dim": "PRODUCT",
                    "transpose_flag": True,
                    "launch_columns": fqa_11_columns,
                    "launch_column_tables": ["PRODUCT", "CLAIM", "PART"],
                },
            )
        ).data
        assert job_route.called
        assert res2["state"] == "completed"
        body2 = json.loads(launch_route.calls.last.request.content)
        assert body2["tableName"] == "DS_CUSTOM_WB1"
        assert body2["transposeFlag"] == 1
        assert body2["launchColumnTables"] == ["PRODUCT", "CLAIM", "PART"]
        assert body2["launchColumns"] == fqa_11_columns

        # 4. Backward compatibility: omitting launch_columns & launch_column_tables sends []
        await client.call_tool(
            "launch_data_selection_tool",
            {"selection_id": "ds-wb1-12345678-90ab-cdef"},
        )
        body3 = json.loads(launch_route.calls.last.request.content)
        assert body3["launchColumns"] == []
        assert body3["launchColumnTables"] == []
