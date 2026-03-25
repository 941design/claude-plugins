---
name: java
description: Java language conventions, tools, and frameworks for property-based testing development
language: Java
property_testing_framework: jqwik
version_preference: "11+"
---

# Java Language Skill

This skill defines Java-specific conventions, tools, and frameworks for feature development with property-based testing.

## Package Management

**Primary Tools**: Maven or Gradle
- **Maven**: `pom.xml` for dependencies
- **Gradle**: `build.gradle` or `build.gradle.kts` (Kotlin DSL)

## Project Configuration

**Maven (pom.xml)**:
```xml
<project>
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <jqwik.version>1.7.4</jqwik.version>
        <junit.version>5.10.0</junit.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>net.jqwik</groupId>
            <artifactId>jqwik</artifactId>
            <version>${jqwik.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
```

**Gradle (build.gradle.kts)**:
```kotlin
plugins {
    java
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

dependencies {
    testImplementation("net.jqwik:jqwik:1.7.4")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
}
```

## Code Style & Standards

**Naming Conventions**:
- Classes: PascalCase (`DiscountCalculator`)
- Methods: camelCase (`calculateDiscount`)
- Constants: UPPER_SNAKE_CASE (`MAX_DISCOUNT`)
- Packages: lowercase (`com.company.domain`)

**Documentation**: Javadoc
- Use Javadoc comments for all public classes and methods
- Document parameters, returns, and exceptions

```java
/**
 * Calculates the discounted price.
 *
 * @param price The original price (must be non-negative)
 * @param discountRate The discount percentage (0-100)
 * @return The final price after applying the discount
 * @throws IllegalArgumentException if discount rate is out of bounds
 */
public BigDecimal calculateDiscount(BigDecimal price, BigDecimal discountRate) {
    // implementation
}
```

## File Organization

**Project Structure**:
```
project/
├── pom.xml (or build.gradle)
├── src/
│   ├── main/
│   │   └── java/
│   │       └── com/company/project/
│   │           ├── domain/         # Business logic
│   │           └── infrastructure/ # External dependencies
│   └── test/
│       └── java/
│           └── com/company/project/
│               ├── unit/           # Unit tests
│               └── integration/     # Integration tests
└── README.md
```

**File Conventions**:
- One public class per file
- File name matches class name: `DiscountCalculator.java`
- Package structure mirrors directory structure

## File Exclusion Patterns

**Directories to exclude** (Maven/Gradle build artifacts, IDE files):
```
target/
build/
.gradle/
.idea/
.vscode/
.settings/
bin/
out/
```

