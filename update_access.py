import os

missing = ['delete_forecasting_data_definition', 'run_statistical_driver_analysis_tool', 'delete_data_selection_tool', 'list_folders_and_projects_tool', 'run_iot_analysis_and_wait_tool', 'launch_data_selection_tool', 'get_iot_analysis_results', 'run_exposure_analysis_tool', 'remediate_high_cardinality_tool', 'list_alerts_for_run_tool', 'create_forecasting_data_definition', 'run_pareto_analysis_tool', 'get_forecasting_filter', 'run_decision_tree_analysis_tool', 'copy_data_selection_tool', 'update_data_selection_tool', 'get_forecasting_pipeline_results', 'reload_fqa_metadata_tool', 'create_child_data_selection_and_launch_tool', 'list_iot_analyses_tool', 'get_iot_analysis_details_tool', 'get_forecasting_comparison_results', 'run_event_forecasting_analysis_tool', 'list_forecasting_data_definitions', 'create_child_analysis_and_run_tool', 'drop_table_from_memory', 'create_iot_analysis_tool', 'run_trend_analysis_tool', 'delete_iot_analysis_tool', 'create_project_tool', 'copy_data_selections_tool', 'list_data_selections_tool', 'set_data_selection_date_range_tool', 'launch_data_selection_and_wait_tool', 'get_iot_analysis_output_tables_tool', 'create_folder_tool', 'run_summary_tables_analysis_tool', 'run_failure_relationships_analysis_tool', 'list_iot_models_tool', 'run_detail_analysis_tool', 'delete_project_tool', 'get_forecasting_data_definition', 'get_data_selection_details', 'run_geographic_analysis_tool', 'run_time_of_event_analysis_tool', 'run_reliability_analysis_tool', 'reload_table_to_memory', 'run_forecasting_comparison', 'delete_folder_tool', 'run_trend_by_exposure_analysis_tool', 'run_iot_analysis_tool', 'list_iot_projects_tool', 'get_iot_model_definition_tool', 'generate_forecasting_timeseries_plot', 'generate_forecast_plot', 'list_forecasting_filters', 'copy_iot_analyses_tool', 'run_text_mining_analysis_tool', 'list_emerging_issue_runs_tool', 'run_final_forecast']

read = []
write = []
for t in sorted(missing):
    if t.startswith(('list_', 'get_', 'describe_', 'search_', 'find_')):
        read.append(f'        "{t}",')
    else:
        write.append(f'        "{t}",')

with open('src/sas_mcp_server/tools/_access.py', 'r') as f:
    c = f.read()

read_insert = '\n'.join(read) + '\n    }\n)'
write_insert = '\n'.join(write) + '\n    }\n)'

c = c.replace('    }\n)\n\n# Every tool that is NOT read-only', read_insert + '\n\n# Every tool that is NOT read-only')
c = c.replace('    }\n)\n\n\n# --- registration', write_insert + '\n    }\n)\n\n\n# --- registration')

with open('src/sas_mcp_server/tools/_access.py', 'w') as f:
    f.write(c)

print('Added missing tools to _access.py')
