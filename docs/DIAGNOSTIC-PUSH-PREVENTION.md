# CRITICAL: Diagnostic Push Prevention (Gap #16)

**Gap #16**: Warden pushed code even though tests were failing locally, creating a "diagnostic push" anti-pattern where partial fixes are pushed to "save progress" while debugging.

## The Problem

**What happened**:
```
Developer/Agent workflow (WRONG):
1. Make fix attempt
2. Run tests → tests FAIL
3. Diagnose the issue
4. Push partial fix anyway "to save progress"
5. Plan to debug more later
6. Repeat steps 1-5 multiple times

Result: Multiple commits pushed with failing tests
```

**Real example from Gap #16 discovery**:
```bash
Commit 08dd878a: "Fix UUID to string conversion"
  - Query was comparing UUID object to string column causing 0 matches
  - Commit message PROVES tests were run and failed
  - TestGetAssociatedMetric: Expected 2 elements, got 0
  - **PUSHED ANYWAY** ❌

Commit fb505257: "Run gofmt formatting" (on debug file)
  - Tests still failing
  - **PUSHED ANYWAY** ❌

Commit c002749e: "Remove debug file" (cleanup)
  - Tests still failing
  - **PUSHED ANYWAY** ❌

None of these commits had passing tests!
```

**The smoking gun**: Commit message said "Query was comparing UUID object to string column causing 0 matches" - this PROVES the developer:
- RAN the test locally
- SAW it fail
- DIAGNOSED the root cause
- **Pushed the partial fix anyway without fixing it completely**

## Why This Happens

**Diagnostic push mindset**:
- "I'll push this partial fix to save my progress"
- "I'll debug the rest later"
- "At least this gets part of the fix out there"
- "I need to switch contexts, let me push what I have"

**Why it's wrong**:
- Breaks CI for everyone
- Other developers pull broken code
- Wastes CI resources
- Creates noisy commit history
- Violates the fundamental rule: **only push working code**

## The Solution

**HARD RULE: Tests must pass 100% before ANY push**

This is not a suggestion or recommendation - it must be **ABSOLUTELY BLOCKING**.

### Phase 6: Pre-Push Validation (ABSOLUTE BLOCKING)

**Current (BROKEN) enforcement**:
```bash
# This CAN be bypassed or ignored
$TEST_CMD || { rollback; exit 1; }
```

**New (ABSOLUTE) enforcement**:
```bash
#!/bin/bash
set -euo pipefail  # Exit on any error, no bypassing

echo "=== Phase 6: Pre-Push Validation (ABSOLUTE BLOCKING) ==="
echo ""
echo "HARD RULE: Tests must pass 100% before ANY push"
echo "No exceptions without explicit user approval"
echo ""

# Source validation commands from Phase 0
ARTIFACT="$WORKSPACE/.warden-validation-commands.sh"
if [ ! -f "$ARTIFACT" ]; then
  echo "❌ FATAL: Phase 0 artifact not found"
  exit 1
fi

source "$ARTIFACT"

# Track validation state
VALIDATION_FAILED=false

# 1. BUILD (BLOCKING)
echo "[1/5] Running build..."
if ! eval "$BUILD_CMD"; then
  echo "❌ BUILD FAILED"
  VALIDATION_FAILED=true
else
  echo "✅ Build passed"
fi

# 2. GENERATE (if applicable)
if [ -n "${GENERATE_CMD:-}" ]; then
  echo "[2/5] Running generate..."
  if ! eval "$GENERATE_CMD"; then
    echo "❌ GENERATE FAILED"
    VALIDATION_FAILED=true
  else
    echo "✅ Generate passed"
  fi
fi

# 3. LINT (BLOCKING)
echo "[3/5] Running lint..."
if ! eval "$LINT_CMD"; then
  echo "❌ LINT FAILED"
  VALIDATION_FAILED=true
else
  echo "✅ Lint passed"
fi

# 4. FORMAT (AUTO-FIX, but verify no manual changes needed)
echo "[4/5] Running format..."
eval "$FORMAT_CMD" || true  # Format always runs, errors ignored
if git diff --exit-code > /dev/null 2>&1; then
  echo "✅ Format passed (no changes needed)"
else
  echo "⚠️  Format made changes - these will be included in commit"
  git add .
fi

# 5. TESTS (ABSOLUTE BLOCKING)
echo "[5/5] Running tests..."
if ! eval "$TEST_CMD"; then
  echo ""
  echo "❌❌❌ TESTS FAILED ❌❌❌"
  echo ""
  echo "HARD RULE VIOLATION: Cannot push code with failing tests"
  echo ""
  echo "What failed:"
  echo "  - One or more tests returned failures"
  echo "  - OR: Tests expected data but got 0 results"
  echo "  - OR: Tests timed out or crashed"
  echo ""
  echo "This is a 'DIAGNOSTIC PUSH' attempt - you ran tests, saw failures,"
  echo "but tried to push anyway. This is NOT ALLOWED."
  echo ""
  VALIDATION_FAILED=true
else
  echo "✅ Tests passed"
fi

# BLOCKING CHECK: Did any validation fail?
if [ "$VALIDATION_FAILED" = true ]; then
  echo ""
  echo "=========================================="
  echo "  VALIDATION FAILED - CANNOT PUSH"
  echo "=========================================="
  echo ""
  echo "Rollback in progress..."
  git reset --hard HEAD
  echo ""
  echo "Options:"
  echo "  1. Fix the failures and run Warden again"
  echo "  2. If you MUST push failing tests (not recommended):"
  echo "     - Get explicit user approval"
  echo "     - Use commit message: 'WIP: Tests failing - [reason]'"
  echo "     - Push manually with: git push --force-with-lease"
  echo ""
  echo "Warden will NOT push failing code automatically."
  echo ""
  exit 1
fi

echo ""
echo "=========================================="
echo "  ✅ ALL VALIDATIONS PASSED"
echo "=========================================="
echo ""
echo "Safe to commit and push"
```

