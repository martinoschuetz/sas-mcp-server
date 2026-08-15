from sas_mcp_server.helpers.telemetry_helpers import (
    classify_error,
    is_tool_failure_status,
)


def test_classify_error_empty():
    assert classify_error(None) == (None, None)
    assert classify_error("") == (None, None)

def test_classify_error_match():
    # We don't know exact ERROR_TYPE_RULES but we can test HTTP_STATUS_RE
    assert classify_error("Error 404") == ("client_error", 404)
    assert classify_error("Error 500") == ("server_error", 500)

def test_is_tool_failure_status():
    assert is_tool_failure_status("invalid_argument") is True
    assert is_tool_failure_status("not_found") is True
    assert is_tool_failure_status("ok") is False
    assert is_tool_failure_status(None) is False

def test_rescue_unparsed_input():
    from sas_mcp_server.helpers.telemetry_helpers import rescue_unparsed_input
    # test not envelope
    assert rescue_unparsed_input({"a": 1}) == ({"a": 1}, False, None)
    
    # test no raw
    assert rescue_unparsed_input({"__unparsedToolInput": {}}) == ({"__unparsedToolInput": {}}, False, None)
    
    # test raw invalid JSON with goal
    raw_str = 'some invalid json "goal": "do something"'
    assert rescue_unparsed_input({"__unparsedToolInput": {"raw": raw_str}})[1] is False
    
    # test raw valid JSON
    res = rescue_unparsed_input({"__unparsedToolInput": {"raw": '{"valid": "json"}'}})
    assert res == ({"valid": "json"}, True, None)
def test_result_shape():
    from sas_mcp_server.helpers.telemetry_helpers import result_shape
    assert result_shape(None) is None
    assert result_shape({"a": 1}) == {"_type": "object", "_keys": ["a"]}
    assert result_shape([1, 2, 3]) == {"_type": "array", "_items": 3}
    assert result_shape("hello") == {"_type": "string", "_bytes": 5}
    assert result_shape(123) == {"_type": "int"}
    
    class Thrower:
        def __len__(self):
            raise ValueError()

    assert result_shape([Thrower()]) == {"_type": "array", "_items": 1}

def test_args_hash():
    from sas_mcp_server.helpers.telemetry_helpers import args_hash
    # same dicts same hash
    h1 = args_hash({"b": 2, "a": 1})
    h2 = args_hash({"a": 1, "b": 2})
    assert h1 == h2
    assert len(h1) == 12

    class Thrower2:
        def __str__(self):
            raise ValueError()

    # test fallback
    h3 = args_hash({"a": Thrower2()})
    assert len(h3) == 12

def test_scrub_host():
    from sas_mcp_server.helpers.telemetry_helpers import _HOST_MASK, scrub_host, scrub_host_deep
    assert scrub_host("https://host.com/api", "https://host.com") == f"{_HOST_MASK}/api"
    assert scrub_host(123, "https://host.com") == 123
    assert scrub_host("https://host.com/api", None) == "https://host.com/api"

    # test scrub_host_deep
    data = {"url": "https://host.com/api", "nested": ["https://host.com/api"]}
    scrubbed = scrub_host_deep(data, "https://host.com")
    assert scrubbed["url"] == f"{_HOST_MASK}/api"
    assert scrubbed["nested"][0] == f"{_HOST_MASK}/api"
    assert scrub_host_deep(123, "https://host.com") == 123
    assert scrub_host_deep("hello", None) == "hello"
