
from pypdf import PdfReader
import sys

try:
    reader = PdfReader('docs/advanced_forecasting_report.pdf')
    text = ''
    for page in reader.pages:
        text += page.extract_text() + '\n'
        
    with open('docs/advanced_forecasting_report.txt', 'w', encoding='utf-8') as f:
        f.write(text)
    print('Extraction complete. Saved to docs/advanced_forecasting_report.txt')
except Exception as e:
    print(f'ERROR: {e}')

