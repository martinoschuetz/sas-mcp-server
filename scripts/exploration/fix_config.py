filepath = r"src/sas_mcp_server/config.py"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()
import re
new_content = re.sub(
    r"<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> david/main",
    r"\1\n\2",
    content,
    flags=re.DOTALL
)
with open(filepath, "w", encoding="utf-8") as f:
    f.write(new_content)
