
import re
with open('tests/test_read_only.py', 'r') as f:
    text = f.read()

text = re.sub(r'<<<<<<< HEAD\n    assert len\(names\) == len\(READ_ONLY_TOOLS\)\n=======\n    assert len\(names\) == \d+\n>>>>>>> v1.15.0', '    assert len(names) == len(READ_ONLY_TOOLS)', text)
text = re.sub(r'<<<<<<< HEAD\n    assert len\(await _register\(\)\) == len\(READ_ONLY_TOOLS\) \+ len\(WRITE_TOOLS\)\n=======\n    assert len\(await _register\(\)\) == \d+\n>>>>>>> v1.15.0', '    assert len(await _register()) == len(READ_ONLY_TOOLS) + len(WRITE_TOOLS)', text)

with open('tests/test_read_only.py', 'w') as f:
    f.write(text)

