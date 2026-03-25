---
name: javascript-typescript
description: JavaScript/TypeScript language conventions, tools, and frameworks for property-based testing development
language: JavaScript/TypeScript
property_testing_framework: fast-check
version_preference: "Node 18+, TypeScript 5+"
---

# JavaScript/TypeScript Language Skill

This skill defines JavaScript/TypeScript-specific conventions, tools, and frameworks for feature development with property-based testing.

## Package Management

**Primary Tool**: npm or yarn or pnpm
- **npm**: `package.json` for dependencies
- **yarn**: Faster alternative to npm
- **pnpm**: Disk-efficient package manager

## Project Configuration

**package.json**:
```json
{
  "name": "project-name",
  "version": "1.0.0",
  "type": "module",
  "engines": {
    "node": ">=18.0.0"
  },
  "scripts": {
    "test": "jest",
    "test:unit": "jest --testPathPattern=test/unit",
    "test:integration": "jest --testPathPattern=test/integration",
    "build": "tsc",
    "lint": "eslint ."
  },
  "devDependencies": {
    "fast-check": "^3.0.0",
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0",
    "typescript": "^5.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0"
  }
}
```

**TypeScript (tsconfig.json)**:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "test"]
}
```

## Code Style & Standards

**Naming Conventions**:
- Variables/Functions: camelCase (`calculateDiscount`)
- Classes: PascalCase (`DiscountCalculator`)
- Constants: UPPER_SNAKE_CASE (`MAX_DISCOUNT`)
- Interfaces (TS): PascalCase, no "I" prefix (`Calculator`, not `ICalculator`)
- Types (TS): PascalCase (`DiscountRate`)

**Documentation**: JSDoc
- Use JSDoc comments for all exported functions and classes
- TypeScript uses JSDoc for documentation alongside type annotations

```typescript
/**
 * Calculates the discounted price.
 *
 * @param price - The original price (must be non-negative)
 * @param discountRate - The discount percentage (0-100)
 * @returns The final price after applying the discount
 * @throws {Error} If discount rate is out of bounds
 */
