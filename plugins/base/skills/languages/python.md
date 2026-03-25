---
name: python
description: Python language conventions, tools, and frameworks for property-based testing development
language: Python
property_testing_framework: hypothesis
version_preference: "3.11+"
---

# Python Language Skill

This skill defines Python-specific conventions, tools, and frameworks for feature development with property-based testing.

## Package Management

**Primary Tool**: `uv`
- Use `uv` for all package management and virtual environment access
- Install dependencies via `uv add <package>`
- Run commands in virtual environment via `uv run <command>`

## Project Configuration

**Standard**: PEP 517/518
- Use `pyproject.toml` for all project configuration
- No separate `setup.py` or `requirements.txt` files
- Package metadata, dependencies, and tool configs in `pyproject.toml`

## Code Style & Standards

**Style Guide**: PEP 8
- Follow PEP 8 for all code style conventions
- Prefer automated formatters (black, ruff) over manual formatting

**Type Hints**: PEP 484
- Use type hints throughout all code
- Annotate function signatures, class attributes, and variables
- Use `typing` module for complex types (Union, Optional, List, Dict, etc.)

**Docstrings**: PEP 257
- Follow PEP 257 docstring conventions
- Include docstrings for all public modules, classes, and functions
- Format: Google-style or NumPy-style (match project convention)

## File Organization

**Project Structure**:
```
project/
├── pyproject.toml
├── src/
│   └── package_name/
│       ├── __init__.py
│       ├── domain/         # Business logic
│       └── infrastructure/ # External dependencies
├── tests/
│   ├── unit/              # Unit tests (included in regression checks)
│   └── integration/       # Integration tests (excluded from regression)
└── README.md
```

**Test Organization**:
- Unit tests: `tests/unit/`, `test_*.py`, `*_test.py`
- Integration tests: `tests/integration/`, `*_integration_test.py`
- Exclude integration from regression: `tests/integration/`, `tests/e2e/`, `*_e2e_test.py`

## File Exclusion Patterns

**Directories to exclude** (Python build artifacts, caches, virtual environments):
```
__pycache__/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.tox/
.hypothesis/
.cache/
htmlcov/
build/
dist/
*.egg-info/
.eggs/
venv/
env/
.venv/
.vscode/
.idea/
docs/_build/
```

**File patterns to exclude**:
```
*.pyc
*.pyo
*.pyd
*.egg
*.cover
.coverage
*.tmp
*.log
*.bak
*.orig
*.swp
*.swo
*~
.DS_Store
.env
```

**Search patterns for verification**:
- Source files: `*.py`
- Test files: `test_*.py`, `*_test.py`
- Import pattern: `^import ` or `^from .* import `
- Function definition: `^def \w+\(`
- Class definition: `^class \w+[(:)]`

## Property-Based Testing

**Framework**: Hypothesis

**Installation**:
```bash
uv add hypothesis pytest
```

**Usage Patterns**:

1. **Basic property test**:
```python
from hypothesis import given
from hypothesis import strategies as st

@given(st.integers())
def test_property(value):
    assert function_under_test(value) >= 0
```

2. **Custom strategies**:
```python
from hypothesis import strategies as st

discount_strategy = st.decimals(
    min_value=0,
    max_value=100,
    places=2
)

@given(st.builds(DiscountCalculator, discount_rate=discount_strategy))
def test_discount_bounds(calculator):
    assert 0 <= calculator.calculate() <= 100
```

3. **Stateful testing**:
```python
from hypothesis.stateful import RuleBasedStateMachine, rule

class ShoppingCartMachine(RuleBasedStateMachine):
    @rule(item=st.text())
    def add_item(self, item):
        self.cart.add(item)

    @rule()
    def check_invariant(self):
        assert self.cart.total >= 0
```

**Documentation Retrieval**:
- "Retrieve Hypothesis documentation for testing custom strategies"
- "Get Hypothesis examples for stateful testing"
- "Find Hypothesis API for generators and strategies"

## Test Execution

**Test Runner**: pytest

**Unit Tests (for regression detection)**:
```bash
pytest tests/unit/ --tb=line --no-header -q
```

**All Tests**:
```bash
pytest
```

**Integration Tests Only**:
```bash
pytest tests/integration/
```

## Regression Detection

**Baseline Capture**:
```bash
# Before implementation - unit tests only
pytest tests/unit/ --tb=line --no-header -q 2>&1 | tee baseline_output.txt
```

**Regression Check**:
```bash
# After implementation - compare against baseline
pytest tests/unit/ --tb=line --no-header -q
# Compare failed test names against baseline
# NEW failures = regression (block)
# Same pre-existing failures = acceptable
```

**Important**:
- Only unit tests in baseline
- Integration tests excluded from all regression checks
- Pre-existing failures don't block progression
- New failures introduced by implementation DO block

## Dependency Management

**pyproject.toml format**:
```toml
[project]
name = "package-name"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "hypothesis>=6.0",
    "pytest>=7.0",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]

[tool.ruff]
line-length = 88
```

## Contract Specification Format

