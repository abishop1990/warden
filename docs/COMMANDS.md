# Warden - Discovering and Executing Validation Commands

**IMPORTANT**: This is NOT conceptual review. You ACTUALLY RUN commands and check exit codes.

## How to Find Commands (Priority Order)

### 1. Read Repository's AI Instructions (HIGHEST PRIORITY)

**ALWAYS check these files FIRST** for build/test/validation commands:

```bash
# Platform-specific AI instruction files (check all that exist):
- CLAUDE.md                              # Claude Code instructions
- AGENTS.md                               # Unified AI instructions
- .cursorrules                            # Cursor instructions
- .cursor/rules/*.md                      # Cursor rule files
- .github/copilot-instructions.md         # GitHub Copilot instructions
- README.md                               # Project documentation

# Look for sections like:
- "Build and Test"
- "Development"
- "Running Tests"
- "CI/CD Commands"
- "Pre-commit Checks"
- "Validation"
- "Common Commands"
```

**Example - What to look for**:

```markdown
## Build and Test (from CLAUDE.md)

- Build: `make build`
- Test: `make test`
- Lint: `make lint`
- Format: `make fmt`
```

**Use THOSE commands**, not generic defaults!

### 2. Check CI Configuration Files (HIGH PRIORITY)

If AI instruction files don't specify commands, check CI configs:

```bash
# GitHub Actions
.github/workflows/*.yml

# Look for:
- run: go build ./...          ← Build command
- run: golangci-lint run       ← Lint command
- run: go test ./...           ← Test command

# GitLab CI
.gitlab-ci.yml

# CircleCI
.circleci/config.yml

# Other
Makefile                       # Look for build/test/lint targets
package.json                   # Look for scripts
justfile                       # Look for recipes
```

### 3. Check Project-Specific Scripts (MEDIUM PRIORITY)

```bash
# Scripts directory
scripts/build.sh
scripts/test.sh
scripts/lint.sh

# Package managers
package.json → "scripts": { "build": "...", "test": "..." }
Makefile → build: / test: / lint: targets
```

### 4. Language Defaults (FALLBACK ONLY)

**ONLY use these if nothing found in steps 1-3**

Use standard language conventions as last resort.

---

## Command Discovery Example

### Real-World Example

```bash
# 1. Check CLAUDE.md in the repo
cat CLAUDE.md

# Found this section:
# ## Development Commands
# - Build: `go build -tags unit,integration ./...`
# - Generate: `go generate ./...`
# - Lint: `golangci-lint run --config .golangci.yml`
# - Format: `gofmt -s -w .`
# - Test: `go test -tags unit,integration -v ./...`

# 2. Use THOSE commands (not generic defaults)
BUILD_CMD="go build -tags unit,integration ./..."
GENERATE_CMD="go generate ./..."
LINT_CMD="golangci-lint run --config .golangci.yml"
FORMAT_CMD="gofmt -s -w ."
TEST_CMD="go test -tags unit,integration -v ./..."

# 3. Execute them
$BUILD_CMD
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ BUILD FAILED"
  # Fix and retry
fi
```

---

## Validation Commands by Language (DEFAULTS ONLY)

### Go Projects

**Required commands to run in order**:

```bash
# 1. BUILD - Ensure code compiles
go build -tags unit,integration ./...
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ BUILD FAILED"
  # Fix build errors, then rerun
fi

# 2. GENERATE - Check for uncommitted generated code
go generate ./...
git diff --exit-code
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ GENERATED CODE NOT COMMITTED"
  # Commit generated files
fi

# 3. LINT - Code quality checks
golangci-lint run
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ LINT FAILED"
  # Fix lint errors, then rerun
fi

# 4. FORMAT - Style fixes (auto-fix)
gofmt -s -w .
# Commit formatting changes

# 5. TEST - Functionality validation
go test -tags unit,integration ./...
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ TESTS FAILED"
  # Fix test failures, then rerun
fi
```

**Summary for Go**:
1. `go build -tags unit,integration ./...`
2. `go generate ./... && git diff --exit-code`
3. `golangci-lint run`
4. `gofmt -s -w .`
5. `go test -tags unit,integration ./...`

