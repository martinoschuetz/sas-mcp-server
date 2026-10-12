import os
import re
from pathlib import Path

knowledge_dir = Path("knowledge")
folders = ["api", "caf", "esp", "forecasting", "sas", "standards"]

for f in folders:
    base = knowledge_dir / f
    for d in ["evals", "references", "templates"]:
        (base / d).mkdir(parents=True, exist_ok=True)
    
    skill_file = base / "SKILL.md"
    rules_file = base / "mcp_execution_rules.md"
    
    if f == "standards":
        # Rename python.md to mcp_execution_rules.md
        if (base / "python.md").exists():
            (base / "python.md").rename(rules_file)
        
        # Update SKILL.md
        if skill_file.exists():
            content = skill_file.read_text("utf-8")
            content = content.replace("python.md", "mcp_execution_rules.md")
            skill_file.write_text(content, "utf-8")
        continue

    if skill_file.exists() and not rules_file.exists():
        content = skill_file.read_text("utf-8")
        # Split YAML frontmatter from rest of content
        match = re.match(r"^---\n(.*?)\n---\n(.*)", content, re.DOTALL)
        if match:
            frontmatter = match.group(1)
            body = match.group(2).strip()
            
            # If body is substantial (more than just a pointer), move it to mcp_execution_rules.md
            if len(body) > 200:
                rules_file.write_text(body + "\n", "utf-8")
                
                # New SKILL.md
                new_skill = f"---\n{frontmatter}\n---\n\nPlease refer to mcp_execution_rules.md for the detailed rules and guidelines.\n"
                skill_file.write_text(new_skill, "utf-8")

print("Done refactoring folders.")
