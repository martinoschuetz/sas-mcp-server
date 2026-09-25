import httpx
import re

def main():
    resp = httpx.get('https://iot.viya-azure-gpu.unx.sas.com/SASQualityAnalyticSuite/', verify=False)
    js_files = re.findall(r'src="([^"]+\.js)"', resp.text)
    print("Found JS files:", js_files)
    
if __name__ == "__main__":
    main()
