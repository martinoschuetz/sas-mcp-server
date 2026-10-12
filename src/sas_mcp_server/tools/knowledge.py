"""Knowledge-base tools: list domains, read topics (markdown, templates, doc text) and search them."""

import asyncio
import re
from collections.abc import Awaitable, Callable
from pathlib import Path

from fastmcp import Context, FastMCP

# Use /app/knowledge if in docker, otherwise resolve the local knowledge/ dir relative to this file
LOCAL_KNOWLEDGE_DIR = Path(__file__).resolve().parent.parent.parent.parent / "knowledge"
KNOWLEDGE_DIR = Path("/app/knowledge") if Path("/app/knowledge").exists() else LOCAL_KNOWLEDGE_DIR

# Text formats that may be returned to the client. Markdown topics can be addressed without
# extension; every other format must be addressed with its extension (e.g. "templates/x.xml").
READABLE_SUFFIXES: frozenset[str] = frozenset(
    {".md", ".txt", ".xml", ".py", ".sas", ".json", ".yml", ".yaml", ".csv", ".lua", ".sql"}
)
DEFAULT_MAX_CHARS = 60_000
MAX_TOPICS_LISTED = 200
MAX_SEARCH_RESULTS = 200


def _within(base: Path, relative: str) -> Path | None:
    """Resolve *relative* below *base*; return None if it escapes *base* (path traversal)."""
    base_resolved = base.resolve()
    candidate = (base_resolved / relative).resolve()
    if candidate == base_resolved or base_resolved in candidate.parents:
        return candidate
    return None


def _domain_path(domain: str) -> Path | None:
    path = _within(KNOWLEDGE_DIR, domain)
    if path is None or not path.is_dir():
        return None
    return path


def _readable_files(domain_path: Path) -> list[Path]:
    return sorted(p for p in domain_path.rglob("*") if p.is_file() and p.suffix.lower() in READABLE_SUFFIXES)


def _topic_name(domain_path: Path, path: Path) -> str:
    rel = path.relative_to(domain_path).as_posix()
    return rel[: -len(".md")] if rel.endswith(".md") else rel


def _resolve_topic(domain_path: Path, topic: str) -> Path | None:
    topic = topic.replace("\\", "/").strip()
    candidates = [topic] if Path(topic).suffix.lower() in READABLE_SUFFIXES else []
    candidates.append(f"{topic}.md")
    for cand in candidates:
        path = _within(domain_path, cand)
        if path is not None and path.is_file() and path.suffix.lower() in READABLE_SUFFIXES:
            return path
    return None


def _read_slice(path: Path, start_line: int, max_chars: int) -> str:
    with open(path, encoding="utf-8-sig", errors="replace") as f:
        lines = f.readlines()
    total = len(lines)
    start = max(start_line, 1)
    if start > total and total > 0:
        return f"[start_line {start} is beyond end of file ({total} lines)]"
    out: list[str] = []
    size = 0
    end = start - 1
    for idx in range(start - 1, total):
        line = lines[idx]
        if out and size + len(line) > max_chars:
            break
        out.append(line)
        size += len(line)
        end = idx + 1
    body = "".join(out)
    if start == 1 and end >= total:
        return body
    note = f"[lines {start}-{end} of {total}"
    note += f"; continue with start_line={end + 1}]" if end < total else "]"
    return f"{note}\n{body}"


def _search(domain_path: Path, pattern: str, regex: bool, path_glob: str | None, max_results: int) -> str:
    try:
        rx = re.compile(pattern if regex else re.escape(pattern), re.IGNORECASE)
    except re.error as exc:
        return f"Invalid regular expression: {exc}"
    files = _readable_files(domain_path)
    if path_glob:
        files = [p for p in files if p.relative_to(domain_path).match(path_glob)]
    hits: list[str] = []
    truncated = False
    for path in files:
        topic = _topic_name(domain_path, path)
        with open(path, encoding="utf-8-sig", errors="replace") as f:
            for lineno, line in enumerate(f, start=1):
                if rx.search(line):
                    text = line.strip()
                    if len(text) > 300:
                        text = text[:300] + "..."
                    hits.append(f"{topic}:{lineno}: {text}")
                    if len(hits) >= max_results:
                        truncated = True
                        break
        if truncated:
            break
    if not hits:
        return f"No matches for '{pattern}' in {len(files)} file(s)."
    header = f"{len(hits)} match(es){' (truncated; refine pattern or path_glob)' if truncated else ''}:"
    return header + "\n" + "\n".join(hits)


