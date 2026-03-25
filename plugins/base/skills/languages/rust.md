---
name: rust
description: Rust language conventions, tools, and frameworks for property-based testing development
language: Rust
property_testing_framework: proptest or quickcheck
version_preference: "1.70+"
---

# Rust Language Skill

This skill defines Rust-specific conventions, tools, and frameworks for feature development with property-based testing.

## Package Management

**Primary Tool**: Cargo
- Cargo is the standard build tool and package manager
- `Cargo.toml` for project configuration and dependencies
- `Cargo.lock` for locked dependency versions

## Project Configuration

**Cargo.toml**:
```toml
[package]
name = "project-name"
version = "0.1.0"
edition = "2021"
rust-version = "1.70"

[dependencies]
# Production dependencies

[dev-dependencies]
proptest = "1.4"
# or
quickcheck = "1.0"

[[bin]]
name = "app"
path = "src/main.rs"

[lib]
name = "project_name"
path = "src/lib.rs"
```

## Code Style & Standards

**Official Style**: rustfmt and clippy
- **rustfmt**: Automatically format all Rust code
- **clippy**: Linter for catching common mistakes and improving code

**Naming Conventions**:
- Crates: snake_case (`my_crate`)
- Modules: snake_case (`discount_calculator`)
- Types/Traits: PascalCase (`DiscountCalculator`, `Calculate`)
- Functions/Variables: snake_case (`calculate_discount`)
- Constants: SCREAMING_SNAKE_CASE (`MAX_DISCOUNT`)
- Lifetimes: short lowercase (`'a`, `'b`)

**Documentation**: Rust doc comments
```rust
/// Calculates the discounted price.
///
/// # Arguments
///
/// * `price` - The original price (must be non-negative)
/// * `discount_rate` - The discount percentage (0-100)
///
/// # Returns
///
/// The final price after applying the discount
///
/// # Errors
///
/// Returns `Err` if discount rate is out of bounds
///
/// # Properties
///
/// - final_price <= original_price
/// - final_price >= 0
pub fn calculate_discount(price: f64, discount_rate: f64) -> Result<f64, String> {
    // implementation
}
```

## File Organization

**Project Structure**:
```
project/
├── Cargo.toml
├── Cargo.lock
├── src/
│   ├── lib.rs              # Library root
│   ├── main.rs             # Binary entrypoint
│   ├── domain/             # Business logic module
│   │   ├── mod.rs
│   │   └── calculator.rs
│   └── infrastructure/     # External dependencies module
│       └── mod.rs
├── tests/                  # Integration tests
│   ├── integration_test.rs
│   └── common/
│       └── mod.rs
└── README.md
```

**Test Organization**:
- Unit tests: Same file as code (`#[cfg(test)] mod tests { ... }`)
- Integration tests: `tests/` directory
- Each file in `tests/` is a separate crate

## File Exclusion Patterns

**Directories to exclude** (Cargo build artifacts, caches):
```
target/
.cargo/
.idea/
.vscode/
```

**File patterns to exclude**:
```
Cargo.lock
*.swp
*.swo
*~
.DS_Store
*.tmp
*.log
*.bak
*.orig
```

**Search patterns for verification**:
- Source files: `*.rs`
- Test files: files containing `#[cfg(test)]` or files in `tests/` directory
- Import pattern: `^use .+;`
- Function definition: `^(pub )?fn \w+`
- Struct definition: `^(pub )?struct \w+`
- Trait definition: `^(pub )?trait \w+`
- Impl block: `^impl\s`

## Property-Based Testing

**Frameworks**:
- **proptest**: Full-featured, macro-based (recommended)
- **quickcheck**: Simpler, attribute-based

### Using proptest

**Installation**:
```toml
[dev-dependencies]
proptest = "1.4"
```

**Usage Patterns**:

1. **Basic property test**:
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    proptest! {
        #[test]
        fn test_discount_never_negative(price in 0.0f64..1000000.0) {
            let result = calculate_discount(price, 10.0).unwrap();
            prop_assert!(result >= 0.0);
        }
    }
}
```

2. **Custom strategies**:
```rust
use proptest::prelude::*;

fn discount_rate_strategy() -> impl Strategy<Value = f64> {
    (0.0..=100.0)
}

fn price_strategy() -> impl Strategy<Value = f64> {
    (0.0..1000000.0)
}

proptest! {
    #[test]
    fn test_discount_bounds(
        price in price_strategy(),
        rate in discount_rate_strategy()
    ) {
        let result = calculate_discount(price, rate).unwrap();
        prop_assert!(result <= price);
        prop_assert!(result >= 0.0);
    }
}
```

3. **Testing with custom types**:
```rust
use proptest::prelude::*;

