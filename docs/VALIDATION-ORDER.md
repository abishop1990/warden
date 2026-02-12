# CRITICAL: Validation Order

**TL;DR**: Phase 0 creates validation artifact → Phase 5 sources artifact → Run Build → Lint → Format → Test → Push.

**⚠️ MANDATORY**: Phase 0 MUST complete before Phase 5. Phase 5 is BLOCKED without validation artifact.

## The Problem

**WRONG** (What happened to you):
1. Skip Phase 0 command discovery
2. Apply fixes in Phase 5
3. Push without validation
4. CI fails immediately (gofmt, lint errors)

**RIGHT** (Enforced workflow):
1. **Phase 0**: Discover and save commands to artifact `.warden-validation-commands.sh` (BLOCKING)
2. **Phase 5**: Source artifact, validate, push

## The Correct Sequence

For each severity tier:

```
1. Apply fixes
2. Build  → Exit code != 0? Rollback, abort tier
3. Lint   → Exit code != 0? Rollback, abort tier
4. Format → Auto-fix style
5. Test   → Exit code != 0? Rollback, abort tier
6. Commit → Only if all validations passed
7. Push   → Only after commit
8. Cleanup workspace
```

## Implementation

**Phase 0 (MANDATORY)**: Create validation artifact (see [PHASE-0-DISCOVERY.md](PHASE-0-DISCOVERY.md)):
```bash
# Discover commands and save to artifact
./discover-commands.sh > .warden-validation-commands.sh
chmod +x .warden-validation-commands.sh

# BLOCKING CHECK
if [ ! -f ".warden-validation-commands.sh" ]; then
  echo "❌ FATAL: Phase 0 failed"
  exit 1
fi
```

**Phase 5 (MANDATORY)**: Source artifact then validate:
```bash
# MANDATORY: Verify artifact exists
ARTIFACT=".warden-validation-commands.sh"
if [ ! -f "$ARTIFACT" ]; then
  echo "❌ FATAL: Phase 0 not completed - cannot validate"
  exit 1
fi

# Source validation commands
source "$ARTIFACT"

# After applying fixes, run validations:

# 1. Build
$BUILD_CMD
if [ $? -ne 0 ]; then
  git reset --hard HEAD  # Rollback
  exit 1  # Abort tier
fi

# Lint
$LINT_CMD
if [ $? -ne 0 ]; then
  git reset --hard HEAD
  exit 1
fi

# Format
$FORMAT_CMD

# 4. Test
$TEST_CMD
if [ $? -ne 0 ]; then
  git reset --hard HEAD
  exit 1
fi

# 5. PRE-COMMIT VERIFICATION (MANDATORY)
echo "=== Pre-Commit File Verification ==="

# Stage files
git add .

# Show exactly what will be committed
echo "Files to be committed:"
git status --short

# Check for unintended files (debug, temp, IDE files)
UNINTENDED=$(git diff --cached --name-only | grep -E '(_debug\.|test_debug\.|debug_.*\.|\.debug$|\.tmp$|\.swp$|\.swo$|~$|\.DS_Store$)')

if [ -n "$UNINTENDED" ]; then
  echo "❌ ERROR: Unintended files staged for commit:"
  echo "$UNINTENDED"
  echo ""
  echo "These appear to be debug/temp/IDE files."
  echo "Review .gitignore and unstage with: git reset HEAD <file>"
  git reset --hard HEAD  # Rollback
  exit 1
fi

# Verify only intended files are staged
STAGED_COUNT=$(git diff --cached --name-only | wc -l)
if [ $STAGED_COUNT -eq 0 ]; then
  echo "❌ ERROR: No files staged for commit"
  exit 1
fi

echo "✅ Pre-commit verification passed ($STAGED_COUNT files)"
echo ""

# 6. Commit
git commit -m "Fix: ${TIER}"

# 7. Push
git push origin $(git branch --show-current)

# Cleanup
cd / && rm -rf "$WORKSPACE"
```

## Enforcement

**Rule 1: Phase 0 MUST complete before Phase 5**
```bash
# At start of Phase 5 - BLOCKING CHECK
if [ ! -f "$WORKSPACE/.warden-validation-commands.sh" ]; then
  echo "❌ FATAL: Phase 0 not completed!"
  echo "Required artifact: $WORKSPACE/.warden-validation-commands.sh"
  echo "Run Phase 0 to discover validation commands."
  exit 1
fi
```

**Rule 2: MUST source artifact before validation**
```bash
# Phase 5 validation sequence
source "$WORKSPACE/.warden-validation-commands.sh"

# Now commands are available
echo "Using validation commands:"
echo "  BUILD:  $BUILD_CMD"
echo "  LINT:   $LINT_CMD"
echo "  FORMAT: $FORMAT_CMD"
echo "  TEST:   $TEST_CMD"
```

**Rule 3: MUST validate before push**
```bash
# After each tier's fixes, create validation marker
if [ $? -eq 0 ]; then
  touch "/tmp/warden-tier-${TIER}-validated"
fi

# Before push - check validation marker
if [ ! -f "/tmp/warden-tier-${TIER}-validated" ]; then
  echo "❌ ERROR: Cannot push without validation!"
  exit 1
fi
```

**Rule 4: MUST verify staged files before commit**
```bash
# After validation passes, before commit
git add .

# Show what will be committed
git status --short

# Check for unintended files (debug, temp, IDE)
UNINTENDED=$(git diff --cached --name-only | grep -E '(_debug\.|test_debug\.|debug_.*\.|\.debug$|\.tmp$|\.swp$)')

if [ -n "$UNINTENDED" ]; then
  echo "❌ ERROR: Unintended files staged:"
  echo "$UNINTENDED"
  git reset --hard HEAD
  exit 1
fi

# Verify at least one file staged
if [ $(git diff --cached --name-only | wc -l) -eq 0 ]; then
  echo "❌ ERROR: No files staged"
  exit 1
fi
```

## Platform-Specific

**Claude Code**: Use Bash agent for each validation (blocking), check exit codes
**Copilot**: Use sequential commands with `&&`, not background tasks
**Cursor**: Use Composer with explicit step-by-step execution

## The Golden Rule

```
NO PUSH WITHOUT VALIDATION
BUILD + LINT + TEST MUST PASS BEFORE COMMIT
```

**Why all three?**
- Build: Catches compilation errors
- Lint: Catches code quality issues
- Test: Ensures functionality works

Skip any = CI fails after push = multiple fix/push cycles
