import asyncio
import json
import os
import random
import subprocess
import sys
from urllib.parse import urljoin, urlparse

# Ensure playwright is installed
try:
    from playwright.async_api import async_playwright
except ImportError:
    print("Playwright not found. Installing playwright package...")
    try:
        # Try uv first since this is a uv environment
        subprocess.check_call(["uv", "pip", "install", "playwright"])
    except Exception:
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "playwright"])
        except Exception:
            print("Failed to install playwright. Please run 'uv pip install playwright' manually.")
            sys.exit(1)
            
    print("Installing Chromium browser dependency...")
    try:
        subprocess.check_call(["uv", "run", "playwright", "install", "chromium"])
    except Exception:
        try:
            subprocess.check_call([sys.executable, "-m", "playwright", "install", "chromium"])
        except Exception as e:
            print(f"Failed to install chromium: {e}")
            sys.exit(1)
            
    from playwright.async_api import async_playwright

def sanitize_folder_name(name: str) -> str:
    # Remove characters that are not allowed in Windows folder names
    return "".join(c for c in name if c.isalnum() or c in (' ', '_', '-')).strip()

async def download_all_specs():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    # Output to docs/APIs
    docu_dir = os.path.join(project_root, "docs", "APIs")
    storage_path = os.path.join(script_dir, "auth_state.json")
    
    os.makedirs(docu_dir, exist_ok=True)
    base_url = "https://developer.sas.com/rest-apis"
    
    # We will track visited API pages
    # We will track discovered API pages to visit
    to_visit = set()
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        
        # Load authentication state
        has_session = False
        if os.path.exists(storage_path):
            try:
                context = await browser.new_context(storage_state=storage_path)
                has_session = True
                print(f"Loaded saved authentication session from {storage_path}.")
            except Exception as e:
                print(f"Could not load saved session: {e}")
                context = await browser.new_context()
        else:
            context = await browser.new_context()
            
        page = await context.new_page()
        
        # Go to main rest-apis directory
        await page.goto(base_url)
        
        # Verify session is still valid
        if has_session:
            try:
                resp = await page.request.get("https://developer.sas.com/api/auth/get-session")
                if resp.status == 200:
                    session_info = await resp.json()
                    if session_info.get("user"):
                        print(f"Active session verified! Logged in as {session_info['user'].get('email')}.")
                    else:
                        print("Saved session is invalid/expired.")
                        has_session = False
                else:
                    has_session = False
            except Exception:
                has_session = False
                
        if not has_session:
            print("\n" + "="*80)
            print("ACTION REQUIRED:")
            print("1. In the opened browser window, log in using your Google account (martin.schuetz@sas.com).")
            print("2. Confirm you can see your logged-in profile in the top-right corner.")
            print("3. Waiting automatically for you to log in...")
            print("="*80 + "\n")
            
            while not has_session:
                await page.wait_for_timeout(3000)
                try:
                    resp = await page.request.get("https://developer.sas.com/api/auth/get-session")
                    if resp.status == 200:
                        session_info = await resp.json()
                        if session_info.get("user"):
                            print(f"Active session verified! Logged in as {session_info['user'].get('email')}.")
                            has_session = True
                except Exception:
                    pass
            
            # Save storage state for future runs
            await context.storage_state(path=storage_path)
            print(f"Saved authentication session to {storage_path} for future runs.")
        
        # 1. Scrape all API links on the main page to build a tree search
        print("Scraping links from main REST APIs directory to start tree crawl...")
        links = await page.query_selector_all("a")
        for l in links:
            href = await l.get_attribute("href")
            if href:
                full_url = urljoin(base_url, href)
                parsed = urlparse(full_url)
                if parsed.netloc == "developer.sas.com" and parsed.path.startswith("/rest-apis/") and len(parsed.path.split('/')) == 3:
                    to_visit.add(full_url)
                    
        # Merge APIs from Next.js hydration data if any
        try:
            next_data_str = await page.locator("script#__NEXT_DATA__").inner_text()
            next_data = json.loads(next_data_str)
            categories = next_data["props"]["pageProps"]["categories"]
            for cat in categories:
                for api in cat.get("apis", []):
                    api_name = api.get("apiName")
                    to_visit.add(f"https://developer.sas.com/rest-apis/{api_name}")
        except Exception:
            pass
            
        print(f"Discovered {len(to_visit)} total REST API endpoints to crawl and download.")
        
        success_count = 0
        fail_count = 0
        
        # Visit each API page to extract specifications
        for api_page in sorted(list(to_visit)):
            api_name = api_page.split('/')[-1]
            print(f"\nProcessing endpoint: {api_name} ({api_page})")
            
            try:
                # Add random jitter between 3 and 7 seconds to evade WAF rate limits
                delay = random.uniform(3.0, 7.0)
                print(f"  Sleeping {delay:.1f}s to avoid WAF block...")
                await page.wait_for_timeout(int(delay * 1000))
                
                await page.goto(api_page)
                await page.wait_for_timeout(1000)
                
                # Check Next.js pageProps
                next_data_str = await page.locator("script#__NEXT_DATA__").inner_text()
                page_data = json.loads(next_data_str)
                props = page_data["props"]["pageProps"]
                
                api_details = props.get("api")
                if not api_details:
                    # DOM Fallback search for spec download link
                    links = await page.query_selector_all("a")
                    found_any = False
                    for l in links:
                        await l.inner_text()
                        href = await l.get_attribute("href")
                        if href and ("specifications" in href.lower() or "openapi.yml" in href.lower()):
                            found_any = True
                            full_spec_url = urljoin(api_page, href)
                            category_name = "Uncategorized"
                            cat_folder = sanitize_folder_name(category_name)
                            cat_dir = os.path.join(docu_dir, cat_folder)
                            os.makedirs(cat_dir, exist_ok=True)
                            
                            file_path = os.path.join(cat_dir, f"{api_name}.yml")
                            
                            resp = await page.request.get(full_spec_url)
                            if resp.status == 200:
                                content = await resp.body()
                                with open(file_path, "wb") as f:
                                    f.write(content)
                                print(f"  - Downloaded spec (via DOM fallback) to {file_path}")
                                success_count += 1
                                
                                # Handle legacy files copy to root
                                if api_name in ["dataSelection", "iotAnalysis", "iotAnalysisModels"]:
                                    root_path = os.path.join(docu_dir, f"{api_name}-v1-openapi.yml")
                                    with open(root_path, "wb") as f:
                                        f.write(content)
                            else:
                                print(f"  - Failed download from {full_spec_url}: status {resp.status}")
                                fail_count += 1
                    if not found_any:
                        print("  - No specifications link found for this endpoint.")
                    continue
                
                # Use metadata from Next.js props
                category_name = api_details.get("api_category", {}).get("displayName") or "Uncategorized"
                cat_folder = sanitize_folder_name(category_name)
                cat_dir = os.path.join(docu_dir, cat_folder)
                os.makedirs(cat_dir, exist_ok=True)
                
                versions = api_details.get("versions", [])
                if not versions:
                    print(f"  No versions found for {api_name}.")
                    continue
                    
                target_version = None
                for v in versions:
                    for c_entry in v.get("cadences", []):
                        c_name = c_entry.get("cadence", {}).get("name") if c_entry.get("cadence") else None
                        if c_name == "2026.07":
                            target_version = v
                            break
                    if target_version:
                        break
                        
                if not target_version:
                    target_version = versions[0]
                    v_source = f"fallback to {target_version.get('apiId')}"
                else:
                    v_source = f"2026.07 version {target_version.get('apiId')}"
                    
                api_id = target_version.get("apiId")
                spec_url = f"https://developer.sas.com/api/apis/{api_id}/specifications/openapi.yml"
                file_path = os.path.join(cat_dir, f"{api_name}.yml")
                
                print(f"  Downloading spec from {spec_url} ({v_source})...", end="", flush=True)
                resp = await page.request.get(spec_url)
                if resp.status == 200:
                    content = await resp.body()
                    with open(file_path, "wb") as f:
                        f.write(content)
                    print(" Success!")
                    success_count += 1
                    
                    # Handle legacy files copy to root
                    if api_name in ["dataSelection", "iotAnalysis", "iotAnalysisModels"]:
                        root_path = os.path.join(docu_dir, f"{api_name}-v1-openapi.yml")
                        with open(root_path, "wb") as f:
                            f.write(content)
                else:
                    print(f" Failed (HTTP Status {resp.status})")
                    fail_count += 1
            except Exception as e:
                print(f"  Error processing page {api_page}: {e}")
                fail_count += 1
                
        print("\n" + "="*80)
        print("TREE SEARCH DOWNLOAD COMPLETED!")
        print(f"Successfully downloaded: {success_count} specifications")
        print(f"Failed to download:       {fail_count} specifications")
        print(f"Saved into:               {docu_dir}")
        print("="*80)
        
        await browser.close()

if __name__ == "__main__":
    asyncio.run(download_all_specs())
