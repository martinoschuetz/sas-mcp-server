
import re
with open('tests/test_read_only.py', 'r') as f:
    text = f.read()

text = re.sub(r'<<<<<<< HEAD\n    assert len\(await _register\(read_only=False\)\) == len\(READ_ONLY_TOOLS\) \+ len\(WRITE_TOOLS\)\n=======\n    assert len\(await _register\(read_only=False\)\) == \d+\n>>>>>>> v1.15.0', '    assert len(await _register(read_only=False)) == len(READ_ONLY_TOOLS) + len(WRITE_TOOLS)', text)

with open('tests/test_read_only.py', 'w') as f:
    f.write(text)

