# SAS MCP Server

A Model Context Protocol (MCP) server for executing SAS code on SAS Viya environments.

## Features

- Execute SAS code on SAS Viya compute contexts
- OAuth2 authentication with PKCE flow
- HTTP-based MCP server compatible with MCP clients

## Getting Started
### Prerequisites
- Required
    - [Python 3.12+](https://www.python.org/downloads) 
    - [uv 0.8+](https://github.com/astral-sh/uv)  
    - [SAS Viya environment](https://www.sas.com/en_us/software/viya.html) with compute service
    - Setup the Viya environment for MCP
        - See [configuration.md](/examples/configuration.md)

- Optional
    - [Docker](https://docs.docker.com/engine/install): refer to [docker setup](/examples/docker/setup.md)

### Installation

1. Clone the repository:
```sh
git clone <repository-url>
cd sas-mcp-server
```

2. Install dependencies
```sh
uv sync
```

NOTE: This will by default create a virtual environment called .venv in the project's root directory. 

If for some reason the virtual environment is not created, please run `uv venv` and then re-run `uv sync`.

### Usage

1. Configure environment variables:
```sh
cp .env.sample .env
```

Edit `.env` and set
```sh
VIYA_ENDPOINT=https://your-viya-server.com
```

2. Start the MCP server:
```sh
uv run app
```

The server will be available at `http://localhost:8134/mcp` by default.

### Available Tools

- **execute_sas_code**: Execute SAS code snippets and retrieve execution results (log and listing output)

## MCP Client Configuration

Add to your MCP client configuration (e.g., `.vscode/mcp.json`):
```json
{
    "servers": {
        "sas-execution-mcp": {
            "url": "http://localhost:8134/mcp",
            "type": "http"
        }
    }
}
```

## Example

Execute SAS code through the MCP tool:
```sas
data work.students;
input Name $ Age Grade $;
datalines;
Alice 20 A
Bob 22 B
;
run;

proc print data=work.students;
run;
```
---

**For more details, configuration options, and deployment options, please refer to the **examples** folder and follow the instructions listed there.**

## Contributing
Maintainers are accepting patches and contributions to this project. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details about submitting contributions to this project.

## License & Attribution

Except for the the contents of the /static folder, this project is licensed under the [Apache 2.0 License](LICENSE). Elements in the /static folder are owned by SAS and are not released under an open source license. SAS and all other SAS Institute Inc. product or service names are registered trademarks or trademarks of SAS Institute Inc. in the USA and other countries. ® indicates USA registration.

Separate commercial licenses for SAS software (e.g., SAS Viya) are not included and are required to use these capabilities with SAS software.

All third-party trademarks referenced belong to their respective owners and are only used here for identification and reference purposes, and not to imply any affiliation or endorsement by the trademark owners.

This project requires the usage of the following:

- Python, see the Python license [here](https://docs.python.org/3/license.html)
- FastMCP, under the Apache 2.0 License
- uvicorn, under the BSD 3-Clause
- starlette, under the BSD 3-Clause
- httpx, under the MIT license
