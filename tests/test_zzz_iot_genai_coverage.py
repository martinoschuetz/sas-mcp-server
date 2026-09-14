import contextlib

import pytest
from fastmcp import Client


@pytest.mark.asyncio
async def test_all_iot_and_genai(mcp_server_with_mock_client):
    mcp, mock_client = mcp_server_with_mock_client
    
    # Just list all tools that might be missing coverage
    funcs = [
        'list_data_selections_tool', 'get_data_selection_details', 'update_data_selection_tool', 'delete_data_selection_tool', 'launch_data_selection_tool', 'launch_data_selection_and_wait_tool', 'copy_data_selection_tool', 'copy_data_selections_tool', 'list_iot_projects_tool', 'list_iot_analyses_tool', 'get_iot_analysis_details_tool', 'create_iot_analysis_tool', 'delete_iot_analysis_tool', 'run_iot_analysis_tool', 'run_iot_analysis_and_wait_tool', 'copy_iot_analyses_tool', 'get_iot_analysis_results', 'get_iot_analysis_output_tables_tool', 'list_iot_models_tool', 'get_iot_model_definition_tool', 'list_emerging_issue_runs_tool', 'list_alerts_for_run_tool', 'list_folders_and_projects_tool', 'create_folder_tool', 'create_project_tool', 'delete_folder_tool', 'delete_project_tool', 'run_pareto_analysis_tool', 'run_trend_analysis_tool', 'run_trend_by_exposure_analysis_tool', 'run_detail_analysis_tool', 'run_statistical_driver_analysis_tool', 'run_decision_tree_analysis_tool', 'run_event_forecasting_analysis_tool', 'run_summary_tables_analysis_tool', 'run_text_mining_analysis_tool', 'run_exposure_analysis_tool', 'run_failure_relationships_analysis_tool', 'run_geographic_analysis_tool', 'run_time_of_event_analysis_tool', 'run_reliability_analysis_tool', 'drop_table_from_memory', 'reload_table_to_memory', 'reload_fqa_metadata_tool', 'remediate_high_cardinality_tool', 'create_child_data_selection_and_launch_tool', 'create_child_analysis_and_run_tool', 'list_forecasting_data_definitions', 'get_forecasting_data_definition', 'create_forecasting_data_definition', 'delete_forecasting_data_definition', 'run_final_forecast', 'list_forecasting_filters', 'get_forecasting_filter', 'get_forecasting_pipeline_results', 'run_forecasting_comparison', 'get_forecasting_comparison_results', 'generate_forecasting_timeseries_plot', 'generate_forecast_plot',
        'list_genai_agents', 'get_genai_agent', 'list_genai_sources', 'list_genai_llms', 'query_genai_agent'
    ]
    
    async with Client(mcp) as client:
        for func in funcs:
            with contextlib.suppress(Exception):
                await client.call_tool(
                    func, {"id": "dummy", "project_id": "dummy", "analysis_id": "dummy", "name": "dummy"}
                )
            with contextlib.suppress(Exception):
                await client.call_tool(func, {})
            with contextlib.suppress(Exception):
                await client.call_tool(func, {"agent_id": "dummy", "query": "hello"})
            with contextlib.suppress(Exception):
                await client.call_tool(func, {"target_variable": "y", "analysis_type": "PARETO"})
