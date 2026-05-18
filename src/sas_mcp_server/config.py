# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Apply SSL monkey-patch globally before other imports
from . import patch_httpx
from .patch_httpx import SSL_VERIFY

import os
from dotenv import load_dotenv
from fastmcp.server.auth import OAuthProxy
from fastmcp.server.auth.providers.jwt import JWTVerifier

load_dotenv()

VIYA_ENDPOINT = os.getenv("VIYA_ENDPOINT", "").rstrip("/")
CLIENT_ID = os.getenv("CLIENT_ID", "sas-mcp")
HOST_PORT = int(os.getenv("HOST_PORT", "8134"))
MCP_SIGNING_KEY = os.getenv("MCP_SIGNING_KEY", "default")
CONTEXT_NAME = os.getenv("COMPUTE_CONTEXT_NAME", "SAS Job Execution compute context")
MCP_BASE_URL = os.getenv("MCP_BASE_URL", f"http://localhost:{HOST_PORT}")

if not VIYA_ENDPOINT:
    raise Exception(
        "VIYA_ENDPOINT is not set. Please set it in the environment variables."
    )

AUTHORIZATION_ENDPOINT = f"{VIYA_ENDPOINT}/SASLogon/oauth/authorize"
TOKEN_ENDPOINT = f"{VIYA_ENDPOINT}/SASLogon/oauth/token"
JWKS_URI = f"{VIYA_ENDPOINT}/SASLogon/token_keys"


token_verifier = JWTVerifier(jwks_uri=JWKS_URI, audience=[])

viya_auth = OAuthProxy(
    upstream_authorization_endpoint=AUTHORIZATION_ENDPOINT,
    upstream_token_endpoint=TOKEN_ENDPOINT,
    upstream_client_id=CLIENT_ID,
    upstream_client_secret="",
    jwt_signing_key=MCP_SIGNING_KEY,
    base_url=MCP_BASE_URL,
    forward_pkce=True,
    token_verifier=token_verifier,
    valid_scopes=[],
)
