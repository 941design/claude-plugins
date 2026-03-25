---
name: kotlin
description: Kotlin language conventions, tools, and frameworks for property-based testing development
language: Kotlin
property_testing_framework: kotest-property or kotlintest
version_preference: "1.9+"
---

# Kotlin Language Skill

This skill defines Kotlin-specific conventions, tools, and frameworks for feature development with property-based testing.

## Package Management

**Primary Tools**: Gradle or Maven
- **Gradle**: `build.gradle.kts` (Kotlin DSL) or `build.gradle` (Groovy)
- **Maven**: `pom.xml`

## Project Configuration

**Gradle (build.gradle.kts)**:
```kotlin
plugins {
    kotlin("jvm") version "1.9.22"
    application
}

group = "com.company"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation(kotlin("stdlib"))

    testImplementation("io.kotest:kotest-runner-junit5:5.8.0")
    testImplementation("io.kotest:kotest-assertions-core:5.8.0")
    testImplementation("io.kotest:kotest-property:5.8.0")
}

tasks.test {
    useJUnitPlatform()
}

kotlin {
    jvmToolchain(17)
}
```

## Code Style & Standards

**Official Style**: Kotlin Coding Conventions
- Follow official Kotlin style guide
- Use ktlint or detekt for linting

**Naming Conventions**:
- Packages: lowercase (`com.company.domain`)
- Classes/Objects: PascalCase (`DiscountCalculator`)
- Functions/Properties: camelCase (`calculateDiscount`)
- Constants: UPPER_SNAKE_CASE (`MAX_DISCOUNT`)
- Backing properties: underscore prefix (`_discount`)

**Documentation**: KDoc
```kotlin
/**
 * Calculates the discounted price.
 *
 * @param price The original price (must be non-negative)
 * @param discountRate The discount percentage (0-100)
 * @return The final price after applying the discount
 * @throws IllegalArgumentException if discount rate is out of bounds
 *
 * Properties:
 * - finalPrice <= originalPrice
 * - finalPrice >= 0
 * - 0 <= discountRate <= 100
 */
fun calculateDiscount(price: BigDecimal, discountRate: BigDecimal): BigDecimal {
    require(discountRate in BigDecimal.ZERO..BigDecimal(100)) {
        "Discount rate must be between 0 and 100"
    }
    // implementation
}
```

## File Organization

**Project Structure**:
```
project/
├── build.gradle.kts
├── settings.gradle.kts
├── src/
│   ├── main/
│   │   └── kotlin/
│   │       └── com/company/project/
│   │           ├── domain/         # Business logic
│   │           │   └── Calculator.kt
│   │           └── infrastructure/ # External dependencies
│   └── test/
│       └── kotlin/
│           └── com/company/project/
│               ├── unit/           # Unit tests
│               │   └── CalculatorTest.kt
│               └── integration/    # Integration tests
│                   └── CalculatorIntegrationTest.kt
└── README.md
```

**File Conventions**:
- Multiple classes per file allowed (unlike Java)
- Top-level functions allowed
- File name typically matches primary class: `Calculator.kt`

## File Exclusion Patterns

**Directories to exclude** (Gradle build artifacts, IDE files):
```
build/
.gradle/
.idea/
.vscode/
bin/
out/
```