### Pre-Commit Verification (Additional Safety)

```bash
#!/bin/bash
# .git/hooks/pre-commit (optional additional safety)

echo "Pre-commit validation..."

# Run tests one more time right before commit
if ! make test; then
  echo ""
  echo "❌ TESTS FAILED - Cannot commit"
  echo ""
  echo "This appears to be a 'diagnostic push' attempt."
  echo "Tests must pass before committing."
  echo ""
  exit 1
fi

echo "✅ Pre-commit validation passed"
```

## Enforcement Rules

### Rule 1: MUST run all validations before push
```bash
# BLOCKING - cannot skip
$BUILD_CMD    || exit 1
$LINT_CMD     || exit 1
$FORMAT_CMD   # auto-fix
$TEST_CMD     || exit 1  # ABSOLUTE BLOCKING
```

### Rule 2: MUST rollback if any validation fails
```bash
if [ "$VALIDATION_FAILED" = true ]; then
  git reset --hard HEAD
  exit 1
fi
```

### Rule 3: MUST NOT push partial fixes
```bash
# If tests fail, STOP
# Do NOT push to "save progress"
# Do NOT push "will fix later"
# Do NOT push "debugging in progress"
```

### Rule 4: MUST get user approval for WIP pushes
```bash
# ONLY push failing tests if:
# 1. User explicitly approves: "Push anyway with failing tests"
# 2. Commit message: "WIP: Tests failing - [specific reason]"

# Warden NEVER pushes failing tests automatically
```

## Detection Mechanisms

### Detect "Diagnostic Push" Attempts

**Indicators**:
1. Tests ran but failed (exit code != 0)
2. Test output shows failures (FAIL, expected X got Y)
3. Commit message mentions debugging ("comparing UUID to string", "investigating", "partial fix")
4. Multiple consecutive commits with same test failing
5. Debug files in staging area (debug_*.go, *_debug.py)

**Detection code**:
```bash
# After running tests, check for diagnostic push
if [ $TEST_EXIT_CODE -ne 0 ]; then
  # Tests failed - check if this is a diagnostic push
  COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

  if echo "$COMMIT_MSG" | grep -qiE "(debug|investigating|partial|wip|temp|trying)"; then
    echo "⚠️  DIAGNOSTIC PUSH DETECTED"
    echo "Commit message suggests debugging: '$COMMIT_MSG'"
    echo "Tests are failing. This looks like a 'push to save progress' attempt."
    echo "BLOCKED."
    exit 1
  fi

  # Even without debug keywords, tests failing = block
  echo "❌ Tests failed - cannot push"
  exit 1
fi
```

### Detect Partial Fixes

**Indicators**:
1. Test output shows "Expected 2 elements, got 0"
2. Queries returning 0 results when expecting data
3. Null pointer exceptions
4. Type mismatches (UUID vs string)

**Detection code**:
```bash
# Analyze test output for partial fix indicators
TEST_OUTPUT=$(go test ./... 2>&1)

if echo "$TEST_OUTPUT" | grep -qiE "(expected [0-9]+ .* got 0|got 0 .* expected)"; then
  echo "⚠️  PARTIAL FIX DETECTED"
  echo "Test expecting data but got 0 results"
  echo "This indicates the fix is incomplete"
  echo "BLOCKED."
  exit 1
fi

if echo "$TEST_OUTPUT" | grep -qiE "(nil pointer|null reference|undefined)"; then
  echo "⚠️  INCOMPLETE FIX DETECTED"
  echo "Test hitting nil/null errors"
  echo "BLOCKED."
  exit 1
fi
```

## Common Scenarios

### Scenario 1: Partial Fix (Gap #16 Original)
```
WRONG workflow:
1. Fix review comment about UUID conversion
2. Run tests: TestGetAssociatedMetric FAILS (Expected 2, got 0)
3. Diagnose: "Query comparing UUID object to string column"
4. Commit: "Fix UUID to string conversion"
5. Push ❌ (tests still failing!)

CORRECT workflow:
1. Fix review comment about UUID conversion
2. Run tests: FAILS
3. Diagnose: "Query comparing UUID object to string column"
4. Fix the actual issue (convert UUID properly in query)
5. Run tests: PASSES ✅
6. Commit: "Fix UUID to string conversion in inventory query"
7. Push ✅
```

