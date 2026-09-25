from collections.abc import Awaitable, Callable
from pathlib import Path

from fastmcp import FastMCP

from fastmcp import Context

# Use /app/knowledge if in docker, otherwise local knowledge/ dir
KNOWLEDGE_DIR = Path("/app/knowledge") if Path("/app/knowledge").exists() else Path("knowledge")


def register(mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]) -> None:
    @mcp.tool()
    async def list_knowledge_domains(ctx: Context) -> str:
        """List all available knowledge domains and playbooks in the MCP server.

        Returns:
            A formatted list of domains (e.g., fqa, esp, caf, api, forecasting).
        """
        if not KNOWLEDGE_DIR.exists():
            return "Knowledge directory not found."

        domains = []
        for d in KNOWLEDGE_DIR.iterdir():
            if d.is_dir():
                domains.append(f"- {d.name}")

        if not domains:
            return "No knowledge domains found."

        return "Available Knowledge Domains:\n" + "\n".join(domains)

    @mcp.tool()
    async def read_knowledge_topic(domain: str, topic: str, ctx: Context) -> str:
        """Read a specific playbook or markdown reference file from a knowledge domain.

        Args:
            domain: The knowledge domain (e.g., 'fqa', 'esp', 'caf', 'standards').
            topic: The topic or file name to read (e.g., 'SKILL', 'mcp_execution_rules', 'sas', 'python'). Do not include the .md extension.

        Returns:
            The markdown content of the requested topic.
        """
        domain_path = KNOWLEDGE_DIR / domain
        if not domain_path.exists():
            return f"Domain '{domain}' not found. Use list_knowledge_domains to see available domains."

        # Check standard file
        topic_path = domain_path / f"{topic}.md"
        if not topic_path.exists():
            # Support reading nested topics if they pass topic="references/analyses/weibull"
            nested_path = domain_path / f"{topic}.md"
            if not nested_path.exists():
                # List available top-level topics
                available = [f.stem for f in domain_path.glob("**/*.md")]
                return f"Topic '{topic}' not found in domain '{domain}'.\nAvailable topics include: {', '.join(available[:20])}"

        try:
            with open(topic_path, encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            return f"Error reading topic: {str(e)}"