def register(mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]) -> None:
    @mcp.tool()
    async def list_knowledge_domains(ctx: Context) -> str:
        """List all available knowledge domains and playbooks in the MCP server.

        Returns:
            A formatted list of domains (e.g., fqa, esp, caf, api, forecasting).
        """
        if not KNOWLEDGE_DIR.exists():
            return "Knowledge directory not found."

        domains = sorted(f"- {d.name}" for d in KNOWLEDGE_DIR.iterdir() if d.is_dir())
        if not domains:
            return "No knowledge domains found."

        return "Available Knowledge Domains:\n" + "\n".join(domains)

    @mcp.tool()
    async def read_knowledge_topic(
        domain: str,
        topic: str,
        ctx: Context,
        start_line: int = 1,
        max_chars: int = DEFAULT_MAX_CHARS,
    ) -> str:
        """Read a playbook, reference, template or documentation file from a knowledge domain.

        Args:
            domain: The knowledge domain (e.g., 'fqa', 'esp', 'caf', 'standards').
            topic: Path of the file inside the domain. Markdown topics may omit '.md'
                (e.g. 'SKILL', 'mcp_execution_rules', 'references/kafka_connector');
                other files need their extension (e.g. 'templates/kafka_json_to_cas.xml',
                'references/docs/espca.txt').
            start_line: 1-based line to start from (use for paging through large files).
            max_chars: Maximum characters to return (default 60000).

        Returns:
            The file content (or a slice with a continuation hint for large files).
        """
        domain_path = _domain_path(domain)
        if domain_path is None:
            return f"Domain '{domain}' not found. Use list_knowledge_domains to see available domains."

        topic_path = _resolve_topic(domain_path, topic)
        if topic_path is None:
            available = [_topic_name(domain_path, p) for p in _readable_files(domain_path)]
            shown = available[:MAX_TOPICS_LISTED]
            more = f" (+{len(available) - len(shown)} more)" if len(available) > len(shown) else ""
            return (
                f"Topic '{topic}' not found in domain '{domain}'.\n"
                f"Available topics ({len(available)}){more}: {', '.join(shown)}"
            )

        try:
            return await asyncio.to_thread(_read_slice, topic_path, start_line, max(max_chars, 1000))
        except Exception as e:
            return f"Error reading topic: {e!s}"

    @mcp.tool()
    async def search_knowledge(
        domain: str,
        pattern: str,
        ctx: Context,
        regex: bool = False,
        path_glob: str | None = None,
        max_results: int = 50,
    ) -> str:
        """Search all readable files of a knowledge domain (markdown, templates, documentation text).

        Use this before guessing syntax, e.g. search the ESP manuals for a connector property:
        search_knowledge('esp', 'disableespmetaconsumer', path_glob='references/docs/*').

        Args:
            domain: The knowledge domain (e.g., 'esp').
            pattern: Case-insensitive search text (or regular expression when regex=True).
            regex: Treat pattern as a Python regular expression.
            path_glob: Optional glob relative to the domain to restrict files (e.g. 'references/docs/*').
            max_results: Maximum matching lines to return (default 50, max 200).

        Returns:
            Matching lines as 'topic:line: text'. Read context with read_knowledge_topic(start_line=...).
        """
        domain_path = _domain_path(domain)
        if domain_path is None:
            return f"Domain '{domain}' not found. Use list_knowledge_domains to see available domains."
        if not pattern:
            return "Pattern must not be empty."
        limit = min(max(max_results, 1), MAX_SEARCH_RESULTS)
        return await asyncio.to_thread(_search, domain_path, pattern, regex, path_glob, limit)
