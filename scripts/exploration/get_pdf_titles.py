
import glob
from pypdf import PdfReader

for f in glob.glob('docs/ESP/*.pdf'):
    try:
        reader = PdfReader(f)
        meta = reader.metadata
        print(f'{f}: {meta.title}')
    except Exception as e:
        print(f'{f}: ERROR {e}')

