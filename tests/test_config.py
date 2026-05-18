# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import os
import sys
from unittest.mock import patch
import pytest

def _reload_config():
    """Force-reload the config module so it picks up environment changes."""
    if 'sas_mcp_server.config' in sys.modules:
        del sys.modules['sas_mcp_server.config']
    import sas_mcp_server.config as cfg
    return cfg

def test_config_env_vars(monkeypatch):
    """Test that environment variables are correctly loaded."""
    monkeypatch.setenv("VIYA_ENDPOINT", "https://example.com")
    monkeypatch.setenv("CLIENT_ID", "test-client")
    monkeypatch.setenv("HOST_PORT", "9000")
    monkeypatch.setenv("MCP_BASE_URL", "https://mcp.example.com")
    monkeypatch.setenv("COMPUTE_CONTEXT_NAME", "Test Context")
    monkeypatch.setenv("MCP_SIGNING_KEY", "test-secret")
    monkeypatch.setenv("SSL_VERIFY", "false")

    cfg = _reload_config()

    assert cfg.VIYA_ENDPOINT == "https://example.com"
    assert cfg.CLIENT_ID == "test-client"
    assert cfg.HOST_PORT == 9000
    assert cfg.MCP_BASE_URL == "https://mcp.example.com"
    assert cfg.CONTEXT_NAME == "Test Context"
    assert cfg.MCP_SIGNING_KEY == "test-secret"
    assert cfg.SSL_VERIFY is False

def test_config_default_values(monkeypatch):
    """Test that default values are used when environment variables are missing."""
    monkeypatch.delenv("VIYA_ENDPOINT", raising=False)
    monkeypatch.delenv("CLIENT_ID", raising=False)
    monkeypatch.delenv("HOST_PORT", raising=False)
    monkeypatch.delenv("MCP_BASE_URL", raising=False)
    monkeypatch.delenv("COMPUTE_CONTEXT_NAME", raising=False)
    monkeypatch.delenv("MCP_SIGNING_KEY", raising=False)
    monkeypatch.delenv("SSL_VERIFY", raising=False)

    # Block module-level load_dotenv from repopulating from .env.
    with patch('dotenv.load_dotenv'):
        cfg = _reload_config()
    
    assert cfg.CLIENT_ID == "sas-mcp"
    assert cfg.HOST_PORT == 8134
    assert cfg.MCP_SIGNING_KEY == "default"
    assert cfg.CONTEXT_NAME == "SAS Job Execution compute context"
    assert cfg.SSL_VERIFY is True

def test_config_ssl_verify_variants(monkeypatch):
    """Test that SSL_VERIFY parses various truthy/falsy strings correctly."""
    for val in ("false", "0", "no", "FALSE"):
        monkeypatch.setenv("SSL_VERIFY", val)
        cfg = _reload_config()
        assert cfg.SSL_VERIFY is False, f"Failed for SSL_VERIFY={val}"

    for val in ("true", "1", "yes", "TRUE", ""):
        monkeypatch.setenv("SSL_VERIFY", val)
        cfg = _reload_config()
        assert cfg.SSL_VERIFY is True, f"Failed for SSL_VERIFY={val}"
