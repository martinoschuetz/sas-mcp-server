import os
filepath = r"src/sas_mcp_server/tools/knowledge.py"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# Fix the redundant nested_path check
content = content.replace(
'''        if not topic_path.exists():
            # Support reading nested topics if they pass topic="references/analyses/weibull"
            nested_path = domain_path / f"{topic}.md"
            if not nested_path.exists():
                # List available top-level topics
                available = [f.stem for f in domain_path.glob("**/*.md")]
                return f"Topic '{topic}' not found in domain '{domain}'.\\nAvailable topics include: {', '.join(available[:20])}"''',
'''        if not topic_path.exists():
            # List available top-level topics
            available = [str(f.relative_to(domain_path).with_suffix('')) for f in domain_path.glob("**/*.md")]
            return f"Topic '{topic}' not found in domain '{domain}'.\\nAvailable topics include: {', '.join(available[:20])}"'''
)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
