# CRITICAL: Validation Order (MUST READ)

## ⚠️ THE PROBLEM

**WRONG ORDER** (What Copilot was doing):
```
1. Make fixes
2. Commit fixes
3. Push to remote  ← DANGER! Pushing unvalidated code!
4. Run tests
5. See tests fail ← TOO LATE!
```

**This is DANGEROUS because**:
- Broken code gets pushed to PR
- CI fails publicly
- Other developers may pull broken code
- Wastes CI resources
- Violates the contract: "only push working code"

---

## ✅ THE CORRECT ORDER

**MANDATORY SEQUENCE** (Non-negotiable):

```
For each severity tier (Critical → High → Medium → Low):

1. Apply fixes for this tier
   ↓
2. **VALIDATE: Run build** (ensure code compiles)
   ↓
   Build PASSED?
   ├─ YES → Continue to step 3
   └─ NO  → ROLLBACK fixes, ABORT tier, continue to next tier
   ↓
3. **VALIDATE: Run linter** (catch code quality issues)
   ↓
   Lint PASSED?
   ├─ YES → Continue to step 4
   └─ NO  → ROLLBACK fixes, ABORT tier, continue to next tier
   ↓
4. Run language-specific formatting (auto-fix style)
   ↓
5. **VALIDATE: Run tests** ← CRITICAL GATE
   ↓
   Tests PASSED?
   ├─ YES → Continue to step 6
   └─ NO  → ROLLBACK fixes, ABORT tier, continue to next tier
   ↓
6. Commit changes (only if ALL validations passed)
   ↓
7. **Push to remote** (only after successful commit)
   ↓
8. Verify CI starts
   ↓
9. Clean up workspace
   ↓
10. Continue to next severity tier
```

---

## VALIDATION GATES (Never Skip These)

### Gate 1: Pre-Commit Validation
```bash
# After applying fixes, BEFORE committing:

# 1. RUN BUILD (BLOCKING)
<language-build-command>
BUILD_EXIT_CODE=$?
if [ $BUILD_EXIT_CODE -ne 0 ]; then
  echo "❌ BUILD FAILED - Rolling back fixes"
  git reset --hard HEAD
  exit 1  # ABORT - do not continue
fi

# 2. RUN LINTER (BLOCKING)
<language-lint-command>
LINT_EXIT_CODE=$?
if [ $LINT_EXIT_CODE -ne 0 ]; then
  echo "❌ LINT FAILED - Rolling back fixes"
  git reset --hard HEAD
  exit 1  # ABORT - do not continue
fi

# 3. RUN FORMATTER (auto-fix style issues)
git diff --name-only | xargs <language-formatter>

# 4. RUN TESTS (BLOCKING)
<language-test-command>
TEST_EXIT_CODE=$?
if [ $TEST_EXIT_CODE -ne 0 ]; then
  echo "❌ TESTS FAILED - Rolling back fixes"
  git reset --hard HEAD
  exit 1  # ABORT - do not commit or push
fi

# 5. Only if ALL validations passed, commit
git add <changed-files>
git commit -m "[PR #${PR_NUMBER}] Fix: ${TIER} - ${DESCRIPTION}"

# 6. Only if commit succeeded, push
git push origin ${PR_BRANCH}

# 7. Clean up workspace
cd / && rm -rf "$WORKSPACE"
```

### Gate 2: Post-Push Verification
```bash
# After pushing, verify CI starts
sleep 5
gh pr checks ${PR_NUMBER} --watch

# If CI fails immediately, alert user
```

---

## EXPLICIT CHECKS (Add to Workflow)

### Checkpoint 1: Before Any Commits
```bash
# MANDATORY: Verify no commits before validation
COMMITS_BEFORE=$(git rev-parse HEAD)

# Apply fixes...

# RUN TESTS
run_tests_for_tier

# Only commit if tests pass
if tests_passed; then
  git commit ...
  COMMITS_AFTER=$(git rev-parse HEAD)

  # Verify commit happened
  if [ "$COMMITS_AFTER" == "$COMMITS_BEFORE" ]; then
    echo "ERROR: Commit failed"
    exit 1
  fi
else
  echo "Tests failed - no commit created"
  git reset --hard HEAD
  continue  # Skip to next tier
fi
```