### Python Projects

**Required commands to run in order**:

```bash
# 1. BUILD - Check syntax/compilation
python -m compileall .
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ BUILD FAILED"
fi

# 2. LINT - Code quality
ruff check .
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ LINT FAILED"
fi

# 3. FORMAT - Style fixes (auto-fix)
black .

# 4. TYPE CHECK - Type validation
mypy .
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ TYPE CHECK FAILED"
fi

# 5. TEST - Functionality
pytest -v
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ TESTS FAILED"
fi
```

### JavaScript/TypeScript Projects

**Required commands to run in order**:

```bash
# 1. BUILD - Compilation
npm run build
# OR
tsc
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ BUILD FAILED"
fi

# 2. LINT - Code quality
npm run lint
# OR
eslint .
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ LINT FAILED"
fi

# 3. FORMAT - Style fixes (auto-fix)
npm run format
# OR
prettier --write .

# 4. TYPE CHECK - Type validation (TypeScript)
tsc --noEmit
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ TYPE CHECK FAILED"
fi

# 5. TEST - Functionality
npm test
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ TESTS FAILED"
fi
```

### Rust Projects

**Required commands to run in order**:

```bash
# 1. BUILD - Compilation
cargo build
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ BUILD FAILED"
fi

# 2. LINT - Code quality
cargo clippy -- -D warnings
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ LINT FAILED"
fi

# 3. FORMAT - Style fixes (auto-fix)
cargo fmt

# 4. TEST - Functionality
cargo test
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ TESTS FAILED"
fi
```

---

## Extracting Commands from Repo Files

### From Markdown Files (CLAUDE.md, README.md, etc.)

Look for code blocks with commands:

```markdown
## Build and Test

Build the project:
```bash
npm run build
```

Run tests:
```bash
npm test
```
```

**Extract**: `npm run build`, `npm test`

### From GitHub Actions

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    steps:
      - name: Build
        run: go build ./...

      - name: Lint
        run: golangci-lint run

      - name: Test
        run: go test -v ./...
```

**Extract**: `go build ./...`, `golangci-lint run`, `go test -v ./...`

### From package.json

```json
{
  "scripts": {
    "build": "tsc",
    "lint": "eslint . --max-warnings 0",
    "format": "prettier --write .",
    "test": "jest --coverage"
  }
}
```

**Extract**: `npm run build`, `npm run lint`, `npm run format`, `npm test`

### From Makefile

```makefile
build:
	go build -tags unit,integration ./...

lint:
	golangci-lint run

test:
	go test -tags unit,integration ./...
```

**Extract**: `make build`, `make lint`, `make test`

---

## Command Discovery Algorithm

```bash
# 1. Read repo's AI instructions
commands=$(extract_commands_from_ai_instructions)

# 2. If not found, check CI configs
if [ -z "$commands" ]; then
  commands=$(extract_commands_from_ci_configs)
fi

# 3. If not found, check scripts
if [ -z "$commands" ]; then
  commands=$(extract_commands_from_scripts)
fi

# 4. If not found, use language defaults
if [ -z "$commands" ]; then
  commands=$(get_language_defaults)
fi

# 5. Execute discovered commands
for cmd in $commands; do
  echo "Running: $cmd"
  $cmd
  if [ $? -ne 0 ]; then
    echo "❌ FAILED: $cmd"
    # Fix and retry
  fi
done
```

---

## Execution Flow

### For EACH PR:

```bash
# 1. Setup workspace
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
gh repo clone owner/repo .
gh pr checkout ${PR_NUMBER}

# 2. DISCOVER validation commands from repo's own documentation
echo "Discovering validation commands from repository..."