**File patterns to exclude**:
```
*.class
*.jar
*.war
*.ear
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
- Source files: `*.java`
- Test files: files in `src/test/` or containing `@Test`, `@Property`
- Import pattern: `^import .+;`
- Class definition: `^(public |private |protected )?(abstract |final )?(class|interface|enum) \w+`
- Method definition: `^(public |private |protected )?(static |final )*\w+(<.+>)? \w+\(`
- Annotation: `^@\w+`

## Property-Based Testing

**Framework**: jqwik

**Installation** (Maven):
```xml
<dependency>
    <groupId>net.jqwik</groupId>
    <artifactId>jqwik</artifactId>
    <version>1.7.4</version>
    <scope>test</scope>
</dependency>
```

**Usage Patterns**:

1. **Basic property test**:
```java
import net.jqwik.api.*;

class DiscountCalculatorTest {
    @Property
    boolean discountedPriceIsNeverNegative(@ForAll BigDecimal price) {
        BigDecimal result = calculator.calculateDiscount(price);
        return result.compareTo(BigDecimal.ZERO) >= 0;
    }
}
```

2. **Custom arbitraries**:
```java
@Property
void discountRateBounds(@ForAll("discountRates") BigDecimal rate) {
    assertTrue(rate.compareTo(BigDecimal.ZERO) >= 0);
    assertTrue(rate.compareTo(new BigDecimal("100")) <= 0);
}

@Provide
Arbitrary<BigDecimal> discountRates() {
    return Arbitraries.bigDecimals()
        .between(BigDecimal.ZERO, new BigDecimal("100"))
        .ofScale(2);
}
```

3. **Stateful testing**:
```java
class ShoppingCartStateMachine {
    private ShoppingCart cart;

    @Action
    void addItem(@ForAll String item) {
        cart.add(item);
    }

    @Invariant
    void totalIsNonNegative() {
        assertThat(cart.getTotal()).isGreaterThanOrEqualTo(BigDecimal.ZERO);
    }
}
```

**Documentation Retrieval**:
- "Get jqwik examples for stateful testing"
- "Retrieve jqwik documentation for custom arbitraries"
- "Find jqwik API for domain generation"

## Test Execution

**Maven**:
```bash
# All tests
mvn test

# Unit tests only
mvn test -Dtest="**/*Test"

# Integration tests only
mvn test -Dtest="**/integration/**/*Test"
```

**Gradle**:
```bash
# All tests
./gradlew test

# Unit tests only
./gradlew test --tests "*Test"

# Integration tests only
./gradlew test --tests "*Integration*"
```

## Regression Detection

**Baseline Capture**:
```bash
# Maven - unit tests only
mvn test -Dtest="**/*Test" > baseline_output.txt 2>&1

# Gradle - unit tests only
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
```java
/**
 * Calculate discounted price.
 *
 * Properties:
 * - final_price <= original_price
 * - final_price >= 0
 * - discount_rate bounds: 0 <= discount_rate <= 100
 *
 * @param price Original price (non-negative)
 * @param discountRate Discount percentage (0-100)
 * @return Final price after discount
 */
public BigDecimal calculateDiscount(BigDecimal price, BigDecimal discountRate) {
    // implementation
}
```

## Verification Criteria

**Mandatory Questions**:
1. Is there any dead code (unused methods, classes)?
2. Are there any parallel implementations (duplicate/redundant implementations)?
3. Are all obsolete files cleaned up?

**Java-Specific Questions**:
- Are all public classes and methods documented with Javadoc?
- Do class names follow conventions (one public class per file)?
- Are exceptions properly declared and documented?
- Is package structure appropriate for the domain?

## Common Commands

**Maven**:
```bash
# Compile
mvn compile

# Run tests
mvn test

# Package
mvn package

# Install dependency
# (Add to pom.xml dependencies section)
```

**Gradle**:
```bash
# Build
./gradlew build

# Run tests
./gradlew test

# Clean
./gradlew clean

# Add dependency
# (Add to build.gradle dependencies block)
```

## Documentation Standards

### README.md
- Include feature descriptions
- Provide usage examples extracted from integration tests
- Use Java code blocks with proper syntax highlighting

### CHANGELOG.md
Follow Keep a Changelog format:
- Organize by version with `[Unreleased]` section
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security

### API Documentation
Use Javadoc comments:

```java
/**
 * Brief one-line summary.
 *
 * <p>Detailed description explaining the class purpose,
 * behavior, and important constraints.
 *
 * <p>Example usage:
 * <pre>{@code
 * ClassName instance = new ClassName();
 * ReturnType result = instance.method();
 * }</pre>
 *
 * @author Author Name
 * @version 1.0
 * @since 1.0
 */
public class ClassName {
}

/**
 * Brief one-line summary.
 *
 * @param param1 description of param1
 * @param param2 description of param2
 * @return description of return value
 * @throws ExceptionType when and why this is raised
 * @see RelatedClass#relatedMethod
 */
public ReturnType methodName(Type1 param1, Type2 param2) {
}
```

Generate documentation with: `mvn javadoc:javadoc` or `./gradlew javadoc`

### Architecture Docs
Update if feature adds components. Include class diagrams and component interactions.

## Verification Tools

Tools for code quality analysis and verification:

### Dead Code Detection
```bash
# Maven: Use plugins in pom.xml
mvn pmd:check  # PMD can detect unused code

# Manual approach: Find unused methods
grep -r "public.*methodName" --include="*.java"
grep -r "methodName(" --include="*.java"

# Use IDE analysis (IntelliJ, Eclipse)
# Run "Analyze > Run Inspection by Name > Unused declaration"
```

### Type System Verification
```bash
# Java compiler provides type checking
mvn compile

# For nullability analysis (if using annotations)
mvn compile -Xlint:all
```

### Test Coverage Analysis
```bash
# Maven with JaCoCo
mvn test jacoco:report

# View report at: target/site/jacoco/index.html

# Gradle with JaCoCo
./gradlew test jacocoTestReport

# View report at: build/reports/jacoco/test/html/index.html
```

### Security Analysis
```bash
# SpotBugs (successor to FindBugs)
mvn spotbugs:check

# OWASP Dependency Check
mvn dependency-check:check

# SonarQube analysis
mvn sonar:sonar
```

### Documentation Verification
```bash
# Check for missing Javadoc
mvn javadoc:javadoc

# Fail build on missing Javadoc
mvn javadoc:javadoc -X
```

### Linting and Style
```bash
# Checkstyle
mvn checkstyle:check

# PMD
mvn pmd:check

# SpotBugs
mvn spotbugs:check
```

**Tool Configuration (Maven pom.xml)**:
```xml
<build>
  <plugins>
    <plugin>
      <groupId>org.jacoco</groupId>
      <artifactId>jacoco-maven-plugin</artifactId>
      <version>0.8.11</version>
    </plugin>
    <plugin>
      <groupId>com.github.spotbugs</groupId>
      <artifactId>spotbugs-maven-plugin</artifactId>
      <version>4.8.0</version>
    </plugin>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId>
      <artifactId>maven-checkstyle-plugin</artifactId>
      <version>3.3.1</version>
    </plugin>
  </plugins>
</build>
```

## Best Practices

**Separation of Concerns**:
- Domain logic in `com.company.domain`
- Infrastructure in `com.company.infrastructure`

**Immutability**:
- Prefer immutable objects
- Use `final` for fields that don't change
- Consider using records (Java 14+)

**Error Handling**:
- Use checked exceptions for recoverable errors
- Use unchecked exceptions for programming errors
- Document all exceptions in Javadoc

**Type Safety**:
- Use generics for type safety
- Avoid raw types
- Use `Optional<T>` instead of null where appropriate

**Testing**:
- Property-based tests for business rules (jqwik)
- Integration tests for component interactions
- Unit tests for isolated logic
