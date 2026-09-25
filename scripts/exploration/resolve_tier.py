
import re
with open('tests/test_tier_selection.py', 'r') as f:
    text = f.read()

text = re.sub(r'<<<<<<< HEAD\n    assert len\(names\) > 0\n=======\n    assert len\(names\) == \d+\n>>>>>>> v1.15.0', '    assert len(names) > 0', text)

with open('tests/test_tier_selection.py', 'w') as f:
    f.write(text)

