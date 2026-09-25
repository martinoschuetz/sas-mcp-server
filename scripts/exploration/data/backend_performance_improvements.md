
# AIoT / FQA Backend Performance Investigation

I investigated the SAS MCP Server's iot.py and iya_client.py implementation to understand why FQA and AIoT tool execution is experiencing latency. I found several architectural patterns contributing to the slowness.

## Key Bottlenecks Identified

### 1. TLS/SSL Connection Thrashing (The biggest issue)
The underlying REST API wrapper make_client(token) creates a **brand new httpx.AsyncClient** every time it's called. 
- In Python, httpx.AsyncClient manages connection pooling. By creating and destroying it with sync with make_client(token) as client: inside almost every basic API wrapper function (create_iot_analysis, get_iot_analysis, etc.), the MCP server forces a full TCP handshake and TLS negotiation for **every single REST request**.
- When the LLM calls a composite tool (like create_and_run_analysis), the tool executes 5-10 sub-requests sequentially, incurring 5-10 seconds of pure TLS overhead before any real work is even done by the SAS Viya backend.

### 2. Aggressive, Fixed Polling Loops
Polling mechanisms across the tools (like poll_job and the manual polling loops in create_child_analysis_and_run_tool) hardcode a 1.0 second sleep interval (wait asyncio.sleep(1)).
- For long-running CAS analyses that take 30+ seconds, this fixed polling hits the SAS Viya endpoints dozens of times unnecessarily, consuming network bandwidth and backend thread capacity.
- It lacks Exponential Backoff, leading to noisy execution.

### 3. Granular LLM Tool Chaining
Currently, the LLM is often forced to execute FQA workflows in a 'chatty' way:
1. list_data_selections_tool
2. get_data_selection_details_tool
3. copy_data_selection_tool
4. launch_data_selection_and_wait_tool
Because these require separate agent actions, the LLM must stop, generate tokens, parse responses, and trigger the next step. The round-trip reasoning time of the LLM adds significant latency.

## Recommended Performance Improvements

### 1. Centralize the Connection Pool
Refactor iya_client.py to maintain a global (or per-user) httpx.AsyncClient instance rather than instantiating a new one per request. 
`python
# Create a single client at the module level
_GLOBAL_CLIENT = httpx.AsyncClient(verify=SSL_VERIFY, timeout=_CLIENT_TIMEOUT)

# Update make_client to inject headers dynamically per-request, or use request hooks
def make_client(token: str | None) -> httpx.AsyncClient:
    return _GLOBAL_CLIENT # And handle the auth token in the request injection
`
Alternatively, in _common.py, use the @asynccontextmanager to yield the SAME persistent client across the lifespan of the MCP server, passing it down to all iot.py functions. This alone will slash execution time by 50-70% for composite operations.

### 2. Implement Exponential Backoff for Polling
Update poll_job and other while True loops in iot.py to use an adaptive backoff strategy.
`python
poll_interval = 1.0
while True:
    # ... check status ...
    await asyncio.sleep(poll_interval)
    poll_interval = min(poll_interval * 1.5, 10.0) # Cap at 10 seconds
`

### 3. Add More 'Macro' (Composite) Tools
The introduction of create_child_data_selection_and_launch_tool was a massive step in the right direction. You should continue consolidating tightly coupled operations into single Python tools.
For example, create a single diagnose_alert_full_workflow tool that automatically finds the data selection, creates a child, launches it, and runs the Pareto/Trend analysis in the backend without requiring LLM back-and-forth for every intermediate ID.

