
with open('CHANGELOG.md', 'r', encoding='utf-8') as f:
    text = f.read()

import re

# We will replace the whole conflict block with:
# ## [Unreleased]
# - **Tier 9 (IoT & FQA)**: ...
# - **Tier 10 (Generative AI)**: ...
# <Then David's v1.15.0 block>

new_block = '''## [Unreleased]
- **Tier 9 (IoT & FQA)**: Added a comprehensive suite of over 60 tools for SAS Field Quality Analytics and IoT solutions, including analysis runs, data selections, forecasting, and visualization.
- **Tier 10 (Generative AI)**: Added tools for interacting with the SAS Retrieval Agent Manager, including fetching and querying agents, retrieving sources, and querying configured LLMs.

## [1.15.0] - 2026-09-13'''

text = re.sub(r'<<<<<<< HEAD.*?=======\n  ## \[1.15.0\] - 2026-09-13\n>>>>>>> v1.15.0', new_block, text, flags=re.DOTALL)

with open('CHANGELOG.md', 'w', encoding='utf-8') as f:
    f.write(text)

