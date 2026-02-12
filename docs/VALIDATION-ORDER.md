# CRITICAL: Validation Order

## The Problem

**WRONG**: Push → Validate → See CI fail
**RIGHT**: Validate → Push

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

```bash
# After applying fixes:

# Build
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

# Test
$TEST_CMD
if [ $? -ne 0 ]; then
  git reset --hard HEAD
  exit 1
fi

# All passed - commit
git add .
git commit -m "Fix: ${TIER}"

# Push
git push origin $(git branch --show-current)

# Cleanup
cd / && rm -rf "$WORKSPACE"
```

## Enforcement

```bash
# Before push - check validation marker
if [ ! -f "/tmp/warden-tier-${TIER}-validated" ]; then
  echo "ERROR: Cannot push without validation!"
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