### Checkpoint 2: Before Any Pushes
```bash
# MANDATORY: Only push after validation

# Verify tests ran and passed
if [ ! -f "/tmp/tier-${TIER}-tests-passed" ]; then
  echo "❌ CRITICAL ERROR: Attempting to push without validation!"
  echo "ABORTING to prevent pushing broken code"
  exit 1
fi

# Verify commit exists
if ! git diff --quiet HEAD origin/${PR_BRANCH}; then
  # We have unpushed commits - push them
  git push origin ${PR_BRANCH}
else
  echo "No changes to push"
fi

# Clean up validation marker
rm "/tmp/tier-${TIER}-tests-passed"
```

---

## IMPLEMENTATION FOR EACH PLATFORM

### Claude Code (MANDATORY SEQUENCE)
```
Phase 5.2: Incremental Fix Strategy

For each severity tier:

1. Apply all fixes at this tier
   → Use main agent (simple) or Bash/general-purpose agent (complex)

2. **CRITICAL: RUN BUILD BEFORE CONTINUING**
   → BLOCKING operation - MUST wait for completion
   → Use Bash agent: run_build_for_tier
   → Capture exit code
   → Log output

   if exit code != 0:
     → Log "Build failed for ${TIER} tier"
     → git reset --hard HEAD  (rollback fixes)
     → Mark tier as failed
     → Continue to next tier (don't push anything)
     → NEVER commit or push

3. **CRITICAL: RUN LINTER BEFORE CONTINUING**
   → BLOCKING operation - MUST wait for completion
   → Use Bash agent: run_lint_for_tier
   → Capture exit code
   → Log output

   if exit code != 0:
     → Log "Lint failed for ${TIER} tier"
     → git reset --hard HEAD  (rollback fixes)
     → Mark tier as failed
     → Continue to next tier (don't push anything)
     → NEVER commit or push

4. Run formatting on changed files ONLY
   → git diff --name-only | xargs formatter
   → Auto-fix style issues

5. **CRITICAL: RUN TESTS BEFORE COMMIT**
   → BLOCKING operation - MUST wait for completion
   → Use Bash agent: run_tests_for_tier
   → Capture exit code
   → Log output

6. **CHECK ALL VALIDATION RESULTS**
   if exit code != 0:
     → Log "Tests failed for ${TIER} tier"
     → git reset --hard HEAD  (rollback fixes)
     → Mark tier as failed
     → Continue to next tier (don't push anything)
     → NEVER commit or push

   if exit code == 0:
     → Log "All validations passed for ${TIER} tier"
     → Create validation marker
     → Continue to step 7

7. Commit (ONLY if all validations passed)
   → git add <changed-files>
   → git commit -m "..."
   → Verify commit created

8. Push (ONLY if step 7 succeeded)
   → Verify validation marker exists
   → git push origin ${PR_BRANCH}
   → Verify push succeeded

9. Verify CI
   → sleep 5
   → gh pr checks ${PR_NUMBER}

10. Clean up workspace
   → cd / && rm -rf "$WORKSPACE"
   → Verify cleanup completed
```

### GitHub Copilot (MANDATORY SEQUENCE)
```
Use @github to ensure proper sequencing:

@github "For PR #123, apply Critical fixes, then:
1. Format changed files
2. **RUN TESTS** (must pass before proceeding)
3. Only if tests pass: commit with message 'Fix: Critical issues'
4. Only if commit succeeded: push to PR branch
5. If tests fail: rollback and skip to High tier"
```

### Cursor (MANDATORY SEQUENCE)
```
Use Composer with explicit steps:

1. Make fixes
2. Format: Run formatter on changed files
3. **VALIDATE: Run test command and wait for result**
4. If tests failed: Undo changes, mark tier failed
5. If tests passed: Commit changes
6. Only after commit: Push to remote
```

---

## VERIFICATION SCRIPT

Add this to every Warden run:

```bash
#!/bin/bash
# verify-validation-order.sh

set -e

PR_BRANCH="$1"
TIER="$2"

echo "🔍 Verifying validation order for ${TIER} tier..."

# Check 1: No commits before tests pass
if git diff --quiet HEAD origin/${PR_BRANCH}; then
  echo "✓ No premature commits detected"
else
  echo "⚠️  WARNING: Commits exist - verifying they were tested first"

  # Check for validation marker
  if [ ! -f "/tmp/warden-validated-${TIER}" ]; then
    echo "❌ CRITICAL: Commits exist without validation!"
    echo "This violates the validation order contract."
    exit 1
  fi
fi

# Check 2: Validation marker exists before push
echo "Checking for validation marker..."
if [ -f "/tmp/warden-validated-${TIER}" ]; then
  echo "✓ Validation passed before commit"
else
  echo "❌ ERROR: No validation marker found"
  echo "Tests must pass before committing"
  exit 1
fi

# Check 3: Remote is not ahead of local (no premature pushes)
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/${PR_BRANCH})

if [ "$LOCAL" == "$REMOTE" ]; then
  echo "✓ Local and remote in sync - safe to push"
elif git merge-base --is-ancestor $LOCAL $REMOTE; then
  echo "❌ ERROR: Remote is ahead - did we push before validating?"
  exit 1
else
  echo "✓ Local is ahead - validation passed, ready to push"
fi

echo "✅ Validation order verified for ${TIER} tier"
```

