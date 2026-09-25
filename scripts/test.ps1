Write-Host "Running Ruff Formatter..." -ForegroundColor Cyan
uv run ruff format .

Write-Host "
Running Ruff Linter..." -ForegroundColor Cyan
uv run ruff check .

Write-Host "
Running Pyright Type Checker..." -ForegroundColor Cyan
uv run pyright src

Write-Host "
Running Pytest Unit Tests..." -ForegroundColor Cyan
uv run pytest