# Check CLAUDE.md
if [ -f "CLAUDE.md" ]; then
  echo "Reading CLAUDE.md for build/test commands..."
  # Extract commands from ## Build, ## Test, ## Development sections
  BUILD_CMD=$(grep -A 5 "## Build" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`' | head -1)
  LINT_CMD=$(grep -A 5 "## Lint" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`' | head -1)
  TEST_CMD=$(grep -A 5 "## Test" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`' | head -1)
fi

# Check .github/workflows/*.yml if commands not found
if [ -z "$BUILD_CMD" ] && [ -d ".github/workflows" ]; then
  echo "Reading GitHub Actions for CI commands..."
  BUILD_CMD=$(grep -h "run:.*build" .github/workflows/*.yml | head -1 | sed 's/.*run: //')
  LINT_CMD=$(grep -h "run:.*lint" .github/workflows/*.yml | head -1 | sed 's/.*run: //')
  TEST_CMD=$(grep -h "run:.*test" .github/workflows/*.yml | head -1 | sed 's/.*run: //')
fi

# Check Makefile if commands not found
if [ -z "$BUILD_CMD" ] && [ -f "Makefile" ]; then
  echo "Found Makefile, using make targets..."
  BUILD_CMD="make build"
  LINT_CMD="make lint"
  TEST_CMD="make test"
fi

# Check package.json if commands not found
if [ -z "$BUILD_CMD" ] && [ -f "package.json" ]; then
  echo "Found package.json, using npm scripts..."
  BUILD_CMD="npm run build"
  LINT_CMD="npm run lint"
  TEST_CMD="npm test"
fi

# Fallback to language defaults only if nothing found
if [ -z "$BUILD_CMD" ]; then
  echo "No repo-specific commands found, using language defaults..."
  # Detect language and use defaults (see "Language Defaults" section)
fi

echo "Discovered commands:"
echo "  Build: $BUILD_CMD"
echo "  Lint: $LINT_CMD"
echo "  Test: $TEST_CMD"

# 3. Run discovered validation commands
echo "Running build..."
$BUILD_CMD
if [ $? -ne 0 ]; then
  echo "❌ BUILD FAILED"
  # Fix build errors
  # Rerun: $BUILD_CMD
fi

echo "Running linter..."
$LINT_CMD
if [ $? -ne 0 ]; then
  echo "❌ LINT FAILED"
  # Fix lint errors
  # Rerun: $LINT_CMD
fi

echo "Running tests..."
$TEST_CMD
if [ $? -ne 0 ]; then
  echo "❌ TESTS FAILED"
  # Fix test failures
  # Rerun: $TEST_CMD
fi

# 4. Push fixes (only if all validations passed)
git push origin $(git branch --show-current)

# 5. Cleanup
cd /
rm -rf "$WORKSPACE"
```

---

## Scale: How to Process Multiple PRs

### Answer: One at a time, sequentially

```
FOR PR #1:
  - Setup workspace
  - Run all validation commands
  - Fix all issues
  - Push fixes
  - Clean up workspace
  ← WAIT for this PR to complete before starting next

FOR PR #2:
  - Setup workspace
  - Run all validation commands
  - Fix all issues
  - Push fixes
  - Clean up workspace
  ← WAIT for this PR to complete

... continue for all PRs
```

**NOT**: Analyze all PRs, then report everything
**YES**: Fix each PR completely, push it, move to next

---

## Exit Code Handling

**CRITICAL**: Check exit codes after EVERY command

```bash
# CORRECT
go build ./...
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Build failed - fixing..."
  # Fix the issue
  go build ./...  # Rerun after fix
fi

# WRONG - Don't ignore failures
go build ./...  # Might fail
go test ./...   # Continues anyway ← BAD!
```

---

## What "Review" Means

❌ **NOT THIS**: "Review against architectural principles" (abstract analysis)
✅ **THIS**: Run `golangci-lint run` and check if exit code is 0

❌ **NOT THIS**: "Check naming conventions" (manual inspection)
✅ **THIS**: Linter will catch naming issues - fix what it reports

**Everything must be executable commands with measurable pass/fail.**

---

## Summary for AI Agents

1. **Checkout PR branch** in temp workspace
2. **Run actual commands** (build, generate, lint, format, test)
3. **Check exit codes** after each command
4. **Fix failures** if any command fails
5. **Rerun command** after fixing
6. **Push fixes** when all commands pass
7. **Clean up workspace**
8. **Move to next PR**

This is hands-on command execution, not abstract code review.