**Language-Agnostic (in specifications)**:
- Use natural language type descriptions: "decimal number", "collection of items"
- Mathematical notation for properties: `0 ≤ discount_rate ≤ 100`
- Pseudocode for algorithms
- Avoid framework-specific references

**Language-Specific (in implementation)**:
```python
# Type hints follow PEP 484
def calculate_discount(price: Decimal, discount_rate: Decimal) -> Decimal:
    """
    Calculate discounted price.

    Args:
        price: Original price (non-negative decimal)
        discount_rate: Discount percentage (0-100)

    Returns:
        Final price after discount

    Properties:
        - final_price <= original_price
        - 0 <= final_price
        - discount_rate bounds: 0 <= discount_rate <= 100
    """
    pass
```

## Verification Criteria

**Mandatory Questions**:
1. Is there any dead code (unused functions, classes, or imports)?
2. Are there any parallel implementations (duplicate/redundant implementations)?
3. Are all obsolete files cleaned up?

**Python-Specific Questions**:
- Are all functions and classes documented with PEP 257 docstrings?
- Are all type hints properly used throughout (PEP 484)?
- Is dependency management properly configured in pyproject.toml?
- Are data classes properly typed with all fields annotated?

**Excluded (automated by tools)**:
- PEP 8 style compliance (use ruff/black)
- Import sorting (use isort)
- Line length limits (use formatter)

## Common Commands

**Setup project**:
```bash
uv init
uv add hypothesis pytest
```

**Run tests**:
```bash
uv run pytest
```

**Run specific test file**:
```bash
uv run pytest tests/unit/test_feature.py
```

**Install dependency**:
```bash
uv add <package-name>
```

**Install dev dependency**:
```bash
uv add --dev <package-name>
```

## Documentation Standards

### README.md
- Include feature descriptions
- Provide usage examples extracted from integration tests
- Use Python code blocks with proper syntax highlighting

### CHANGELOG.md
Follow Keep a Changelog format:
- Organize by version with `[Unreleased]` section
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security

### API Documentation
Use docstrings following PEP 257:

```python
class ClassName:
    """Brief one-line summary.

    Detailed description explaining the class purpose,
    behavior, and important constraints.

    Attributes:
        attribute_name (type): Description of attribute

    Example:
        >>> instance = ClassName()
        >>> instance.method()
        expected_result

    Note:
        Any important notes about usage or behavior.
    """
```

Function/method docstring format:
```python
def function_name(param1: Type1, param2: Type2) -> ReturnType:
    """Brief one-line summary.

    Args:
        param1: Description of param1
        param2: Description of param2

    Returns:
        Description of return value

    Raises:
        ExceptionType: When and why this is raised

    Example:
        >>> function_name(value1, value2)
        expected_result
    """
```

Auto-generate API docs using Sphinx or similar tools.

### Architecture Docs
Update if feature adds components. Include module dependencies and data flow diagrams.

## Verification Tools

Tools for code quality analysis and verification:

### Dead Code Detection
```bash
# Find unused imports and variables
uv run pyflakes <module>

# Comprehensive linting (includes unused code)
uv run pylint <module>

# Manual approach: Find unused functions
grep -r "def function_name" --include="*.py"
grep -r "function_name(" --include="*.py"
```

### Type System Verification
```bash
# Strict type checking
uv run mypy --strict <module>

# Check specific file
uv run mypy <file>.py

# Generate type coverage report
uv run mypy --html-report ./mypy-report <module>
```

### Test Coverage Analysis
```bash
# Run tests with coverage
uv run pytest --cov=<module> --cov-report=term-missing

# Generate HTML coverage report
uv run pytest --cov=<module> --cov-report=html

# Coverage for specific test file
uv run pytest tests/test_feature.py --cov=<module>
```

### Security Analysis
```bash
# Scan for security vulnerabilities
uv run bandit -r <module>

# Check for known vulnerabilities in dependencies
uv run safety check

# Comprehensive security scan
uv run bandit -r <module> -f json -o security_report.json
```

### Documentation Verification
```bash
# Check for missing docstrings
uv run pydocstyle <module>

# Verify docstring style (PEP 257)
uv run pydocstyle --convention=pep257 <module>
```

### Linting and Formatting
```bash
# Fast Python linter
uv run ruff check <module>

# Format code
uv run black <module>

# Sort imports
uv run isort <module>
```

**Tool Installation**:
```bash
uv add --dev mypy pytest pytest-cov bandit safety pydocstyle ruff black isort pyflakes pylint
```

## Best Practices

**Separation of Concerns**:
- Domain logic in `src/<package>/domain/`
- Infrastructure/external dependencies in `src/<package>/infrastructure/`

**Error Handling**:
- Raise specific exceptions (ValueError, TypeError, etc.)
- Document exceptions in docstrings
- Validate at system boundaries (user input, external APIs)

**Security**:
- Validate all external input
- Avoid SQL injection (use parameterized queries)
- No hardcoded secrets (use environment variables)

**Testing**:
- Property-based tests for business rules
- Integration tests for component interactions
- Unit tests for isolated logic
- Test edge cases and failure scenarios
