---
name: go
description: Go language conventions, tools, and frameworks for property-based testing development
language: Go
property_testing_framework: gopter or testing/quick
version_preference: "1.21+"
---

# Go Language Skill

This skill defines Go-specific conventions, tools, and frameworks for feature development with property-based testing.

## Package Management

**Primary Tool**: Go modules (`go.mod`)
- Go modules are the standard dependency management system
- Use `go get` to add dependencies
- Use `go mod tidy` to clean up dependencies

## Project Configuration

**go.mod**:
```go
module github.com/username/project

go 1.21

require (
    github.com/leanovate/gopter v0.2.9
)
```

**Project Layout** (Standard Go Project Layout):
```
project/
├── go.mod
├── go.sum
├── cmd/
│   └── app/
│       └── main.go          # Application entrypoint
├── internal/                # Private application code
│   ├── domain/              # Business logic
│   └── infrastructure/      # External dependencies
├── pkg/                     # Public library code
├── test/
│   ├── unit/                # Unit tests
│   └── integration/         # Integration tests
└── README.md
```

## Code Style & Standards

**Official Style**: gofmt and go vet
- **gofmt**: Automatically format all Go code
- **golint**: Additional style checks
- **go vet**: Static analysis for common mistakes

**Naming Conventions**:
- Packages: lowercase, single word (`domain`, `calculator`)
- Exported: PascalCase (`CalculateDiscount`)
- Unexported: camelCase (`calculateDiscount`)
- Interfaces: `-er` suffix preferred (`Calculator`, `Reader`)
- Constants: MixedCaps (`MaxDiscount`)

**Documentation**: Go doc comments
```go
// CalculateDiscount computes the discounted price.
//
// The discount rate must be between 0 and 100 (inclusive).
// Returns an error if the discount rate is out of bounds.
//
// Properties:
//   - finalPrice <= originalPrice
//   - finalPrice >= 0
func CalculateDiscount(price float64, discountRate float64) (float64, error) {
    // implementation
}
```

## File Organization

**File Conventions**:
- Source files: `*.go`
- Test files: `*_test.go` (in same package)
- Package per directory
- One package declaration per file

**Package Structure**:
```go
package domain

import (
    "errors"
    "fmt"
)

// Types and functions here
```

## File Exclusion Patterns

**Directories to exclude** (Go build artifacts, vendor, caches):
```
vendor/
.idea/
.vscode/
```

**File patterns to exclude**:
```
*.swp
*.swo
*~
.DS_Store
*.tmp
*.log
*.bak
*.orig
go.sum
```

**Search patterns for verification**:
- Source files: `*.go` (excluding `*_test.go`)
- Test files: `*_test.go`
- Import pattern: `^import (\(|".+")`
- Function definition: `^func (\(\w+ \*?\w+\) )?\w+\(`
- Type definition: `^type \w+ (struct|interface)`
- Method definition: `^func \(\w+ \*?\w+\) \w+\(`

## Property-Based Testing

**Frameworks**:
- **gopter**: Full-featured property-based testing (recommended)
- **testing/quick**: Built-in, simpler alternative

### Using gopter

**Installation**:
```bash
go get github.com/leanovate/gopter
```

**Usage Patterns**:

1. **Basic property test**:
```go
package domain_test

import (
    "testing"
    "github.com/leanovate/gopter"
    "github.com/leanovate/gopter/gen"
    "github.com/leanovate/gopter/prop"
)

func TestDiscountNeverNegative(t *testing.T) {
    properties := gopter.NewProperties(nil)

    properties.Property("discounted price is never negative",
        prop.ForAll(
            func(price float64) bool {
                result, _ := CalculateDiscount(price, 10)
                return result >= 0
            },
            gen.Float64Range(0, 1000000),
        ),
    )

    properties.TestingRun(t)
}
```

2. **Custom generators**:
```go
func discountRateGen() gopter.Gen {
    return gen.Float64Range(0, 100)
}

func TestDiscountBounds(t *testing.T) {
    properties := gopter.NewProperties(nil)

    properties.Property("discount stays within bounds",
        prop.ForAll(
            func(price, rate float64) bool {
                result, err := CalculateDiscount(price, rate)
                if err != nil {
                    return false
                }
                return result <= price && result >= 0
            },
            gen.Float64Range(0, 1000000),
            discountRateGen(),
        ),
    )

    properties.TestingRun(t)
}
```

