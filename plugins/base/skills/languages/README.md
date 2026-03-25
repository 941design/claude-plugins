# Language Skills

This directory contains language-specific skills that define conventions, tools, and frameworks for property-based testing development.

## Available Languages

| Language | Property Testing Framework | Skill File |
|----------|---------------------------|------------|
| Python | Hypothesis | [`python.md`](python.md) |
| Java | jqwik | [`java.md`](java.md) |
| Kotlin | Kotest Property Testing | [`kotlin.md`](kotlin.md) |
| JavaScript/TypeScript | fast-check | [`javascript-typescript.md`](javascript-typescript.md) |
| Go | gopter / testing/quick | [`go.md`](go.md) |
| Rust | proptest / quickcheck | [`rust.md`](rust.md) |

## What Each Language Skill Contains

Each language skill provides comprehensive guidance for:

### 1. Package Management
- Primary package manager and tools
- Configuration files
- Dependency installation

### 2. Project Configuration
- Standard project structure
- Build configuration
- Environment setup

### 3. Code Style & Standards
- Naming conventions
- Documentation standards (Javadoc, JSDoc, KDoc, etc.)
- Style guides and best practices

### 4. File Organization
- Standard directory layout
- Test file organization
- Module/package structure

### 5. Property-Based Testing
- Framework installation
- Basic usage patterns
- Custom generators/arbitraries
- Stateful testing examples
- Documentation retrieval patterns

### 6. Test Execution
- Running all tests
- Running unit vs integration tests
- Coverage reporting

### 7. Regression Detection
- Baseline capture commands
- Regression check procedures
- Interpretation of results

### 8. Contract Specification Format
- Language-agnostic specification style
- Language-specific implementation examples
- Type annotations and documentation

### 9. Verification Tools
- **Dead Code Detection**: Find unused functions, classes, imports
- **Type System Verification**: Check type annotations and coverage
- **Test Coverage Analysis**: Measure coverage metrics
- **Security Analysis**: Scan for vulnerabilities
- **Documentation Verification**: Check for missing docs
- **Linting and Formatting**: Code quality tools

### 10. Common Commands
- Build, test, run commands
- Package management
- Code formatting

### 11. Documentation Standards
- README conventions
- API documentation generation
- Architecture documentation

### 12. Best Practices
- Separation of concerns
- Error handling
- Security considerations
- Testing strategies
- Code organization

## How Agents Use Language Skills

### integration-architect
- Consults language skill for project setup
- Uses package management conventions
- Follows file organization standards
- Creates language-appropriate contracts and interfaces

### pbt-dev
- Consults language skill for property-based testing framework
- Uses framework-specific syntax
- Follows testing conventions
- Implements using language best practices

### verification-examiner
- Uses verification tools from language skill
- Checks documentation standards
- Validates type annotations
- Runs security and coverage analysis

### system-verifier
- Validates alignment with language conventions
- Checks adherence to best practices
- Verifies proper use of language idioms

## Language Detection

Agents should detect the language from context:

1. **Explicit specification**: User mentions language in request or specification
2. **Project files**: Presence of language-specific config files (check in order of specificity)

   | Language | Primary Indicators | Secondary Indicators |
   |----------|-------------------|---------------------|
   | Python | `pyproject.toml`, `setup.py` | `requirements.txt`, `Pipfile`, `.py` files |
   | Java | `pom.xml`, `build.gradle` | `gradle.properties`, `.java` files |
   | Kotlin | `build.gradle.kts` | `.kt` files |
   | TypeScript | `tsconfig.json` | `package.json` with TypeScript deps, `.ts` files |
   | JavaScript | `package.json` | `.js` files (without TypeScript) |
   | Go | `go.mod` | `go.sum`, `.go` files |
   | Rust | `Cargo.toml` | `Cargo.lock`, `.rs` files |

3. **Existing codebase**: Analyze file extensions and project structure
4. **Fallback**: Ask user to specify language if ambiguous

**Detection Priority**:
1. Look for primary indicators (config files are most reliable)
2. If multiple languages detected (e.g., Python + JavaScript in monorepo), ask user which to use
3. If no indicators found, check for source files by extension
4. If still ambiguous, ask user explicitly

## Extending with New Languages

To add a new language:

1. Create `{language}.md` in this directory
2. Follow the structure of existing language skills
3. Include all sections listed above
4. Update this README with the new language
5. Update agent descriptions to reference the new language

## Usage Example

When implementing a feature in Python:

```markdown
# Integration architect reads python.md:
- Sets up project with pyproject.toml
- Uses uv for package management
- Creates src/ structure with domain/infrastructure separation
- Writes language-agnostic contracts
- Creates stub files following PEP conventions

# pbt-dev reads python.md:
- Uses Hypothesis for property-based testing
- Follows PEP 8, PEP 257, PEP 484 conventions
- Implements with type hints
- Writes tests in tests/unit/ and tests/integration/
- Uses pytest for test execution

# verification-examiner reads python.md:
- Runs mypy for type checking
- Uses bandit for security analysis
- Checks pytest coverage
- Verifies PEP 257 docstrings with pydocstyle
- Validates PEP 484 type hints

# System-verifier:
- Validates alignment with Python best practices
- Checks proper use of Python idioms
- Verifies documentation completeness
```

## Philosophy

**Language-Agnostic at Contract Level, Language-Specific at Implementation**

- **Specifications** use natural language and mathematical notation
- **Contracts** describe behavior without framework-specific details
- **Implementation** uses language idioms and best practices
- **Testing** leverages language-appropriate property-based testing frameworks
- **Verification** uses language-specific tools and conventions

This approach enables:
- Consistent quality across all languages
- Clear separation of "what" (specification) from "how" (implementation)
- Language experts can work in their preferred language
- Easy addition of new languages without changing core workflow
