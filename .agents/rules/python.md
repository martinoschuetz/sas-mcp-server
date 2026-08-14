# Modern Python Best Coding Practices: The Definitive Guide

> A comprehensive, production-grade guide to writing clean, idiomatic, robust, performant, and maintainable Python. Covers modern standards (Python 3.10+ through 3.12+), type hinting, structural pattern matching, async architectures, packaging, testing, and security.

---

## Table of Contents

1. [Code Style, Formatting & PEP Standards](#1-code-style-formatting--pep-standards)
2. [Modern Typing & Static Analysis](#2-modern-typing--static-analysis)
3. [Idiomatic Pythonic Patterns & Data Structures](#3-idiomatic-pythonic-patterns--data-structures)
4. [Function Design & Decorators](#4-function-design--decorators)
5. [Object-Oriented Design, Dataclasses & Protocols](#5-object-oriented-design-dataclasses--protocols)
6. [Error Handling & Exception Architecture](#6-error-handling--exception-architecture)
7. [Resource Management & Context Managers](#7-resource-management--context-managers)
8. [Asynchronous Programming & Concurrency](#8-asynchronous-programming--concurrency)
9. [Testing, Mocking & Quality Assurance](#9-testing-mocking--quality-assurance)
10. [Modern Project Structure & Dependency Management](#10-modern-project-structure--dependency-management)
11. [Performance Profiling & Memory Optimization](#11-performance-profiling--memory-optimization)
12. [Security, Logging & Production Hardening](#12-security-logging--production-hardening)
13. [The Golden Rules Checklist](#13-the-golden-rules-checklist)

---

## 1. Code Style, Formatting & PEP Standards

Writing readable code is at the core of Python's design philosophy (PEP 20 - *The Zen of Python*).

### Naming Conventions (PEP 8)

| Entity | Convention | Example |
| :--- | :--- | :--- |
| **Modules / Packages** | `lowercase_with_underscores` (short) | `data_loader.py`, `models/` |
| **Classes / Exceptions** | `PascalCase` | `UserAccount`, `DatabaseConnectionError` |
| **Functions / Methods** | `snake_case` | `calculate_total_price()`, `sync_cache()` |
| **Variables / Attributes** | `snake_case` | `user_id`, `is_active` |
| **Constants** | `UPPER_SNAKE_CASE` | `MAX_RETRY_ATTEMPTS`, `DEFAULT_TIMEOUT_SEC` |
| **Protected Members** | `_single_leading_underscore` | `_internal_buffer`, `_parse_raw_payload()` |
| **Private Members (Mangled)** | `__double_leading_underscore` | `__sensitive_salt` *(use sparingly)* |
| **Type Variables** | `PascalCase` or `UPPERCASE` | `T`, `UserType`, `ModelT` |

### Tooling Standards (Ruff, Black, isort)

In modern development, do not waste human review time on formatting debates. Automate formatting and linting in your pre-commit hooks and CI/CD pipelines.

- **Ruff**: Extremely fast linter and formatter written in Rust. Replaces Flake8, Black, isort, pydocstyle, and pyupgrade in a single unified tool.

```toml
# pyproject.toml configuration
[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings
    "F",   # Pyflakes
    "I",   # isort (import sorting)
    "B",   # flake8-bugbear (common bug patterns)
    "C4",  # flake8-comprehensions
    "UP",  # pyupgrade (modernize Python syntax)
    "ARG", # flake8-unused-arguments
    "SIM", # flake8-simplify
    "TCH", # flake8-type-checking (optimize imports)
]
ignore = ["E501"] # Let formatter handle line wraps
```

### Import Ordering

Group imports in three distinct blocks separated by a blank line:
1. Standard library imports
2. Third-party packages
3. First-party local application modules

```python
# GOOD: Clean, structured imports
import asyncio
from collections.abc import AsyncIterator, Sequence
from pathlib import Path

import httpx
from pydantic import BaseModel, Field

from myapp.core.config import settings
from myapp.services.auth import AuthService
```

---

## 2. Modern Typing & Static Analysis

Type hints (PEP 484, PEP 585, PEP 604) improve maintainability, IDE auto-completion, and enable static type checkers like **Mypy** or **Pyright**.

### Python 3.10+ Built-in Generic & Union Syntax

Avoid legacy imports from `typing` (`List`, `Dict`, `Optional`, `Union`, `Tuple`). Use native types and pipe `|` operators.

```python
# BAD (Legacy Python <3.10)
from typing import List, Dict, Optional, Union, Tuple

def parse_items(data: Optional[Dict[str, Union[int, str]]]) -> List[Tuple[str, int]]:
    pass

# GOOD (Modern Python 3.10+)
def parse_items(data: dict[str, int | str] | None) -> list[tuple[str, int]]:
    if not data:
        return []
    return [(k, int(v)) for k, v in data.items() if str(v).isdigit()]
```

### Protocols vs ABCs (Structural Subtyping / Static Duck Typing)

Use `typing.Protocol` (PEP 544) when defining interfaces based on behavior rather than explicit class inheritance.

```python
from typing import Protocol

class Renderable(Protocol):
    def render(self) -> str:
        ...

class Button:
    def render(self) -> str:
        return "<button>Click Me</button>"

class Image:
    def render(self) -> str:
        return "<img src='hero.png' />"

# Accepts any object that has a matching .render() method without requiring inheritance
def draw_ui(elements: list[Renderable]) -> str:
    return "\n".join(element.render() for element in elements)
```

### Advanced Type Constructs: `Self`, `Literal`, and `TypedDict`

```python
from typing import Literal, Self, TypedDict

# Literal for constrained string enums
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]

def set_log_level(level: LogLevel) -> None:
    print(f"Setting log level to {level}")

# Self type for fluent interfaces / builder pattern (PEP 673)
class QueryBuilder:
    def __init__(self) -> None:
        self._conditions: list[str] = []

    def filter_by(self, condition: str) -> Self:
        self._conditions.append(condition)
        return self

# TypedDict for structured dictionaries
class UserPayload(TypedDict):
    id: int
    username: str
    email: str
    is_active: bool
```

---

## 3. Idiomatic Pythonic Patterns & Data Structures

### Truth Value Testing

Do not compare explicitly with `True`, `False`, `None`, or empty containers.

```python
# BAD
if is_valid == True: ...
if len(users) == 0: ...
if data != None: ...

# GOOD
if is_valid: ...
if not users: ...
if data is not None: ...  # Explicit identity check for None
```

### `zip(..., strict=True)` and `enumerate`

```python
# BAD
i = 0
for item in items:
    print(i, item)
    i += 1

# GOOD: enumerate with optional starting index
for idx, item in enumerate(items, start=1):
    print(f"{idx}: {item}")

# GOOD: strict zip prevents silent truncation bugs when sequences differ in length
names = ["Alice", "Bob", "Charlie"]
scores = [95, 87, 92]
for name, score in zip(names, scores, strict=True):
    print(f"{name}: {score}")
```

### Structural Pattern Matching (`match` / `case`)

Introduced in Python 3.10 (PEP 634), pattern matching is significantly more powerful than simple `switch` statements, supporting destructuring and guard conditions.

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Coordinate:
    x: float
    y: float

def process_command(command: dict[str, object] | Coordinate) -> str:
    match command:
        case Coordinate(x=0, y=0):
            return "Origin"
        case Coordinate(x=x, y=y) if x == y:
            return f"Diagonal at {x}"
        case {"action": "move", "direction": ("north" | "south" | "east" | "west") as direction, "distance": int(d)}:
            return f"Moving {direction} by {d} units"
        case {"action": "quit"}:
            return "Exiting"
        case _:
            raise ValueError(f"Unrecognized command: {command}")
```

### Assignment Expressions (Walrus Operator `:=`)

Use the walrus operator (PEP 572) to capture values during evaluation and avoid redundant computations.

```python
import re

pattern = re.compile(r"ID:(\d+)")

# Capture in conditional check
if match := pattern.search(raw_line):
    user_id = match.group(1)
```

### Comprehensions vs Generators

```python
# Memory Heavy: Eager list instantiation in memory
total = sum([x**2 for x in range(10_000_000)])

# Memory Efficient: Lazy generator expression, O(1) memory overhead
total = sum(x**2 for x in range(10_000_000))
```

---

## 4. Function Design & Decorators

### Avoid Mutable Default Arguments

Default arguments are evaluated once at function definition time, NOT at invocation time.

```python
# DANGEROUS / BUGGY
def append_item(item: str, target_list: list[str] = []) -> list[str]:
    target_list.append(item)
    return target_list

# SAFE: Sentinel pattern
def append_item(item: str, target_list: list[str] | None = None) -> list[str]:
    if target_list is None:
        target_list = []
    target_list.append(item)
    return target_list
```

### Keyword-Only and Positional-Only Arguments (PEP 570, PEP 3102)

Use `/` for positional-only arguments (callers cannot use keyword names) and `*` for keyword-only arguments (forces explicit naming at call site).

```python
def configure_cache(
    backend: str,           # Positional-or-keyword
    /,                      # Everything before this is positional-only
    max_size: int = 1000,   # Positional-or-keyword
    *,                      # Everything after this is keyword-only
    timeout_sec: float = 30.0,
    eviction_policy: str = "LRU",
) -> None:
    pass

# Call site:
# configure_cache("redis", 5000, timeout_sec=60.0, eviction_policy="FIFO")
```

### Writing Robust, Type-Preserving Decorators

Always use `@functools.wraps` to preserve docstrings, function signatures, and metadata. Use `ParamSpec` and `TypeVar` for static type safety.

```python
import functools
import time
from collections.abc import Callable
from typing import ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")

def time_it(func: Callable[P, R]) -> Callable[P, R]:
    '''Decorator to measure and log function execution time.'''
    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        start_time = time.perf_counter()
        try:
            return func(*args, **kwargs)
        finally:
            elapsed = time.perf_counter() - start_time
            print(f"[METRIC] {func.__qualname__} executed in {elapsed:.4f}s")
    return wrapper

@time_it
def compute_heavy_hash(data: str, iterations: int = 100_000) -> str:
    return f"hash_{len(data)}_{iterations}"
```

---

## 5. Object-Oriented Design, Dataclasses & Protocols

### Modern `@dataclass` vs Plain Classes

For data-holding structures, prefer `@dataclass(slots=True, frozen=True)` for immutability, auto-generated dunder methods (`__init__`, `__repr__`, `__eq__`), and reduced memory overhead.

```python
from dataclasses import dataclass, field
from datetime import datetime, timezone
import uuid

@dataclass(slots=True, frozen=True)
class CustomerOrder:
    customer_id: str
    items: tuple[str, ...]
    order_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def item_count(self) -> int:
        return len(self.items)
```

### When to Use Pydantic vs `dataclasses`

- Use **`dataclasses`** for internal domain models, high-performance computational structures, and when third-party dependencies must be minimized.
- Use **`pydantic.BaseModel`** (v2+) for parsing and validating external boundary data (API request/response payloads, configuration files, JSON deserialization).

```python
from pydantic import BaseModel, EmailStr, Field

class CreateUserSchema(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    age: int = Field(..., ge=18, le=120)
    tags: list[str] = Field(default_factory=list)
```

### Composition Over Inheritance

Avoid deep inheritance trees. Compose smaller, specialized components with dependency injection.

```python
# GOOD: Explicit Dependency Injection & Composition
from typing import Any

class AuditService:
    def __init__(self, db_client: Any, logger: Any) -> None:
        self._db = db_client
        self._logger = logger

    def record_event(self, event_name: str, payload: dict[str, Any]) -> None:
        self._db.insert("audit_logs", {"event": event_name, "payload": payload})
        self._logger.info("Audit log recorded: %s", event_name)
```

---

## 6. Error Handling & Exception Architecture

### Custom Exception Hierarchies

Define a root domain exception for each package or subsystem. This allows consumers to catch either broad or granular errors.

```python
class AppError(Exception):
    '''Base exception for all application errors.'''
    pass

class StorageError(AppError):
    '''Base exception for storage subsystem.'''
    pass

class ItemNotFoundError(StorageError):
    '''Raised when an item does not exist in storage.'''
    def __init__(self, item_id: str) -> None:
        super().__init__(f"Item with ID '{item_id}' was not found.")
        self.item_id = item_id

class StorageCapacityError(StorageError):
    '''Raised when storage limits are exceeded.'''
    pass
```

### Exception Chaining with `raise ... from`

Always chain exceptions when re-wrapping low-level errors into domain exceptions to preserve the underlying traceback.

```python
import sqlite3

def fetch_user_record(user_id: str) -> dict[str, str]:
    try:
        raise sqlite3.OperationalError("Disk I/O error")
    except sqlite3.Error as err:
        # 'from err' preserves the original sqlite3 stack trace
        raise StorageError(f"Failed to retrieve user {user_id} due to database error.") from err
```

### Proper `try / except / else / finally` Structure

Keep `try` blocks minimal to avoid masking unexpected exceptions.

```python
def execute_transaction(connection_pool, transaction_data: dict) -> None:
    try:
        conn = connection_pool.get_connection()
    except Exception as exc:
        logger.error("Failed to acquire database connection: %s", exc)
        raise

    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE accounts SET balance = balance - 10")
    except Exception as exc:
        conn.rollback()
        logger.exception("Transaction failed; rolled back.")
        raise StorageError("Database transaction failed") from exc
    else:
        conn.commit()
        logger.info("Transaction committed successfully.")
    finally:
        connection_pool.release_connection(conn)
```

---

## 7. Resource Management & Context Managers

Never rely on manual cleanup or garbage collection for operating system resources (file handles, network sockets, database connections, locks).

### Class-Based Context Managers

```python
from types import TracebackType
from typing import Self

class ManagedResource:
    def __enter__(self) -> Self:
        print("Acquiring resource...")
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> bool | None:
        print("Releasing resource...")
        # Return True only if you intentionally want to suppress the raised exception
        return False
```

### Generator Context Managers with `@contextlib.contextmanager`

```python
from collections.abc import Iterator
import contextlib
import time

@contextlib.contextmanager
def temporary_metric(metric_name: str) -> Iterator[dict[str, float]]:
    stats = {"start": time.perf_counter(), "duration": 0.0}
    try:
        yield stats
    finally:
        stats["duration"] = time.perf_counter() - stats["start"]
        print(f"Metric '{metric_name}' finalized in {stats['duration']:.4f}s")

# Usage:
with temporary_metric("data_processing") as metric:
    time.sleep(0.05)
```

---

## 8. Asynchronous Programming & Concurrency

### Core Async Principles

1. **Never block the event loop**: Offload CPU-bound or synchronous blocking I/O to worker threads via `asyncio.to_thread`.
2. **Use `asyncio.TaskGroup`** (Python 3.11+) instead of legacy `asyncio.gather` for structured concurrency and safe exception propagation.

```python
import asyncio
import httpx

async def fetch_status(client: httpx.AsyncClient, url: str) -> int:
    response = await client.get(url, timeout=5.0)
    return response.status_code

async def check_all_endpoints(urls: list[str]) -> list[int]:
    results: list[int] = []
    async with httpx.AsyncClient() as client:
        # Structured concurrency with TaskGroup (Python 3.11+)
        async with asyncio.TaskGroup() as tg:
            tasks = [tg.create_task(fetch_status(client, url)) for url in urls]
        # At this point, all tasks have completed cleanly or raised an ExceptionGroup
        results = [t.result() for t in tasks]
    return results
```

### Managing Long-Running Blocking Code in Async Apps

```python
import asyncio
import hashlib

def cpu_bound_hash(content: bytes) -> str:
    '''Synchronous CPU-intensive operation.'''
    return hashlib.sha256(content).hexdigest()

async def handle_upload(data: bytes) -> str:
    # Run blocking work in default thread pool executor without stalling the event loop
    digest = await asyncio.to_thread(cpu_bound_hash, data)
    return digest
```

---

## 9. Testing, Mocking & Quality Assurance

### Pytest Fixture Architecture

Use explicit, modular fixtures with appropriate scopes (`function`, `session`, `module`).

```python
# conftest.py
import pytest
from collections.abc import Generator
from typing import Any

@pytest.fixture(scope="session")
def test_config() -> dict[str, Any]:
    return {"api_url": "https://test.local", "timeout": 5}

@pytest.fixture
def mock_db() -> Generator[dict[str, str], None, None]:
    db = {"user_1": "active"}
    yield db
    db.clear()
```

### Parametrized Testing

Avoid duplicating test bodies for multiple input/output pairs.

```python
import pytest

def calculate_discount(price: float, is_vip: bool) -> float:
    if price < 0:
        raise ValueError("Price cannot be negative")
    rate = 0.20 if is_vip else 0.05
    return round(price * (1 - rate), 2)

@pytest.mark.parametrize(
    ("price", "is_vip", "expected"),
    [
        (100.0, False, 95.0),
        (100.0, True, 80.0),
        (0.0, False, 0.0),
        (50.0, True, 40.0),
    ],
)
def test_calculate_discount(price: float, is_vip: bool, expected: float) -> None:
    assert calculate_discount(price, is_vip) == expected

def test_calculate_discount_negative_raises() -> None:
    with pytest.raises(ValueError, match="Price cannot be negative"):
        calculate_discount(-10.0, False)
```

---

## 10. Modern Project Structure & Dependency Management

### Standard `src`-Layout

The `src` layout prevents import confusion where tests accidentally import uninstalled local packages rather than testing against the built/installed artifact.

```text
my-awesome-project/
├── .github/
│   └── workflows/
│       └── ci.yml
├── src/
│   └── my_project/
│       ├── __init__.py
│       ├── py.typed             # PEP 561 marker for type hints
│       ├── core/
│       │   ├── __init__.py
│       │   ├── config.py
│       │   └── exceptions.py
│       ├── services/
│       │   ├── __init__.py
│       │   └── processor.py
│       └── utils/
│           ├── __init__.py
│           └── string_utils.py
├── tests/
│   ├── conftest.py
│   ├── unit/
│   │   └── test_processor.py
│   └── integration/
│       └── test_database.py
├── .gitignore
├── .pre-commit-config.yaml
├── README.md
└── pyproject.toml
```

### Standard `pyproject.toml` (PEP 621)

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "my-project"
version = "0.1.0"
description = "High-performance data transformation engine"
readme = "README.md"
requires-python = ">=3.11"
authors = [
    { name = "Lead Engineer", email = "engineer@example.com" }
]
dependencies = [
    "httpx>=0.27.0",
    "pydantic>=2.7.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "pytest-cov>=5.0.0",
    "mypy>=1.10.0",
    "ruff>=0.4.0",
    "pre-commit>=3.7.0",
]

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
```

---

## 11. Performance Profiling & Memory Optimization

### Built-in Caching (`@functools.lru_cache`, `@functools.cache`)

```python
import functools

# Unbounded memoization (Python 3.9+)
@functools.cache
def fibonacci(n: int) -> int:
    if n < 2:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

# Bounded LRU cache
@functools.lru_cache(maxsize=1024)
def get_user_permissions(user_id: int) -> frozenset[str]:
    # Simulate expensive database lookup
    return frozenset(["read", "write"])
```

### Memory Savings with `__slots__`

Standard Python objects store attributes in a dynamic `__dict__`. Using `__slots__` bypasses this, slashing memory consumption by 40-70% when instantiating millions of records.

```python
class PointSlots:
    __slots__ = ("x", "y", "z")

    def __init__(self, x: float, y: float, z: float) -> None:
        self.x = x
        self.y = y
        self.z = z
```

### Fast String Concatenation

```python
# BAD: O(n^2) quadratic complexity due to string immutability
tokens = ["a", "b", "c"]
result = ""
for token in tokens:
    result += token

# GOOD: O(n) linear complexity using str.join
result = "".join(tokens)
```

---

## 12. Security, Logging & Production Hardening

### Structured Logging Over `print()`

Never use `print()` statements in production code. Use standard `logging` configured with structured JSON outputs.

```python
import logging
import sys

logger = logging.getLogger("myapp.service")

def setup_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        '{"timestamp":"%(asctime)s", "level":"%(levelname)s", "logger":"%(name)s", "message":"%(message)s"}'
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

# Log with parameterized format (DO NOT use f-strings inside logger calls)
# This defers string interpolation until it is confirmed the log level is active
logger.info("Processing order for user_id=%s, amount=%.2f", "usr_123", 99.50)
```

### Secret & Configuration Management

Never hardcode credentials or API keys. Use environment variables with type validation via `pydantic-settings`.

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import SecretStr

class Settings(BaseSettings):
    app_env: str = "production"
    database_url: SecretStr
    jwt_secret_key: SecretStr
    max_connections: int = 50

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

settings = Settings()
# Access secret value safely: settings.jwt_secret_key.get_secret_value()
```

### Secure Deserialization & Evaluation

- **Avoid `eval()`, `exec()`, `input()` for untrusted expressions.**
- **Avoid `pickle`** for loading data from untrusted sources (can trigger arbitrary remote code execution). Prefer JSON, MessagePack, or Protocol Buffers.
- **Prevent SQL Injection**: Always use parameterized queries or ORM expressions. Never use string interpolation (`f"SELECT * FROM users WHERE id = '{uid}'"`).

---

## 13. The Golden Rules Checklist

Before pushing code to production or submitting a pull request, verify:

- [ ] **Type Annotations**: All function signatures have complete argument and return type annotations.
- [ ] **Static Type Checking**: `mypy --strict` or `pyright` passes with zero errors.
- [ ] **Automated Linting & Formatting**: `ruff check` and `ruff format` pass cleanly.
- [ ] **No Mutable Defaults**: No `def fn(items=[])` or `def fn(config={})`.
- [ ] **Context Management**: Files, locks, and network sockets are encapsulated in `with` / `async with` blocks.
- [ ] **Specific Exceptions**: No bare `except:` or overbroad `except Exception:` catching without re-raising.
- [ ] **Structured Concurrency**: Async workflows utilize `asyncio.TaskGroup` and do not block the event loop.
- [ ] **Clean Tests**: Unit and integration tests achieve high coverage with parametrized fixtures.
- [ ] **Secure Config**: All secrets are fetched from environment variables via typed settings.
- [ ] **Performance Consciousness**: Heavy lookups use sets/dicts, large collections stream via generators, and `str.join()` handles bulk string assembly.

---
*Generated following Python 3.10–3.12+ engineering standards.*
