# PHASE 0: MANDATORY COMMAND DISCOVERY

**CRITICAL**: This phase is MANDATORY and BLOCKING. You CANNOT proceed to Phase 5 (Execution) without completing this phase.

## Purpose

Discover and save the exact build/lint/format/test commands used by the target repository. Create an executable artifact that Phase 5 MUST use.

## Why This Is Mandatory

**Problem**: If agents can skip command discovery, they will push code without proper validation (e.g., missing `gofmt`, `black`, `eslint --fix`), causing immediate CI failures.

**Solution**: Make command discovery mandatory with artifact creation. Phase 5 checks for this artifact before executing ANY fixes.

## Phase 0 Requirements

### 1. MUST Complete Before Phase 1

This phase runs BEFORE discovering PRs. You need commands before you can validate fixes.

### 2. MUST Create Artifact

Create `$WORKSPACE/.warden-validation-commands.sh` containing discovered commands.

### 3. MUST Block Phase 5

Phase 5 MUST verify this artifact exists before making any fixes.

## Execution Steps

### Step 1: Determine Target Repository

```bash
# Get repository being analyzed
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
WORKSPACE="${WORKSPACE:-$(pwd)}"
```

### Step 2: Discover Commands (Priority Order)

**Priority**:
1. AI instruction files (CLAUDE.md, .cursorrules, etc.)
2. CI configuration (.github/workflows/*.yml)
3. Language-specific configs (Makefile, package.json, etc.)
4. Language defaults (last resort)

**Discovery script**:
```bash
#!/bin/bash
# Save as: discover-commands.sh

REPO_ROOT="${1:-.}"
cd "$REPO_ROOT" || exit 1

echo "=== Discovering Validation Commands ==="

# Initialize variables
BUILD_CMD=""
LINT_CMD=""
FORMAT_CMD=""
TEST_CMD=""

# Priority 1: AI instruction files
echo "[1/4] Checking AI instruction files..."
for FILE in CLAUDE.md .cursorrules .github/copilot-instructions.md; do
  if [ -f "$FILE" ]; then
    echo "  Found: $FILE"

    # Extract Build command
    [ -z "$BUILD_CMD" ] && BUILD_CMD=$(grep -A 3 "Build:" "$FILE" | grep -o '`[^`]*`' | head -1 | tr -d '`')

    # Extract Lint command
    [ -z "$LINT_CMD" ] && LINT_CMD=$(grep -A 3 "Lint:" "$FILE" | grep -o '`[^`]*`' | head -1 | tr -d '`')

    # Extract Format command
    [ -z "$FORMAT_CMD" ] && FORMAT_CMD=$(grep -A 3 "Format:" "$FILE" | grep -o '`[^`]*`' | head -1 | tr -d '`')

    # Extract Test command
    [ -z "$TEST_CMD" ] && TEST_CMD=$(grep -A 3 "Test:" "$FILE" | grep -o '`[^`]*`' | head -1 | tr -d '`')
  fi
done

# Priority 2: CI configuration
echo "[2/4] Checking CI configuration..."
if [ -z "$BUILD_CMD" ] || [ -z "$TEST_CMD" ]; then
  for WORKFLOW in .github/workflows/*.yml .github/workflows/*.yaml; do
    if [ -f "$WORKFLOW" ]; then
      echo "  Found: $WORKFLOW"

      [ -z "$BUILD_CMD" ] && BUILD_CMD=$(grep "run:.*build" "$WORKFLOW" | head -1 | sed 's/.*run: *//')
      [ -z "$LINT_CMD" ] && LINT_CMD=$(grep "run:.*lint" "$WORKFLOW" | head -1 | sed 's/.*run: *//')
      [ -z "$FORMAT_CMD" ] && FORMAT_CMD=$(grep "run:.*format\|run:.*fmt" "$WORKFLOW" | head -1 | sed 's/.*run: *//')
      [ -z "$TEST_CMD" ] && TEST_CMD=$(grep "run:.*test" "$WORKFLOW" | head -1 | sed 's/.*run: *//')
    fi
  done
fi

# Priority 3: Language-specific configs
echo "[3/4] Checking language configs..."
if [ -f "Makefile" ] && [ -z "$BUILD_CMD" ]; then
  grep -q "^build:" Makefile && BUILD_CMD="make build"
  grep -q "^test:" Makefile && TEST_CMD="make test"
  grep -q "^lint:" Makefile && LINT_CMD="make lint"
  grep -q "^fmt:" Makefile && FORMAT_CMD="make fmt"
fi

if [ -f "package.json" ]; then
  [ -z "$BUILD_CMD" ] && grep -q '"build"' package.json && BUILD_CMD="npm run build"
  [ -z "$TEST_CMD" ] && grep -q '"test"' package.json && TEST_CMD="npm test"
  [ -z "$LINT_CMD" ] && grep -q '"lint"' package.json && LINT_CMD="npm run lint"
fi

# Priority 4: Language defaults (detect language first)
echo "[4/4] Applying language defaults..."
if [ -z "$BUILD_CMD" ] || [ -z "$TEST_CMD" ]; then
  # Detect language
  if ls *.go &>/dev/null || [ -f "go.mod" ]; then
    LANG="go"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="go build ./..."
    [ -z "$LINT_CMD" ] && LINT_CMD="golangci-lint run"
    [ -z "$FORMAT_CMD" ] && FORMAT_CMD="gofmt -s -w ."
    [ -z "$TEST_CMD" ] && TEST_CMD="go test -v ./..."

  elif ls *.py &>/dev/null || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
    LANG="python"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="python -m compileall ."
    [ -z "$LINT_CMD" ] && LINT_CMD="ruff check ."
    [ -z "$FORMAT_CMD" ] && FORMAT_CMD="black ."
    [ -z "$TEST_CMD" ] && TEST_CMD="pytest"

  elif [ -f "package.json" ]; then
    LANG="javascript"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="npm run build || echo 'No build script'"
    [ -z "$LINT_CMD" ] && LINT_CMD="npm run lint || eslint ."
    [ -z "$FORMAT_CMD" ] && FORMAT_CMD="prettier --write ."
    [ -z "$TEST_CMD" ] && TEST_CMD="npm test"

  elif ls *.rs &>/dev/null || [ -f "Cargo.toml" ]; then
    LANG="rust"
    [ -z "$BUILD_CMD" ] && BUILD_CMD="cargo build"
    [ -z "$LINT_CMD" ] && LINT_CMD="cargo clippy"
    [ -z "$FORMAT_CMD" ] && FORMAT_CMD="cargo fmt"
    [ -z "$TEST_CMD" ] && TEST_CMD="cargo test"
  else
    LANG="unknown"
  fi
  echo "  Detected language: $LANG"
fi

# Summary
echo ""
echo "=== Discovered Commands ==="
echo "BUILD:  ${BUILD_CMD:-[none]}"
echo "LINT:   ${LINT_CMD:-[none]}"
echo "FORMAT: ${FORMAT_CMD:-[none]}"
echo "TEST:   ${TEST_CMD:-[none]}"
echo ""

# Validation
if [ -z "$BUILD_CMD" ] && [ -z "$TEST_CMD" ]; then
  echo "⚠️  WARNING: No build or test commands discovered!"
  echo "    This may result in CI failures after pushing."
  echo "    Consider adding commands to CLAUDE.md or CI config."
fi

# Export for use in other scripts
echo "export BUILD_CMD='$BUILD_CMD'"
echo "export LINT_CMD='$LINT_CMD'"
echo "export FORMAT_CMD='$FORMAT_CMD'"
echo "export TEST_CMD='$TEST_CMD'"
```

### Step 3: Create Validation Artifact

**CRITICAL**: Save discovered commands to artifact that Phase 5 MUST check.

```bash
#!/bin/bash
# Create validation artifact

WORKSPACE="${WORKSPACE:-$(pwd)}"
ARTIFACT="$WORKSPACE/.warden-validation-commands.sh"

# Run discovery
./discover-commands.sh > "$ARTIFACT"

# Make executable
chmod +x "$ARTIFACT"

# Verify artifact created
if [ ! -f "$ARTIFACT" ]; then
  echo "❌ FATAL: Failed to create validation artifact at $ARTIFACT"
  echo "CANNOT proceed to Phase 5 without validation commands."
  exit 1
fi

echo "✅ Validation artifact created: $ARTIFACT"

# Source and verify commands
source "$ARTIFACT"

if [ -z "$BUILD_CMD" ] && [ -z "$TEST_CMD" ]; then
  echo "⚠️  WARNING: No validation commands discovered"
  echo "Proceeding with caution..."
fi
```

### Step 4: Verification

**Before Phase 5 can start**:

```bash
#!/bin/bash
# Phase 5 pre-check (MANDATORY)

WORKSPACE="${WORKSPACE:-$(pwd)}"
ARTIFACT="$WORKSPACE/.warden-validation-commands.sh"

# BLOCKING CHECK
if [ ! -f "$ARTIFACT" ]; then
  echo "❌ FATAL ERROR: Phase 0 not completed!"
  echo ""
  echo "Required artifact not found: $ARTIFACT"
  echo ""
  echo "You MUST complete Phase 0 (Command Discovery) before Phase 5 (Execution)."
  echo "Run: ./discover-commands.sh to create validation artifact"
  echo ""
  echo "STOPPING EXECUTION."
  exit 1
fi

echo "✅ Phase 0 verification passed: $ARTIFACT exists"

# Source commands
source "$ARTIFACT"

echo "Loaded validation commands:"
echo "  BUILD:  ${BUILD_CMD:-[skip]}"
echo "  LINT:   ${LINT_CMD:-[skip]}"
echo "  FORMAT: ${FORMAT_CMD:-[skip]}"
echo "  TEST:   ${TEST_CMD:-[skip]}"
```

## Phase 5 Integration

**Phase 5 MUST**:
1. Check for artifact existence (blocking)
2. Source the artifact to load commands
3. Execute commands in order: BUILD → LINT → FORMAT → TEST
4. Block push if any validation fails

```bash
#!/bin/bash
# Phase 5: Execution with mandatory validation

WORKSPACE="${WORKSPACE:-$(pwd)}"
ARTIFACT="$WORKSPACE/.warden-validation-commands.sh"

# MANDATORY BLOCKING CHECK
if [ ! -f "$ARTIFACT" ]; then
  echo "❌ FATAL: Cannot execute Phase 5 without Phase 0 completion"
  exit 1
fi

# Source validation commands
source "$ARTIFACT"

# Apply fixes
echo "Applying fixes for ${TIER} severity..."
# ... fix code ...

# MANDATORY VALIDATION SEQUENCE
echo "Running validation sequence..."

# 1. Build (if available)
if [ -n "$BUILD_CMD" ]; then
  echo "[1/4] Build: $BUILD_CMD"
  eval "$BUILD_CMD"
  if [ $? -ne 0 ]; then
    echo "❌ Build failed - rolling back"
    git reset --hard HEAD
    exit 1
  fi
fi

# 2. Lint (if available)
if [ -n "$LINT_CMD" ]; then
  echo "[2/4] Lint: $LINT_CMD"
  eval "$LINT_CMD"
  if [ $? -ne 0 ]; then
    echo "❌ Lint failed - rolling back"
    git reset --hard HEAD
    exit 1
  fi
fi

# 3. Format (always run, ignore errors)
if [ -n "$FORMAT_CMD" ]; then
  echo "[3/4] Format: $FORMAT_CMD"
  eval "$FORMAT_CMD" || true  # Format errors are usually auto-fixed
  git add -u  # Stage format changes
fi

# 4. Test (if available)
if [ -n "$TEST_CMD" ]; then
  echo "[4/4] Test: $TEST_CMD"
  eval "$TEST_CMD"
  if [ $? -ne 0 ]; then
    echo "❌ Tests failed - rolling back"
    git reset --hard HEAD
    exit 1
  fi
fi

# All validations passed - safe to commit and push
git add .
git commit -m "Fix: ${TIER} severity issues"
git push origin "$(git branch --show-current)"

echo "✅ Phase 5 complete - all validations passed"
```

## Enforcement Rules

### Rule 1: Phase 0 Before Phase 1
Phase 0 MUST complete before discovering PRs.

### Rule 2: Artifact Creation is Mandatory
The artifact `$WORKSPACE/.warden-validation-commands.sh` MUST exist.

### Rule 3: Phase 5 MUST Check Artifact
Phase 5 MUST verify artifact exists before making ANY fixes.

### Rule 4: No Direct Command Usage
Phase 5 MUST NOT use hard-coded commands. MUST source from artifact.

### Rule 5: Validation Blocks Push
If BUILD/LINT/TEST fail, MUST rollback and MUST NOT push.

## Platform-Specific Notes

### Claude Code
- Run discovery as Bash tool (blocking)
- Create artifact in workspace
- Phase 5 checks artifact before Task tool launches

### GitHub Copilot
- Main agent runs discovery (subagents can't run bash)
- Save artifact to temp file
- Phase 5 main agent verifies before subagent fixes

### Cursor
- Run discovery in Composer
- Save artifact in workspace
- Reference artifact in all subsequent operations

## Troubleshooting

### "Phase 0 not completed" Error

**Cause**: Trying to execute Phase 5 without running Phase 0.

**Fix**:
```bash
# Run discovery
./discover-commands.sh > .warden-validation-commands.sh
chmod +x .warden-validation-commands.sh

# Verify
source .warden-validation-commands.sh
echo "Build: $BUILD_CMD"
```

### "No commands discovered" Warning

**Cause**: Repository has no detectable build/test commands.

**Fix**: Add commands to CLAUDE.md:
```markdown
## Build and Test
- Build: `make build`
- Lint: `golangci-lint run`
- Format: `gofmt -s -w .`
- Test: `go test -v ./...`
```

### Commands Not Working

**Cause**: Discovered commands may be incorrect.

**Fix**: Manually edit `.warden-validation-commands.sh` and update commands.

## See Also

- [VALIDATION-ORDER.md](VALIDATION-ORDER.md) - Validation sequence requirements
- [COMMANDS.md](COMMANDS.md) - Command discovery details
- [WORKFLOW.md](WORKFLOW.md) - Full workflow phases