### Scenario 2: Debugging Session
```
WRONG workflow:
1. Add debug logging
2. Run tests: FAILS (but got useful debug output)
3. Commit: "Add debug logging"
4. Push ❌ (tests failing, debug file committed)
5. Fix issue
6. Commit: "Remove debug file"
7. Push ❌ (tests now pass, but 2 commits with failures)

CORRECT workflow:
1. Add debug logging (DON'T commit yet)
2. Run tests: FAILS (analyze debug output)
3. Fix issue
4. Remove debug logging
5. Run tests: PASSES ✅
6. Commit: "Fix issue X"
7. Push ✅ (single commit, all tests pass)
```

### Scenario 3: Incremental Fixes
```
WRONG workflow:
1. Fix Critical issues → tests FAIL (some tests fixed, others broken)
2. Push ❌
3. Fix High issues → tests FAIL (still debugging)
4. Push ❌
5. Fix remaining → tests PASS
6. Push (finally)

Result: 2 broken commits pushed

CORRECT workflow:
1. Fix Critical issues → tests FAIL
2. DON'T PUSH - keep fixing
3. Fix High issues → tests FAIL
4. DON'T PUSH - keep fixing
5. Fix remaining → tests PASS ✅
6. Commit and push ALL fixes together ✅

Result: 1 working commit pushed
```

## User Override Process

If user explicitly wants to push failing tests (extremely rare, last resort):

**Step 1: Get explicit approval**
```
Agent: "Tests are failing. Cannot push automatically."
Agent: "Do you want to push anyway? (NOT RECOMMENDED)"

User: "Yes, push anyway with failing tests"
```

**Step 2: Require WIP commit message**
```bash
if [ "$USER_APPROVED_WIP_PUSH" = true ]; then
  # Verify commit message includes WIP marker
  COMMIT_MSG="WIP: Tests failing - investigating UUID conversion issue"

  if ! echo "$COMMIT_MSG" | grep -q "^WIP:.*failing"; then
    echo "❌ WIP push requires commit message format:"
    echo "   'WIP: Tests failing - [specific reason]'"
    exit 1
  fi

  # Warn user
  echo "⚠️⚠️⚠️ WARNING ⚠️⚠️⚠️"
  echo "Pushing code with failing tests"
  echo "This will break CI"
  echo "Commit message: $COMMIT_MSG"
  echo ""

  git commit -m "$COMMIT_MSG"
  git push --force-with-lease
fi
```

**Step 3: Track WIP commits**
```bash
# After WIP push, track that tests need fixing
echo "$PR_NUMBER" >> .warden/wip-prs.txt
echo "⚠️  PR #$PR_NUMBER marked as WIP - tests failing"
echo "Remember to fix and push clean commit"
```

## Metrics and Reporting

Track diagnostic push attempts:

```bash
# Log diagnostic push attempts
if [ "$VALIDATION_FAILED" = true ]; then
  echo "$(date),PR#$PR_NUMBER,diagnostic_push_blocked" >> .warden/metrics.csv
fi

# Report at end of Warden run
echo ""
echo "Diagnostic Push Prevention:"
echo "  - Blocked: 3 attempts"
echo "  - Prevented commits: 3"
echo "  - CI failures avoided: 3"
```

## Testing the Fix

**Test 1: Verify blocking works**
```bash
# Simulate failing test
echo "TEST_CMD='go test ./... && exit 1'" > .warden-validation-commands.sh

# Try to run Phase 6
./run-phase6.sh

# Expected: BLOCKED, no push, rollback executed
```

**Test 2: Verify partial fix detection**
```bash
# Simulate test expecting data but getting 0
echo "TEST_CMD='echo FAIL: Expected 2 elements, got 0 && exit 1'" > .warden-validation-commands.sh

# Try to run Phase 6
./run-phase6.sh

# Expected: BLOCKED with "PARTIAL FIX DETECTED" message
```

**Test 3: Verify user override works**
```bash
# User approves WIP push
USER_APPROVED_WIP_PUSH=true
COMMIT_MSG="WIP: Tests failing - debugging UUID conversion"

# Should allow push with warnings
```

## Integration with Other Phases

### Phase 0: Command Discovery
- MUST discover complete test command
- Cannot use placeholder or empty test command
- MUST verify test command actually runs tests

### Phase 6: Execution
- MUST run Phase 6 validation before EVERY push
- Cannot skip or bypass validation
- Cannot push if ANY validation fails
- MUST rollback on failure

### Phase 7: Post-Push Monitoring (NEW)
- After push, watch CI status
- If CI fails unexpectedly, alert immediately
- Compare local test results vs CI results
- Flag environment differences

## See Also

- [WORKFLOW.md](WORKFLOW.md) - Phase 6 validation sequence
- [PHASE-0-DISCOVERY.md](PHASE-0-DISCOVERY.md) - Test command discovery
- [VALIDATION-ORDER.md](VALIDATION-ORDER.md) - Validation execution order
- GitHub Actions docs: Pre-commit hooks