**File patterns to exclude**:
```
*.class
*.jar
*.war
*.iml
*.ipr
*.iws
.classpath
.project
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
- Source files: `*.kt`, `*.kts`
- Test files: files in `src/test/` or containing `@Test`, `checkAll`, `forAll`
- Import pattern: `^import .+`
- Class definition: `^(open |abstract |sealed )?(class|interface|object|data class|enum class) \w+`
- Function definition: `^(private |internal |protected |public )?(suspend |inline |infix )?fun (<.+> )?\w+\(`
- Property definition: `^(private |internal |protected |public )?(val|var) \w+`

## Property-Based Testing

**Framework**: Kotest Property Testing

**Installation** (Gradle):
```kotlin
dependencies {
    testImplementation("io.kotest:kotest-runner-junit5:5.8.0")
    testImplementation("io.kotest:kotest-property:5.8.0")
}
```

**Usage Patterns**:

1. **Basic property test**:
```kotlin
import io.kotest.core.spec.style.StringSpec
import io.kotest.property.checkAll
import io.kotest.property.Arb
import io.kotest.property.arbitrary.double

class CalculatorTest : StringSpec({
    "discounted price is never negative" {
        checkAll<Double> { price ->
            val result = calculateDiscount(price.toBigDecimal(), BigDecimal(10))
            result >= BigDecimal.ZERO
        }
    }
})
```

2. **Custom arbitraries**:
```kotlin
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bigDecimal
import io.kotest.property.arbitrary.filter

fun discountRateArb(): Arb<BigDecimal> =
    Arb.bigDecimal()
        .filter { it >= BigDecimal.ZERO && it <= BigDecimal(100) }

fun priceArb(): Arb<BigDecimal> =
    Arb.bigDecimal()
        .filter { it >= BigDecimal.ZERO && it <= BigDecimal(1000000) }

class CalculatorTest : StringSpec({
    "discount stays within bounds" {
        checkAll(priceArb(), discountRateArb()) { price, rate ->
            val result = calculateDiscount(price, rate)
            result <= price && result >= BigDecimal.ZERO
        }
    }
})
```

3. **Different test styles** (Kotest supports multiple):
```kotlin
// FunSpec style
class CalculatorFunTest : FunSpec({
    test("discount should be within bounds") {
        checkAll(priceArb(), discountRateArb()) { price, rate ->
            val result = calculateDiscount(price, rate)
            result <= price
        }
    }
})

// BehaviorSpec style (BDD)
class CalculatorBehaviorTest : BehaviorSpec({
    given("a calculator") {
        `when`("calculating discount") {
            then("result should be non-negative") {
                checkAll<Double> { price ->
                    calculateDiscount(price.toBigDecimal(), BigDecimal(10)) >= BigDecimal.ZERO
                }
            }
        }
    }
})
```

**Documentation Retrieval**:
- "Get Kotest property testing examples"
- "Retrieve Kotest documentation for custom generators"
- "Find Kotest API for arbitrary generation"

## Test Execution

**Gradle**:
```bash
# All tests
./gradlew test

# Unit tests only
./gradlew test --tests "*Test"

# Integration tests only
./gradlew test --tests "*IntegrationTest"

# With reports
./gradlew test --info

# Continuous
./gradlew test --continuous
```

## Regression Detection

**Baseline Capture**:
```bash
# Unit tests only
./gradlew test --tests "*Test" > baseline_output.txt 2>&1
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
```kotlin
/**
 * Calculate discounted price.
 *
 * @param price Original price (non-negative)
 * @param discountRate Discount percentage (0-100)
 * @return Final price after discount
 * @throws IllegalArgumentException if discount rate is out of bounds
 *
 * Properties:
 * - finalPrice <= originalPrice
 * - finalPrice >= 0
 * - 0 <= discountRate <= 100
 */
fun calculateDiscount(price: BigDecimal, discountRate: BigDecimal): BigDecimal {
    require(discountRate in BigDecimal.ZERO..BigDecimal(100)) {
        "Discount rate must be between 0 and 100"
    }
    return price * (BigDecimal.ONE - discountRate / BigDecimal(100))
}
```

## Kotlin Language Features

**Null Safety**:
```kotlin
// Non-nullable by default
var name: String = "Calculator"

// Explicitly nullable
var description: String? = null

// Safe call
val length = description?.length

// Elvis operator
val len = description?.length ?: 0

// Non-null assertion (use sparingly)
val l = description!!.length
```

**Data Classes**:
```kotlin
data class Discount(
    val rate: BigDecimal,
    val description: String
) {
    init {
        require(rate >= BigDecimal.ZERO) {
            "Rate must be non-negative"
        }
    }
}
```

**Extension Functions**:
```kotlin
fun BigDecimal.isPercentage(): Boolean =
    this >= BigDecimal.ZERO && this <= BigDecimal(100)

fun BigDecimal.applyDiscount(rate: BigDecimal): BigDecimal =
    this * (BigDecimal.ONE - rate / BigDecimal(100))
```

**Sealed Classes** (for ADTs):
```kotlin
sealed class CalculationResult {
    data class Success(val value: BigDecimal) : CalculationResult()
    data class Error(val message: String) : CalculationResult()
}
```

## Verification Criteria

**Mandatory Questions**:
1. Is there any dead code (unused functions, classes, properties)?
2. Are there any parallel implementations (duplicate/redundant implementations)?
3. Are all obsolete files cleaned up?

**Kotlin-Specific Questions**:
- Are all public functions and classes documented with KDoc?
- Is null safety properly utilized (nullable types vs non-nullable)?
- Are data classes used appropriately for value objects?
- Are extension functions used where appropriate?
- Is immutability preferred (val over var)?
- Are sealed classes used for restricted hierarchies?

## Common Commands

**Gradle**:
```bash
# Build
./gradlew build

# Clean
./gradlew clean

# Run
./gradlew run

# Test
./gradlew test

# Format code (with ktlint plugin)
./gradlew ktlintFormat

# Lint (with detekt plugin)
./gradlew detekt

# Generate docs
./gradlew dokkaHtml
```

## Documentation Standards

### README.md
- Include feature descriptions
- Provide usage examples extracted from integration tests
- Use Kotlin code blocks with proper syntax highlighting

### CHANGELOG.md
Follow Keep a Changelog format:
- Organize by version with `[Unreleased]` section
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security

### API Documentation
Use KDoc comments:

```kotlin
/**
 * Brief one-line summary.
 *
 * Detailed description explaining the class/function purpose,
 * behavior, and important constraints.
 *
 * @param param1 Description of param1
 * @param param2 Description of param2
 * @return Description of return value
 * @throws ExceptionType When and why this is thrown
 *
 * @sample samples.SampleClass.sampleMethod
 *
 * @see RelatedClass
 * @see relatedFunction
 */
fun functionName(param1: Type1, param2: Type2): ReturnType {
}

/**
 * Brief one-line summary.
 *
 * Detailed description explaining the class purpose,
 * behavior, and important constraints.
 *
 * @property propertyName Description of property
 * @constructor Creates an instance with specified parameters
 */
class ClassName(val propertyName: Type) {
}
```

**KDoc conventions:**
- Similar to Javadoc but Kotlin-specific
- Use `@param`, `@return`, `@throws`, `@property`, `@constructor`
- Use `@sample` to reference executable examples
- Markdown formatting supported

Generate documentation with: `./gradlew dokkaHtml`

### Architecture Docs
Update if feature adds components. Include module dependencies and component interactions.

## Verification Tools

Tools for code quality analysis and verification:

### Dead Code Detection
```bash
# Kotlin compiler warnings
./gradlew build

# detekt for unused code
./gradlew detekt

# Manual approach: Find unused functions
grep -r "fun functionName" --include="*.kt"
grep -r "functionName(" --include="*.kt"

# IntelliJ IDEA: Analyze > Run Inspection by Name > Unused symbol
```

### Type System Verification
```bash
# Kotlin compiler enforces types
./gradlew compileKotlin

# Compile with all warnings as errors
./gradlew compileKotlin -Pwarnings-as-errors=true
```

### Test Coverage Analysis
```bash
# Gradle with JaCoCo
./gradlew test jacocoTestReport

# View report at: build/reports/jacoco/test/html/index.html

# Coverage with Kover (Kotlin-specific)
./gradlew koverHtmlReport

# View report at: build/reports/kover/html/index.html
```

### Security Analysis
```bash
# OWASP Dependency Check
./gradlew dependencyCheckAnalyze

# detekt with security rules
./gradlew detekt

# Gradle dependency vulnerability scanning
./gradlew buildHealth
```

### Documentation Verification
```bash
# Generate KDoc documentation
./gradlew dokkaHtml

# detekt checks for missing documentation
./gradlew detekt

# Manual: Check for missing KDoc on public APIs
grep -r "^\\s*public\\s\\+fun" --include="*.kt"
```

### Linting and Formatting
```bash
# ktlint check
./gradlew ktlintCheck

# ktlint format
./gradlew ktlintFormat

# detekt (comprehensive linter)
./gradlew detekt

# detekt with auto-fix
./gradlew detekt --auto-correct
```

**Tool Configuration (build.gradle.kts)**:
```kotlin
plugins {
    kotlin("jvm") version "1.9.22"
    id("org.jetbrains.kotlinx.kover") version "0.7.5"
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
    id("org.jlleitschuh.gradle.ktlint") version "12.0.3"
    id("org.jetbrains.dokka") version "1.9.10"
}

detekt {
    config.setFrom(files("$projectDir/config/detekt.yml"))
    buildUponDefaultConfig = true
}

kover {
    reports {
        total {
            html {
                onCheck = true
            }
        }
    }
}
```

## Best Practices

**Separation of Concerns**:
- Domain logic in domain package
- Infrastructure in infrastructure package
- Use clean architecture principles

**Immutability**:
- Prefer `val` over `var`
- Use immutable collections
- Use data classes with `val` properties
- Consider using `copy()` for modifications

**Functional Programming**:
- Use higher-order functions (map, filter, fold)
- Use sequences for lazy evaluation
- Avoid mutable state
- Use lambda expressions

**Null Safety**:
- Design APIs to avoid nulls where possible
- Use nullable types explicitly when needed
- Prefer safe calls and Elvis operator over !!
- Use `let`, `run`, `apply` for null handling

**Error Handling**:
- Use `require()` and `check()` for preconditions
- Throw exceptions for exceptional cases
- Use Result type for functional error handling
- Use sealed classes for domain errors

**Coroutines** (for async):
```kotlin
suspend fun calculateAsync(price: BigDecimal): BigDecimal {
    // async computation
}

// Structured concurrency
coroutineScope {
    val result1 = async { calculate1() }
    val result2 = async { calculate2() }
    result1.await() + result2.await()
}
```

**Testing**:
- Property-based tests for business rules (Kotest)
- Integration tests for component interactions
- Unit tests for isolated logic
- Use different test styles based on context
- Use data-driven tests with Kotest

**Code Organization**:
- Multiple related classes per file allowed
- Top-level functions for utilities
- Use objects for singletons
- Use companion objects for factory methods

**Type System**:
- Use type aliases for clarity: `typealias DiscountRate = BigDecimal`
- Use inline classes for zero-cost wrappers (Kotlin 1.3+)
- Use sealed interfaces for exhaustive when expressions
- Leverage smart casts

**Performance**:
- Use inline functions for higher-order functions
- Use sequences for large collections
- Consider using primitive arrays for performance-critical code
- Profile before optimizing