export function calculateDiscount(price: number, discountRate: number): number {
  // implementation
}
```

## File Organization

**Project Structure**:
```
project/
├── package.json
├── tsconfig.json
├── src/
│   ├── domain/              # Business logic
│   │   ├── calculator.ts
│   │   └── index.ts
│   ├── infrastructure/      # External dependencies
│   └── index.ts
├── test/
│   ├── unit/                # Unit tests
│   │   └── calculator.test.ts
│   └── integration/         # Integration tests
│       └── calculator.integration.test.ts
└── README.md
```

**File Conventions**:
- Source files: `*.ts` or `*.js`
- Test files: `*.test.ts`, `*.test.js`, `*.spec.ts`, `*.spec.js`
- Integration tests: `*.integration.test.ts`

## File Exclusion Patterns

**Directories to exclude** (Node.js dependencies, build artifacts, caches):
```
node_modules/
dist/
build/
out/
lib/
coverage/
.next/
.nuxt/
.cache/
.parcel-cache/
.turbo/
.nyc_output/
.jest/
.vitest/
.vscode/
.idea/
```

**File patterns to exclude**:
```
*.js.map
*.d.ts
*.tsbuildinfo
*.lcov
*.tmp
*.log
*.bak
*.orig
*.swp
*.swo
*~
.DS_Store
.env
.env.local
.eslintcache
npm-debug.log*
yarn-debug.log*
yarn-error.log*
```

**Search patterns for verification**:
- Source files: `*.ts`, `*.tsx`, `*.js`, `*.jsx`
- Test files: `*.test.ts`, `*.test.js`, `*.spec.ts`, `*.spec.js`
- Import pattern: `^import .* from ` or `^const .* = require\(`
- Function definition: `^(export )?(async )?function \w+` or `^(export )?const \w+ = .*=>`
- Class definition: `^(export )?class \w+`
- Interface/Type: `^(export )?(interface|type) \w+`

## Property-Based Testing

**Framework**: fast-check

**Installation**:
```bash
npm install --save-dev fast-check jest @types/jest
```

**Usage Patterns**:

1. **Basic property test**:
```typescript
import fc from 'fast-check';

describe('DiscountCalculator', () => {
  it('should never produce negative prices', () => {
    fc.assert(
      fc.property(fc.double({ min: 0 }), (price) => {
        const result = calculateDiscount(price, 10);
        return result >= 0;
      })
    );
  });
});
```

2. **Custom arbitraries**:
```typescript
const discountRateArbitrary = fc.double({
  min: 0,
  max: 100,
  noNaN: true
});

const priceArbitrary = fc.double({
  min: 0,
  noNaN: true,
  noDefaultInfinity: true
});

fc.assert(
  fc.property(
    priceArbitrary,
    discountRateArbitrary,
    (price, rate) => {
      const result = calculateDiscount(price, rate);
      return result <= price && result >= 0;
    }
  )
);
```

3. **Stateful testing**:
```typescript
import fc from 'fast-check';

class ShoppingCartModel {
  items: string[] = [];

  addItem(item: string) {
    this.items.push(item);
  }

  getTotal(): number {
    return this.items.length;
  }
}

const commands = [
  fc.constant({ type: 'add', item: 'test' }),
  fc.constant({ type: 'clear' })
];

fc.assert(
  fc.property(fc.array(fc.oneof(...commands)), (commands) => {
    const cart = new ShoppingCartModel();
    // execute commands and check invariants
    return cart.getTotal() >= 0;
  })
);
```

**Documentation Retrieval**:
- "Find fast-check API for array generators"
- "Get fast-check examples for stateful testing"
- "Retrieve fast-check documentation for custom arbitraries"

## Test Execution

**Jest**:
```bash
# All tests
npm test

# Unit tests only
npm run test:unit
# or
jest --testPathPattern=test/unit

# Integration tests only
npm run test:integration
# or
jest --testPathPattern=test/integration

# Watch mode
npm test -- --watch
```

## Regression Detection

**Baseline Capture**:
```bash
# Unit tests only
jest --testPathPattern=test/unit > baseline_output.txt 2>&1
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
```typescript
/**
 * Calculate discounted price.
 *
 * Properties:
 * - finalPrice <= originalPrice
 * - finalPrice >= 0
 * - discountRate bounds: 0 <= discountRate <= 100
 *
 * @param price - Original price (non-negative)
 * @param discountRate - Discount percentage (0-100)
 * @returns Final price after discount
 */
export function calculateDiscount(
  price: number,
  discountRate: number
): number {
  if (discountRate < 0 || discountRate > 100) {
    throw new Error('Discount rate must be between 0 and 100');
  }
  // implementation
}
```

## Type System (TypeScript)

**Strict Mode**: Enable all strict type checks
```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitThis": true
  }
}
```

**Type Annotations**:
```typescript
// Explicit types for clarity
const price: number = 100;
const items: string[] = [];
const config: { rate: number; enabled: boolean } = { rate: 10, enabled: true };

// Function signatures
function calculate(price: number, rate: number): number {
  return price * (1 - rate / 100);
}

// Interfaces for contracts
interface Calculator {
  calculate(price: number, rate: number): number;
}

// Type aliases for domain concepts
type DiscountRate = number; // Consider branded types for stronger typing
```

## Verification Criteria

**Mandatory Questions**:
1. Is there any dead code (unused functions, variables, imports)?
2. Are there any parallel implementations (duplicate/redundant implementations)?
3. Are all obsolete files cleaned up?

**TypeScript-Specific Questions**:
- Are all exported functions and classes documented with JSDoc?
- Is strict mode enabled in TypeScript configuration?
- Are all types properly annotated (no implicit any)?
- Are interfaces used for contracts and data structures?

**JavaScript-Specific Questions**:
- Are all exported functions documented with JSDoc?
- Are parameter types documented in JSDoc?
- Is error handling consistent and appropriate?

## Common Commands

**npm**:
```bash
# Install dependencies
npm install

# Add dependency
npm install <package>

# Add dev dependency
npm install --save-dev <package>

# Run tests
npm test

# Build TypeScript
npm run build
```

**yarn**:
```bash
# Install dependencies
yarn install

# Add dependency
yarn add <package>

# Add dev dependency
yarn add --dev <package>

# Run tests
yarn test
```

## Documentation Standards

### README.md
- Include feature descriptions
- Provide usage examples extracted from integration tests
- Use JavaScript/TypeScript code blocks with proper syntax highlighting

### CHANGELOG.md
Follow Keep a Changelog format:
- Organize by version with `[Unreleased]` section
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security

### API Documentation
Use JSDoc (JavaScript) or TSDoc (TypeScript) comments:

**JSDoc format:**
```javascript
/**
 * Brief one-line summary.
 *
 * Detailed description explaining the function/class purpose,
 * behavior, and important constraints.
 *
 * @param {Type1} param1 - Description of param1
 * @param {Type2} param2 - Description of param2
 * @returns {ReturnType} Description of return value
 * @throws {Error} When and why this is raised
 *
 * @example
 * const result = functionName(value1, value2);
 * // result is expected_value
 */
```

**TypeScript with TSDoc:**
```typescript
/**
 * Brief one-line summary.
 *
 * Detailed description explaining the function/class purpose,
 * behavior, and important constraints.
 *
 * @param param1 - Description of param1
 * @param param2 - Description of param2
 * @returns Description of return value
 * @throws When and why this is raised
 *
 * @example
 * ```ts
 * const result = functionName(value1, value2);
 * // result is expected_value
 * ```
 */
function functionName(param1: Type1, param2: Type2): ReturnType {
}
```

Generate documentation with: `npx typedoc` or similar tools

### Architecture Docs
Update if feature adds components. Include module dependencies and component interactions.

## Verification Tools

Tools for code quality analysis and verification:

### Dead Code Detection
```bash
# TypeScript: Find unused exports
npx ts-prune

# ESLint with no-unused-vars
npx eslint . --ext .ts,.tsx,.js,.jsx

# Manual approach: Find unused functions
grep -r "function functionName\|const functionName" --include="*.ts" --include="*.js"
grep -r "functionName(" --include="*.ts" --include="*.js"
```

### Type System Verification (TypeScript)
```bash
# Strict type checking
npx tsc --noEmit --strict

# Check specific file
npx tsc --noEmit file.ts

# Report unused locals and parameters
npx tsc --noEmit --noUnusedLocals --noUnusedParameters
```

### Test Coverage Analysis
```bash
# Jest with coverage
npm test -- --coverage

# Generate HTML report
npm test -- --coverage --coverageReporters=html

# Coverage for specific file
npm test -- --coverage --collectCoverageFrom='src/feature.ts'

# NYC (Istanbul) for general coverage
npx nyc npm test
```

### Security Analysis
```bash
# npm audit for dependencies
npm audit

# npm audit fix (auto-fix vulnerabilities)
npm audit fix

# ESLint security plugins
npx eslint . --ext .ts,.js

# Snyk for comprehensive security
npx snyk test
```

### Documentation Verification
```bash
# TSDoc/JSDoc validation with ESLint
npx eslint . --ext .ts,.js --rule 'jsdoc/require-jsdoc: error'

# Generate docs to find missing documentation
npx typedoc --out docs src/
```

### Linting and Formatting
```bash
# ESLint
npx eslint . --ext .ts,.tsx,.js,.jsx

# Prettier
npx prettier --check .

# Fix issues
npx eslint . --fix
npx prettier --write .
```

**Tool Installation**:
```bash
npm install --save-dev \
  typescript \
  eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin \
  prettier eslint-config-prettier \
  jest @types/jest ts-jest \
  ts-prune \
  typedoc
```

## Best Practices

**Separation of Concerns**:
- Domain logic in `src/domain/`
- Infrastructure in `src/infrastructure/`
- Clear module boundaries

**Immutability**:
- Prefer `const` over `let`
- Use spread operators for copying: `{ ...obj }`, `[...arr]`
- Consider using `Object.freeze()` for truly immutable objects

**Error Handling**:
- Use Error classes for exceptions
- Document thrown errors in JSDoc
- Consider Result/Either types for functional error handling

**Async Operations**:
- Use `async/await` for clarity
- Handle promise rejections
- Consider using libraries like p-limit for concurrency control

**Testing**:
- Property-based tests for business rules (fast-check)
- Integration tests for component interactions
- Unit tests for isolated logic
- Mock external dependencies

**TypeScript-Specific**:
- Enable strict mode
- Avoid `any` type (use `unknown` if needed)
- Use union types and type guards
- Consider branded types for domain primitives
