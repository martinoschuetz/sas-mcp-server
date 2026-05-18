# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import os
import ssl
import httpx
from dotenv import load_dotenv

load_dotenv()

SSL_VERIFY = os.getenv("SSL_VERIFY", "true").lower() not in ("false", "0", "no")

if not SSL_VERIFY:
    _ssl_context = ssl.create_default_context()
    _ssl_context.check_hostname = False
    _ssl_context.verify_mode = ssl.CERT_NONE
    
    _original_async_client_init = httpx.AsyncClient.__init__

    def _patched_async_client_init(self, *args, **kwargs):
        kwargs.setdefault("verify", _ssl_context)
        _original_async_client_init(self, *args, **kwargs)

    httpx.AsyncClient.__init__ = _patched_async_client_init

    _original_client_init = httpx.Client.__init__

    def _patched_client_init(self, *args, **kwargs):
        kwargs.setdefault("verify", _ssl_context)
        _original_client_init(self, *args, **kwargs)

    httpx.Client.__init__ = _patched_client_init
    
    print("SSL monkey-patch applied")
