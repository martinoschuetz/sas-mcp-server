"""Tests for the knowledge-base tools (read / list / search, path-traversal guard)."""

import pytest
from fastmcp import Client, FastMCP

import sas_mcp_server.tools.knowledge as knowledge


@pytest.fixture
def kb(tmp_path, monkeypatch):
    root = tmp_path / "knowledge"
    esp = root / "esp"
    (esp / "references" / "docs").mkdir(parents=True)
    (esp / "templates").mkdir()
    (esp / "SKILL.md").write_text("# ESP skill\n", encoding="utf-8")
    (esp / "references" / "kafka_connector.md").write_text(
        "# Kafka\nset disableespmetaconsumer=true\n", encoding="utf-8"
    )
    (esp / "references" / "docs" / "espca.txt").write_text(
        "".join(f"line {i} commitblocks\n" for i in range(1, 301)), encoding="utf-8"
    )
    (esp / "templates" / "kafka_json_to_cas.xml").write_text("<project name='x'/>\n", encoding="utf-8")
    (esp / "templates" / "blob.bin").write_bytes(b"\x00\x01")
    (root / "fqa").mkdir()
    (tmp_path / "secret.md").write_text("TOP SECRET\n", encoding="utf-8")
    monkeypatch.setattr(knowledge, "KNOWLEDGE_DIR", root)
    return root


@pytest.fixture
async def client(kb):
    mcp = FastMCP("kb-test")

    async def get_token(ctx):  # noqa: ARG001
        return "t"

    knowledge.register(mcp, get_token)
    async with Client(mcp) as c:
        yield c


async def call(client, name, args):
    res = await client.call_tool(name, args)
    return res.content[0].text


async def test_list_domains(client):
    text = await call(client, "list_knowledge_domains", {})
    assert "- esp" in text
    assert "- fqa" in text


async def test_list_domains_missing_dir(client, monkeypatch, tmp_path):
    monkeypatch.setattr(knowledge, "KNOWLEDGE_DIR", tmp_path / "nope")
    assert await call(client, "list_knowledge_domains", {}) == "Knowledge directory not found."


async def test_list_domains_empty(client, monkeypatch, tmp_path):
    empty = tmp_path / "empty"
    empty.mkdir()
    monkeypatch.setattr(knowledge, "KNOWLEDGE_DIR", empty)
    assert await call(client, "list_knowledge_domains", {}) == "No knowledge domains found."


async def test_read_markdown_without_extension(client):
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "references/kafka_connector"})
    assert "disableespmetaconsumer" in text


async def test_read_backslash_topic(client):
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "references\\kafka_connector"})
    assert "# Kafka" in text


async def test_read_template_with_extension(client):
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "templates/kafka_json_to_cas.xml"})
    assert "<project" in text


async def test_read_large_file_is_paged(client):
    first = await call(
        client,
        "read_knowledge_topic",
        {"domain": "esp", "topic": "references/docs/espca.txt", "max_chars": 1000},
    )
    assert first.startswith("[lines 1-")
    assert "continue with start_line=" in first
    nxt = int(first.split("start_line=")[1].split("]")[0])
    second = await call(
        client,
        "read_knowledge_topic",
        {"domain": "esp", "topic": "references/docs/espca.txt", "start_line": nxt, "max_chars": 100000},
    )
    assert second.startswith(f"[lines {nxt}-300 of 300]")
    assert "line 300 commitblocks" in second


async def test_read_beyond_end(client):
    text = await call(
        client, "read_knowledge_topic", {"domain": "esp", "topic": "references/docs/espca.txt", "start_line": 999}
    )
    assert "beyond end of file" in text


async def test_unknown_topic_lists_all_readable(client):
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "nope"})
    assert "not found" in text
    assert "references/kafka_connector" in text
    assert "templates/kafka_json_to_cas.xml" in text
    assert "blob.bin" not in text


async def test_non_text_suffix_rejected(client):
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "templates/blob.bin"})
    assert "not found" in text


async def test_topic_traversal_blocked(client):
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "../../secret"})
    assert "TOP SECRET" not in text
    assert "not found" in text


async def test_domain_traversal_blocked(client):
    text = await call(client, "read_knowledge_topic", {"domain": "..", "topic": "secret"})
    assert "TOP SECRET" not in text
    assert "Domain '..' not found" in text


async def test_unknown_domain(client):
    assert "not found" in await call(client, "read_knowledge_topic", {"domain": "zzz", "topic": "SKILL"})
    assert "not found" in await call(client, "search_knowledge", {"domain": "zzz", "pattern": "x"})


async def test_read_error_is_reported(client, monkeypatch):
    def boom(*_a, **_k):
        raise OSError("disk gone")

    monkeypatch.setattr(knowledge, "_read_slice", boom)
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "SKILL"})
    assert "Error reading topic: disk gone" in text


async def test_search_plain_case_insensitive(client):
    text = await call(client, "search_knowledge", {"domain": "esp", "pattern": "DISABLEESPMETACONSUMER"})
    assert "references/kafka_connector:2:" in text


async def test_search_with_glob_and_truncation(client):
    text = await call(
        client,
        "search_knowledge",
        {"domain": "esp", "pattern": "commitblocks", "path_glob": "references/docs/*", "max_results": 5},
    )
    assert text.startswith("5 match(es) (truncated")
    assert "references/docs/espca.txt:1:" in text


async def test_search_regex(client):
    text = await call(client, "search_knowledge", {"domain": "esp", "pattern": r"line 29\d ", "regex": True})
    assert "espca.txt:290:" in text


async def test_search_invalid_regex(client):
    text = await call(client, "search_knowledge", {"domain": "esp", "pattern": "(", "regex": True})
    assert text.startswith("Invalid regular expression")


async def test_search_no_match_and_empty_pattern(client):
    assert "No matches" in await call(client, "search_knowledge", {"domain": "esp", "pattern": "zzzz"})
    assert "must not be empty" in await call(client, "search_knowledge", {"domain": "esp", "pattern": ""})


async def test_search_long_line_is_clipped(client, kb):
    (kb / "esp" / "long.md").write_text("needle " + "x" * 500 + "\n", encoding="utf-8")
    text = await call(client, "search_knowledge", {"domain": "esp", "pattern": "needle"})
    assert text.rstrip().endswith("...")


async def test_bom_is_stripped(client, kb):
    (kb / "esp" / "templates" / "bom.xml").write_bytes(b"\xef\xbb\xbf<project/>\n")
    text = await call(client, "read_knowledge_topic", {"domain": "esp", "topic": "templates/bom.xml"})
    assert text == "<project/>\n"


def test_within_guard(tmp_path):
    assert knowledge._within(tmp_path, "a/b") == (tmp_path / "a" / "b").resolve()
    assert knowledge._within(tmp_path, "../x") is None