---

## ANTI-PATTERNS (NEVER DO THIS)

### ❌ WRONG: Push then validate
```bash
# NEVER DO THIS
git commit -m "fixes"
git push  # ← WRONG! No validation!
npm test  # ← TOO LATE
```

### ❌ WRONG: Background testing
```bash
# NEVER DO THIS
npm test &  # ← Tests in background
git commit  # ← Commits immediately
git push    # ← Pushes without waiting
```

### ❌ WRONG: Assuming tests pass
```bash
# NEVER DO THIS
npm test || true  # ← Ignores test failures
git commit        # ← Commits anyway
git push          # ← Pushes broken code
```

---

## CORRECT PATTERNS (ALWAYS DO THIS)

### ✅ CORRECT: Block on tests
```bash
# Run tests (BLOCKING)
npm test
TEST_EXIT=$?

# Check result
if [ $TEST_EXIT -ne 0 ]; then
  echo "Tests failed - aborting"
  git reset --hard HEAD
  exit 1
fi

# Only reached if tests passed
git commit -m "fixes"
git push
```

### ✅ CORRECT: Explicit validation markers
```bash
# Run tests
if npm test; then
  touch /tmp/tier-validated
  git commit -m "fixes"

  # Verify marker before push
  [ -f /tmp/tier-validated ] || exit 1
  git push
  rm /tmp/tier-validated
else
  echo "Tests failed - no commit"
  git reset --hard HEAD
fi
```

---

## DEBUGGING VALIDATION ORDER

If you suspect validation order is wrong:

```bash
# Add these checks to your workflow

echo "=== VALIDATION ORDER DEBUG ==="
echo "Current HEAD: $(git rev-parse HEAD)"
echo "Validation markers:"
ls -la /tmp/warden-validated-* 2>/dev/null || echo "  (none)"
echo "Uncommitted changes:"
git status --short
echo "Unpushed commits:"
git log origin/${PR_BRANCH}..HEAD --oneline
echo "=============================="
```

---

## ENFORCEMENT

Add this check to the beginning of every push:

```bash
# Before ANY git push:
if [ ! -f "/tmp/warden-tier-${TIER}-validated" ]; then
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║ CRITICAL ERROR: VALIDATION ORDER VIOLATION                 ║"
  echo "║                                                            ║"
  echo "║ Attempting to push without validation!                    ║"
  echo "║                                                            ║"
  echo "║ This is forbidden. Tests MUST pass before push.           ║"
  echo "║                                                            ║"
  echo "║ Correct order:                                             ║"
  echo "║   1. Apply fixes                                           ║"
  echo "║   2. Run tests (MUST PASS)                                 ║"
  echo "║   3. Commit (only if tests pass)                           ║"
  echo "║   4. Push (only after commit)                              ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  exit 1
fi
```

---

## SUMMARY

**THE GOLDEN RULE**:
```
NO PUSH WITHOUT FULL VALIDATION
NO COMMIT WITHOUT ALL CHECKS PASSING
BUILD + LINT + TESTS MUST COMPLETE BEFORE COMMIT
```

**If in doubt, the order is**:
1. Fix
2. **BUILD** ← BLOCKING GATE 1 (ensure compilation)
3. **LINT** ← BLOCKING GATE 2 (catch code quality issues)
4. Format (auto-fix style)
5. **TEST** ← BLOCKING GATE 3 (ensure functionality)
6. Commit (conditional on #2, #3, #5 ALL passing)
7. Push (conditional on #6)
8. Clean up workspace

**Any deviation from this order is a critical bug and must be fixed immediately.**

**Why all three validations?**
- **Build**: Catches syntax errors, type errors, compilation failures
- **Lint**: Catches code quality issues, style violations, potential bugs
- **Tests**: Ensures functionality works correctly

Skipping any of these leads to CI failures after push, causing multiple push/fix cycles.