3. **Stateful testing**:
```go
type ShoppingCartCommands struct {
    cart *ShoppingCart
}

func (c *ShoppingCartCommands) AddItem(item string) {
    c.cart.Add(item)
}

func (c *ShoppingCartCommands) CheckInvariant() bool {
    return c.cart.Total() >= 0
}
```

### Using testing/quick (built-in)

```go
import "testing/quick"

func TestDiscountProperty(t *testing.T) {
    f := func(price float64) bool {
        if price < 0 {
            return true // skip negative inputs
        }
        result, _ := CalculateDiscount(price, 10)
        return result >= 0
    }

    if err := quick.Check(f, nil); err != nil {
        t.Error(err)
    }
}
```

## Test Execution

**Standard Go Testing**:
```bash
# All tests
go test ./...

# Unit tests only
go test ./test/unit/...

# Integration tests only
go test ./test/integration/...

# With coverage
go test -cover ./...

# Verbose output
go test -v ./...

# Run specific test
go test -run TestCalculateDiscount
```

## Regression Detection

**Baseline Capture**:
```bash
# Unit tests only
go test ./internal/... > baseline_output.txt 2>&1
```

**Regression Check**:
- Compare test results against baseline
- NEW failures = regression (block)
- Same pre-existing failures = acceptable

## Contract Specification Format

**Language-Agnostic (in specifications)**:
- Natural language types: "decimal number", "collection of items"
- Mathematical notation: `0 ≤ discount_rate ≤ 100`

**Language-Specific (in implementation)**:
```go
// CalculateDiscount computes the final price after applying a discount.
//
// Parameters:
//   - price: Original price (non-negative float64)
//   - discountRate: Discount percentage (0-100)
//
// Returns:
//   - Final price after discount
//   - Error if discount rate is out of bounds
//
// Properties:
//   - finalPrice <= originalPrice
//   - finalPrice >= 0
//   - 0 <= discountRate <= 100
func CalculateDiscount(price, discountRate float64) (float64, error) {
    if discountRate < 0 || discountRate > 100 {
        return 0, errors.New("discount rate must be between 0 and 100")
    }
    // implementation
}
```

## Error Handling

**Go Idiomatic Error Handling**:
```go
// Return errors explicitly
func Calculate(price float64) (float64, error) {
    if price < 0 {
        return 0, errors.New("price cannot be negative")
    }
    return price * 0.9, nil
}

// Check errors at call site
result, err := Calculate(price)
if err != nil {
    return err
}

// Wrap errors for context
import "fmt"

if err != nil {
    return fmt.Errorf("failed to calculate discount: %w", err)
}
```

## Verification Criteria

**Mandatory Questions**:
1. Is there any dead code (unused functions, variables, imports)?
2. Are there any parallel implementations (duplicate/redundant implementations)?
3. Are all obsolete files cleaned up?

**Go-Specific Questions**:
- Are all exported functions and types documented with Go doc comments?
- Is code formatted with gofmt?
- Does `go vet` pass without warnings?
- Are errors handled appropriately (not ignored)?
- Are defer statements used correctly for cleanup?
- Are goroutines and channels used safely (no race conditions)?

## Common Commands

```bash
# Format code
go fmt ./...

# Vet code (static analysis)
go vet ./...

# Install dependencies
go get <package>

# Update dependencies
go get -u ./...

# Clean up dependencies
go mod tidy

# Run tests
go test ./...

# Run tests with race detector
go test -race ./...

# Build
go build ./cmd/app

# Install
go install ./cmd/app
```

## Documentation Standards

### README.md
- Include feature descriptions
- Provide usage examples extracted from integration tests
- Use Go code blocks with proper syntax highlighting

### CHANGELOG.md
Follow Keep a Changelog format:
- Organize by version with `[Unreleased]` section
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security

### API Documentation
Use Go doc comments:

