## Configuration details for the SAS MCP Server

### Viya Setup
The SAS MCP Server runs locally and expects to communicate with a Viya instance.

The Viya instance serves two important roles:
1. Acts as an authorization server for the MCP Server
2. It provides the SAS execution API for the MCP Server

In order for the local MCP server to function properly, there are a few tweaks that need to be made to the Viya instance.

NOTE: These steps require Administrative access over the Viya instance. If you do not have access, please ask your SAS Administrator for assistance.

#### Step 1: Disable form-action Content Security Policy on SAS Logon Manager
Since the MCP Server is an external client to Viya, after successful authentication, the redirect will fail to trigger due to the form-action directive CSP. For local development and testing, it is most straightforward to **disable the directive**.  

1. Log into Viya, assume the Administrator role
2. Go to SAS Environment Manager (left hand screen, Manage Environment)
3. Go to Configuration (left hand screen, under System)
4. View Definitions (Right next to the View:)
5. Filter by 'sas.commons.web.security', select it
6. Search for 'SAS Logon Manager', edit it
7. Go to 'content-security-policy', delete the 'form-action' component entirely. 
8. Save the configuration

IMPORTANT: This approach does not follow security best practices. While it is feasible for local development and testing, for production scenarios, we strongly recommend hosting the MCP Server with proper TLS termination and adding its domain to the form-action directive as an allowed domain.

#### Step 2. Register an OAuth Client for the MCP Server
Since Viya does not support Dynamic Client Registration (DCR) pattern. It is required to register the OAuth client ahead of time. The [MCP Authorization spec](https://modelcontextprotocol.io/specification/draft/basic/authorization) states that this must be Authorization Code Flow with PKCE.

Following best practies defined in this [SAS blog post](https://blogs.sas.com/content/sgf/2023/02/07/authentication-to-sas-viya)

If you are not comfortable with curl and the command line. Feel free to use any API client.

1\. Retrieve a Viya access token (user is assumed to be a SAS Administrator)
```sh
export BEARER_TOKEN=`curl -sk -X POST \
    "https://YOUR_VIYA_ENDPOINT/SASLogon/oauth/token" \
    -u "sas.cli:" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d 'grant_type=password&username=user&password=password' | awk -F: '{print $2}'|awk -F\" '{print $2}'`
```
Replace the endpoint, username and password with your own values.

2\. Register the OAuth Client
```sh
curl -k -X POST "https://YOUR_VIYA_ENDPOINT/SASLogon/oauth/clients" \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer $BEARER_TOKEN" \
   -d '{"client_id": "sas-mcp",
      "scope": ["openid"],
      "authorized_grant_types": ["authorization_code","refresh_token"],
      "redirect_uri": "http://localhost:8134/auth/callback", "autoapprove":true, "allowpublic":true}'
```
Replace the endpoint with your own value.
Note the client_id and the redirect_uri -- these are important for the environment file

Congratulations! Your Viya is now configured and ready to connect with the MCP server.

---

### Environment file options
The .env file used by the MCP Server allows for customizable options that the user can set themselves.
| Variable            | Required | Default       | Description                                                 |
|---------------------|---------|--------------|---------------------------------------------------------------|
| `VIYA_ENDPOINT`     | Yes     | —            | Viya instance to use                                          |
| `CLIENT_ID`         | No      | `sas-mcp`    | OAuth2 Client ID registered in Viya                           |
| `HOST_PORT`         | No      |  `8134`      | Host Port the local MCP Server listens on                    |
| `MCP_SIGNING_KEY`   | No      | `default`    | Secret key used to sign [FastMCP Proxy JWTs](https://gofastmcp.com/servers/auth/oauth-proxy#param-jwt-signing-key)                                                           |
| `CONTEXT_NAME`      | No      | `SAS Job Execution compute context`       | Viya compute context to use for the code execution                                                                                                |

The defaults listed here are the variable values used in the Viya setup step. If your SAS Administrator has used a different `CLIENT_ID`, `HOST_PORT` during the OAuth Client registration. Please use those values instead. 

---

### Further MCP setup options
For examples on how to run with docker, refer to the **docker** folder. 