#[derive(Debug, Clone)]
struct Cart {
    items: Vec<String>,
}

impl Arbitrary for Cart {
    type Parameters = ();
    type Strategy = BoxedStrategy<Self>;

    fn arbitrary_with(_: Self::Parameters) -> Self::Strategy {
        prop::collection::vec(any::<String>(), 0..100)
            .prop_map(|items| Cart { items })
            .boxed()
    }
}

proptest! {
    #[test]
    fn test_cart_total_non_negative(cart: Cart) {
        prop_assert!(cart.total() >= 0.0);
    }
}
```

### Using quickcheck

**Installation**:
```toml
[dev-dependencies]
quickcheck = "1.0"
quickcheck_macros = "1.0"
```

**Usage**:
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use quickcheck_macros::quickcheck;

    #[quickcheck]
    fn test_discount_never_negative(price: f64) -> bool {
        if price < 0.0 {
            return true;
        }
        calculate_discount(price, 10.0).map(|r| r >= 0.0).unwrap_or(true)
    }
}
```

## Test Execution

**Cargo Test**:
```bash
# All tests
cargo test

# Unit tests only (tests in src/)
cargo test --lib

# Integration tests only (tests in tests/)
cargo test --test '*'

# Specific test
cargo test test_discount

# With output
cargo test -- --nocapture

# Single-threaded
cargo test -- --test-threads=1
```

## Regression Detection

**Baseline Capture**:
```bash
# Library unit tests only
cargo test --lib > baseline_output.txt 2>&1
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
```rust
/// Calculate discounted price.
///
/// # Arguments
///
/// * `price` - Original price (non-negative)
/// * `discount_rate` - Discount percentage (0-100)
///
/// # Returns
///
/// Final price after discount, or error if discount rate invalid
///
/// # Properties
///
/// - final_price <= original_price
/// - final_price >= 0
/// - 0 <= discount_rate <= 100
///
/// # Examples
///
/// ```
/// use project_name::calculate_discount;
/// let result = calculate_discount(100.0, 10.0).unwrap();
/// assert_eq!(result, 90.0);
/// ```
pub fn calculate_discount(price: f64, discount_rate: f64) -> Result<f64, String> {
    if !(0.0..=100.0).contains(&discount_rate) {
        return Err("Discount rate must be between 0 and 100".to_string());
    }
    Ok(price * (1.0 - discount_rate / 100.0))
}
```

## Error Handling

**Rust Idiomatic Error Handling**:
```rust
// Use Result for recoverable errors
fn calculate(price: f64) -> Result<f64, String> {
    if price < 0.0 {
        return Err("Price cannot be negative".to_string());
    }
    Ok(price * 0.9)
}

// Define custom error types
#[derive(Debug)]
enum CalculationError {
    NegativePrice,
    InvalidRate,
}

impl std::fmt::Display for CalculationError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Self::NegativePrice => write!(f, "Price cannot be negative"),
            Self::InvalidRate => write!(f, "Discount rate must be 0-100"),
        }
    }
}

impl std::error::Error for CalculationError {}

// Use ? operator for propagation
fn process() -> Result<f64, CalculationError> {
    let result = calculate(100.0)?;
    Ok(result)
}
```

## Verification Criteria

**Mandatory Questions**:
1. Is there any dead code (unused functions, variables, imports)?
2. Are there any parallel implementations (duplicate/redundant implementations)?
3. Are all obsolete files cleaned up?

**Rust-Specific Questions**:
- Are all public functions and types documented with doc comments?
- Does `cargo clippy` pass without warnings?
- Is code formatted with rustfmt?
- Are all Result types properly handled (no unwrap() in production code)?
- Are lifetimes minimal and clear?
- Is unsafe code justified and documented?
- Are there any data races (check with `cargo test` and thread sanitizer)?

## Common Commands

```bash
# Format code
cargo fmt

# Lint code
cargo clippy

# Check compilation without building
cargo check

# Build
cargo build

# Build optimized
cargo build --release

# Run
cargo run

# Test
cargo test

# Test with coverage (requires cargo-tarpaulin)
cargo tarpaulin

# Generate documentation
cargo doc --open

# Update dependencies
cargo update