```go
// Package packagename provides brief package description.
//
// More detailed package-level documentation explaining
// the purpose, main types, and usage patterns.
package packagename

// ClassName is a brief one-line summary.
//
// Detailed description explaining the type purpose,
// behavior, and important constraints.
//
// Example usage:
//
//	instance := NewClassName()
//	result := instance.Method()
type ClassName struct {
    // Field descriptions if needed
}

// MethodName is a brief one-line summary.
//
// Detailed description of what the method does.
// Parameters and return values are described in the text.
//
// Example:
//
//	result := instance.MethodName(param1, param2)
func (c *ClassName) MethodName(param1 Type1, param2 Type2) ReturnType {
}
```

**Go doc conventions:**
- First sentence is a summary (appears in pkg.go.dev listings)
- Doc comment immediately precedes declaration
- Start with the name being documented
- Use indented code blocks for examples
- Exported items MUST have doc comments

Generate documentation with: `go doc` or publish to pkg.go.dev

### Architecture Docs
Update if feature adds components. Include package dependencies and data flow.

## Verification Tools

Tools for code quality analysis and verification:

### Dead Code Detection
```bash
# Find unused code
go run golang.org/x/tools/cmd/deadcode@latest ./...

# Alternative: staticcheck
staticcheck ./...

# go vet for suspicious code
go vet ./...

# Manual approach: Find unused functions
grep -r "func functionName" --include="*.go"
grep -r "functionName(" --include="*.go"
```

### Type System Verification
```bash
# Go compiler provides type checking
go build ./...

# Verify types compile
go vet ./...
```

### Test Coverage Analysis
```bash
# Run tests with coverage
go test -cover ./...

# Generate coverage profile
go test -coverprofile=coverage.out ./...

# View coverage in browser
go tool cover -html=coverage.out

# Coverage for specific package
go test -cover ./internal/domain/...
```

### Security Analysis
```bash
# gosec - security scanner
gosec ./...

# go vet for common issues
go vet ./...

# govulncheck - check for known vulnerabilities
go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

### Documentation Verification
```bash
# Check for missing documentation
go doc ./...

# golint checks for doc comments
golint ./...

# Manual: Check for missing comments on exported items
grep -r "^func [A-Z]" --include="*.go"  # Exported functions should have comments above
```

### Linting and Formatting
```bash
# Format code
go fmt ./...

# gofmt with simplification
gofmt -s -w .

# goimports (adds/removes imports)
goimports -w .

# golangci-lint (comprehensive)
golangci-lint run

# staticcheck
staticcheck ./...
```

**Tool Installation**:
```bash
# Install analysis tools
go install golang.org/x/tools/cmd/deadcode@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/securego/gosec/v2/cmd/gosec@latest
go install golang.org/x/vuln/cmd/govulncheck@latest
go install golang.org/x/lint/golint@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

## Best Practices

**Separation of Concerns**:
- Domain logic in `internal/domain/`
- Infrastructure in `internal/infrastructure/`
- Public APIs in `pkg/`

**Interfaces**:
- Accept interfaces, return structs
- Small, focused interfaces (Interface Segregation Principle)
- Define interfaces where they're used, not where they're implemented

**Error Handling**:
- Always check errors
- Wrap errors with context
- Use sentinel errors or error types for specific errors
- Consider errors.Is() and errors.As() for error checking

**Concurrency**:
- Use channels to communicate, not shared memory
- Use sync.Mutex when shared memory is necessary
- Test with `-race` flag
- Use context.Context for cancellation

**Memory Management**:
- Use pointers sparingly (only when needed)
- Avoid premature optimization
- Use `defer` for cleanup
- Consider sync.Pool for frequently allocated objects

**Testing**:
- Property-based tests for business rules (gopter)
- Integration tests for component interactions
- Unit tests for isolated logic
- Table-driven tests for multiple cases
- Use subtests with t.Run()

**Code Organization**:
- One package per directory
- Keep packages focused and cohesive
- Avoid cyclic dependencies
- Use internal/ for private code
- Use pkg/ for public libraries

**Documentation**:
- Document all exported identifiers
- Use complete sentences in doc comments
- First sentence is a summary
- Examples in tests (Example functions)
