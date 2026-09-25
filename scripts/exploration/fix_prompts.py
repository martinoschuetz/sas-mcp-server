
with open('src/sas_mcp_server/prompts.py', 'r') as f:
    text = f.read()

text = text.replace('@mcp.prompt()\ndef fqa_best_practices', '    @mcp.prompt()\n    def fqa_best_practices')
# indent the rest
import re
text = re.sub(r'def fqa_best_practices\(\) -> list\[Message\]:\n(.*)', lambda m: 'def fqa_best_practices() -> list[Message]:\n' + '\n'.join('    ' + line if line else line for line in m.group(1).split('\n')), text, flags=re.DOTALL)

with open('src/sas_mcp_server/prompts.py', 'w') as f:
    f.write(text)