# Add dependency
cargo add <crate>
```

## Documentation Standards

### README.md
- Include feature descriptions
- Provide usage examples extracted from integration tests
- Use Rust code blocks with proper syntax highlighting

### CHANGELOG.md
Follow Keep a Changelog format:
- Organize by version with `[Unreleased]` section
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security

### API Documentation
Use Rust doc comments:

```rust
/// Brief one-line summary.
///
/// Detailed description explaining the type/function purpose,
/// behavior, and important constraints.
///
/// # Arguments
///
/// * `param1` - Description of param1
/// * `param2` - Description of param2
///
/// # Returns
///
/// Description of return value
///
/// # Errors
///
/// When and why this returns an error
///
/// # Examples
///
/// ```
/// let instance = ClassName::new();
/// let result = instance.method(param1, param2);
/// assert_eq!(result, expected);
/// ```
///
/// # Panics
///
/// When and why this panics (if applicable)
pub fn function_name(param1: Type1, param2: Type2) -> Result<ReturnType, ErrorType> {
}
```

**Rust doc conventions:**
- Use `///` for outer documentation
- Use `//!` for module/crate-level documentation
- Examples are compiled and tested as doc tests
- Use standard sections: Arguments, Returns, Errors, Examples, Panics, Safety

Generate documentation with: `cargo doc --open`

### Architecture Docs
Update if feature adds components. Include crate dependencies and module structure.

## Verification Tools

Tools for code quality analysis and verification:

### Dead Code Detection
```bash
# Rust compiler warns about unused code
cargo build

# Clippy detects unused code
cargo clippy

# Manual approach: Find unused functions
grep -r "fn function_name" --include="*.rs"
grep -r "function_name(" --include="*.rs"

# Find unused dependencies
cargo +nightly udeps
```

### Type System Verification
```bash
# Rust compiler enforces types
cargo check

# Type check without code generation (faster)
cargo check --all-targets

# Check specific package
cargo check -p package-name
```

### Test Coverage Analysis
```bash
# cargo-tarpaulin (Linux/macOS)
cargo tarpaulin --out Html

# cargo-llvm-cov
cargo llvm-cov --html

# cargo-llvm-cov with specific tests
cargo llvm-cov --lib
cargo llvm-cov --test integration_test
```

### Security Analysis
```bash
# cargo-audit for known vulnerabilities
cargo audit

# cargo-audit with JSON output
cargo audit --json

# Clippy with pedantic and security lints
cargo clippy -- -W clippy::all -W clippy::pedantic

# cargo-deny for dependency policies
cargo deny check
```

### Documentation Verification
```bash
# Check documentation builds
cargo doc --no-deps

# Check for missing docs (warns on missing doc comments)
cargo rustdoc -- -D missing_docs

# Check doc tests
cargo test --doc
```

### Linting and Formatting
```bash
# Format code
cargo fmt

# Check formatting without applying
cargo fmt -- --check

# Clippy (comprehensive linter)
cargo clippy

# Clippy with all warnings
cargo clippy -- -W clippy::all

# Clippy pedantic mode
cargo clippy -- -W clippy::pedantic
```

**Tool Installation**:
```bash
# Install analysis tools
cargo install cargo-tarpaulin  # Linux/macOS
cargo install cargo-llvm-cov
cargo install cargo-audit
cargo install cargo-deny
cargo install cargo-udeps --locked

# Clippy and rustfmt (usually included with rustup)
rustup component add clippy
rustup component add rustfmt
```

## Best Practices

**Ownership and Borrowing**:
- Prefer borrowing (&T) over ownership transfer
- Use &mut T only when necessary
- Clone when ownership is needed and cheap
- Use Rc/Arc for shared ownership

**Type System**:
- Use strong types (newtype pattern) for domain concepts
- Leverage the type system for correctness
- Use enums for variants (not multiple booleans)
- Use Option<T> instead of null

**Error Handling**:
- Use Result for recoverable errors
- Use panic! only for unrecoverable errors
- Define custom error types
- Implement std::error::Error trait

**Concurrency**:
- Use channels for message passing
- Use Mutex/RwLock for shared state
- Prefer async/await for I/O-bound tasks
- Test with cargo test --release for race conditions

**Memory Safety**:
- Let Rust's ownership system prevent bugs
- Use unsafe only when necessary and document why
- Validate safety invariants in unsafe blocks
- Prefer safe abstractions

**Testing**:
- Property-based tests for business rules (proptest)
- Integration tests for component interactions
- Unit tests for isolated logic
- Doc tests for examples
- Use assert_eq! for clear failure messages

**Code Organization**:
- One module per file or directory
- Use mod.rs for module roots
- Re-export public API in lib.rs
- Keep modules focused and cohesive

**Performance**:
- Don't optimize prematurely
- Use cargo bench for benchmarking
- Profile before optimizing
- Consider zero-cost abstractions
