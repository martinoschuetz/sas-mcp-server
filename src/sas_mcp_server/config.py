# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import os
import ssl
from dotenv import load_dotenv
from fastmcp.server.auth.providers.oauth import OAuthProxy
from fastmcp.server.auth.providers.jwt import token_verifier_factory

load_dotenv()

SSL_VERIFY = os.getenv("SSL_VERIFY", "true").lower() not in ("false", "0", "no")

if not SSL_VERIFY:
    # Disable SSL verification for self-signed Viya certificates
    import httpx
    # Guard against re-patching when this module is reloaded (e.g. by tests
    # that del sys.modules['sas_mcp_server.config'] and re-import). Without
    # this, each reload stacks another wrapper around the existing one,
    # eventually breaking outbound httpx connections in the same process.
    if not getattr(httpx.AsyncClient.__init__, "_sas_mcp_ssl_patched", False):
        _ssl_context = ssl.create_default_context()
        _ssl_context.check_hostname = False
        _ssl_context.verify_mode = ssl.CERT_NONE
        # Monkey-patch httpx to use our permissive SSL context by default
        _original_async_client_init = httpx.AsyncClient.__init__

        def _patched_async_client_init(self, *args, **kwargs):
            kwargs.setdefault("verify", _ssl_context)
            _original_async_client_init(self, *args, **kwargs)

        _patched_async_client_init._sas_mcp_ssl_patched = True
        httpx.AsyncClient.__init__ = _patched_async_client_init

        _original_client_init = httpx.Client.__init__

        def _patched_client_init(self, *args, **kwargs):
            kwargs.setdefault("verify", _ssl_context)
            _original_client_init(self, *args, **kwargs)

        _patched_client_init._sas_mcp_ssl_patched = True
        httpx.Client.__init__ = _patched_client_init

VIYA_ENDPOINT = os.getenv("VIYA_ENDPOINT", "").rstrip("/")
CLIENT_ID = os.getenv("CLIENT_ID", "sas-mcp")
HOST_PORT = int(os.getenv("HOST_PORT", "8134"))
MCP_BASE_URL = os.getenv("MCP_BASE_URL", f"http://localhost:{HOST_PORT}")
CONTEXT_NAME = os.getenv(
    "COMPUTE_CONTEXT_NAME", "SAS Job Execution compute context"
)

# Secret key used to sign the tokens (JWT)
MCP_SIGNING_KEY = os.getenv("MCP_SIGNING_KEY", "default")

# Configure the token verifier for OAuthProxy
token_verifier = token_verifier_factory(
    issuer=f"{MCP_BASE_URL}/",
    audience=CLIENT_ID,
    # In production, the public key should be retrieved from the JWKS endpoint
    algorithms=["HS256"],
    secret=MCP_SIGNING_KEY,
)

# Configure the SAS Viya OAuth2 Proxy
viya_auth = OAuthProxy(
    client_id=CLIENT_ID,
    authorize_url=f"{VIYA_ENDPOINT}/SASLogon/oauth/authorize",
    token_url=f"{VIYA_ENDPOINT}/SASLogon/oauth/token",
    base_url=MCP_BASE_URL,
    forward_pkce=True,
    token_verifier=token_verifier,
    valid_scopes=["openid"],
)
