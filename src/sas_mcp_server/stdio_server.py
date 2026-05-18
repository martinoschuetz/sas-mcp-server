#!/usr/bin/env python3
# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Apply SSL patch before any other imports
from . import patch_httpx

"""
Stdio MCP Server for SAS Viya.
Authenticates directly to Viya using password grant, allowing MCP clients
to start the server on demand without a pre-running HTTP server.
"""

import os
import httpx
import time
from dotenv import load_dotenv
from fastmcp import Context, FastMCP
from fastmcp.exceptions import FastMCPError
from .config import VIYA_ENDPOINT, CLIENT_ID, SSL_VERIFY
from .viya_utils import logger
from .tools import register_tools
from .prompts import register_prompts

load_dotenv(override=True)
logger.info(f"CWD: {os.getcwd()}")
logger.info(f".env exists: {os.path.exists('.env')}")

VIYA_USERNAME = os.getenv("VIYA_USERNAME", "")
VIYA_PASSWORD = os.getenv("VIYA_PASSWORD", "")


class AuthenticationError(FastMCPError):
    def __init__(self, message):
        super().__init__(message)
        self.message = message

    def __str__(self):
        return f"AuthenticationError: {self.message}"
def _get_viya_token() -> str:
    """Authenticate to Viya using password grant and return an access token with caching."""
    token_file = ".viya_token"

    # Check if we have a cached token that is less than 30 minutes old
    if os.path.exists(token_file):
        mtime = os.path.getmtime(token_file)
        if time.time() - mtime < 1800: # 30 minutes
            with open(token_file, "r") as f:
                return f.read().strip()

    if not VIYA_USERNAME or not VIYA_PASSWORD:
        raise AuthenticationError(
            "VIYA_USERNAME and VIYA_PASSWORD must be set in .env for stdio mode"
        )

    logger.info(f"Authenticating to Viya at {VIYA_ENDPOINT} with username {VIYA_USERNAME}...")
    try:
        resp = httpx.post(
            f"{VIYA_ENDPOINT}/SASLogon/oauth/token",
            auth=(CLIENT_ID, ""),
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={
                "grant_type": "password",
                "username": VIYA_USERNAME,
                "password": VIYA_PASSWORD,
            },
            verify=SSL_VERIFY,
            timeout=20.0, # Increased timeout for the login itself
        )
        logger.info(f"Auth response status: {resp.status_code}")
        if resp.status_code != 200:
            logger.error(f"Auth failed with body: {resp.text}")
        resp.raise_for_status()
        token = resp.json()["access_token"]

        # Save to cache
        with open(token_file, "w") as f:
            f.write(token)

        logger.info("Token acquired and cached successfully")
        return token
    except Exception as e:
        logger.error(f"Failed to acquire Viya token: {str(e)}")
        raise e



# Token getter for stdio mode: acquires token via password grant
async def _stdio_get_token(ctx: Context) -> str:
    return _get_viya_token()


# Initialize the FastMCP server (no auth — stdio clients handle auth differently)
logger.info(f"Connecting to SAS Viya at {VIYA_ENDPOINT}")
mcp = FastMCP("SAS Viya Execution MCP Server")

# Register all tools and prompts
register_tools(mcp, _stdio_get_token)
register_prompts(mcp)


def main():
    """Run the MCP server in stdio mode."""
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
