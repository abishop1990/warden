# Warden - Exact Commands to Execute

**IMPORTANT**: This is NOT conceptual review. You ACTUALLY RUN these commands and check exit codes.

## Validation Commands by Language

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

## Execution Flow

### For EACH PR:

```bash
# 1. Setup
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
gh repo clone owner/repo .
gh pr checkout ${PR_NUMBER}

# 2. Run validation commands (language-specific)
# For Go example:
go build -tags unit,integration ./...
if [ $? -ne 0 ]; then
  # Fix build errors
  # Rerun build
fi

go generate ./...
git diff --exit-code
if [ $? -ne 0 ]; then
  git add .
  git commit -m "Add generated files"
fi

golangci-lint run
if [ $? -ne 0 ]; then
  # Fix lint errors
  # Rerun lint
fi

gofmt -s -w .
git add .
git commit -m "Format code"

go test -tags unit,integration ./...
if [ $? -ne 0 ]; then
  # Fix test failures
  # Rerun tests
fi

# 3. Push fixes
git push origin $(git branch --show-current)

# 4. Cleanup
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
