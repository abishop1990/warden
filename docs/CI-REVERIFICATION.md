# CRITICAL: CI Status Re-verification

**Gap #16**: Warden checked CI status in Phase 1 but never re-verified before Phase 4, leading to stale data and wrong fix recommendations.

## The Problem

**What was happening**:
```bash
# ❌ WRONG - Only check CI once in Phase 1
Phase 1: gh pr checks 123 --json status,conclusion
         → Save to memory
         → Never check again

Phase 2-3: (Analysis and Planning - takes 2-5 minutes)

Phase 4: Present report using Phase 1 data
         → CI may have changed!
         → User sees stale information
```

**What was missed**:
```
Real scenario (Gap #16):

Phase 1 (Time: 10:00 AM):
  PR #3933: CI Status = PASSING ✅
  PR #3776: CI Status = PASSING ✅

Phase 2-3 (Time: 10:00-10:03 AM):
  - Analyzing review comments
  - Running code quality checks
  - Aggregating findings
  (Meanwhile: Flaky test starts failing, concurrent merge breaks CI)

Phase 4 (Time: 10:03 AM):
  Report shows:
    "PR #3933: No CI failures ✅"
    "PR #3776: No CI failures ✅"

Reality (Time: 10:03 AM):
  PR #3933: TestGetAssociatedMetric FAILING ❌
            Expected 2 inventory elements, got 0
  PR #3776: CI FAILING ❌

User applies wrong fixes based on stale data!
```

## The Solution

**MUST re-verify CI status in Phase 3 (Planning) before Phase 4 (User Interaction)**:

### Phase 1: Initial CI Check
```bash
# Batch fetch all PRs with initial CI status
gh pr list --author @me --state open --json number,title,statusCheckRollup

# Save initial CI state for each PR
for PR in ${SELECTED_PRS[@]}; do
  INITIAL_CI_STATE[$PR]=$(gh pr checks $PR --json conclusion | jq 'map(select(.conclusion == "failure")) | length')
done
```

### Phase 3: CI Re-verification (MANDATORY)
```bash
#!/bin/bash
echo "=== Phase 3: CI Re-verification (Gap #16 Prevention) ==="

for PR_NUM in ${SELECTED_PRS[@]}; do
  echo "[${PR_NUM}] Re-checking CI status..."

  # Fetch FRESH CI status
  CURRENT_CI=$(gh pr checks ${PR_NUM} --json name,status,conclusion)

  # Count current failures
  CURRENT_FAILURES=$(echo "$CURRENT_CI" | jq 'map(select(.conclusion == "failure")) | length')

  # Compare with Phase 1
  INITIAL_FAILURES=${INITIAL_CI_STATE[$PR_NUM]}

  if [ "$INITIAL_FAILURES" != "$CURRENT_FAILURES" ]; then
    echo "⚠️  CI STATUS CHANGED!"
    echo "   Phase 1: ${INITIAL_FAILURES} failures"
    echo "   Current: ${CURRENT_FAILURES} failures"

    # Save fresh CI data
    echo "$CURRENT_CI" > "/tmp/warden-pr-${PR_NUM}-ci-fresh.json"

    # Flag for Phase 4 reporting
    CI_CHANGED[$PR_NUM]=true
    CI_CHANGE_DELTA[$PR_NUM]=$((CURRENT_FAILURES - INITIAL_FAILURES))

    # Extract new failures
    if [ $CURRENT_FAILURES -gt $INITIAL_FAILURES ]; then
      echo "   ⚠️  NEW FAILURES DETECTED:"
      echo "$CURRENT_CI" | jq -r '.[] | select(.conclusion == "failure") | "      - \(.name)"'
    elif [ $CURRENT_FAILURES -lt $INITIAL_FAILURES ]; then
      echo "   ✅ Some failures resolved since Phase 1"
    fi
  else
    echo "   ✅ CI status unchanged (${CURRENT_FAILURES} failures)"
  fi
done

echo ""
echo "=== CI Re-verification Complete ==="

# BLOCKING CHECK: Verify fresh data exists
for PR_NUM in ${SELECTED_PRS[@]}; do
  if [ "${CI_CHANGED[$PR_NUM]}" = "true" ]; then
    if [ ! -f "/tmp/warden-pr-${PR_NUM}-ci-fresh.json" ]; then
      echo "❌ FATAL: Fresh CI data not saved for PR #${PR_NUM}"
      exit 1
    fi
  fi
done
```

### Phase 4: Report with CI Staleness Warnings
```bash
# Phase 4 report MUST include CI status changes

for PR_NUM in ${SELECTED_PRS[@]}; do
  echo "PR #${PR_NUM}: ${PR_TITLE}"
  echo ""

  # CI Status section (Gap #16 enforcement)
  if [ "${CI_CHANGED[$PR_NUM]}" = "true" ]; then
    DELTA=${CI_CHANGE_DELTA[$PR_NUM]}

    echo "⚠️  CI Status Changed (Gap #16 detection):"
    echo "├─ Phase 1: ${INITIAL_CI_STATE[$PR_NUM]} failures"
    echo "└─ Current:  $((INITIAL_CI_STATE[$PR_NUM] + DELTA)) failures (FRESH CHECK)"

    if [ $DELTA -gt 0 ]; then
      echo ""
      echo "   NEW FAILURES DETECTED:"
      jq -r '.[] | select(.conclusion == "failure") | "   - \(.name)"' \
        "/tmp/warden-pr-${PR_NUM}-ci-fresh.json"
    fi
    echo ""
  else
    echo "CI Status: Stable (${INITIAL_CI_STATE[$PR_NUM]} failures)"
    echo ""
  fi

  # Rest of report...
done
```

## Why This Matters

### Scenario 1: Flaky Tests
```
Phase 1: Test passing ✅
Phase 3: Test now failing ❌ (flaky test)
Phase 4: Report shows "No CI failures" (WRONG!)

With Gap #16 fix:
Phase 3: Detects test now failing
Phase 4: Report shows "NEW FAILURE: TestXYZ (flaky)"
```

### Scenario 2: Concurrent Merges
```
Phase 1: CI passing ✅
Phase 2: Another PR merges to main, breaks this PR's tests
Phase 3: CI now failing ❌ (merge conflict)
Phase 4: Report shows "No CI failures" (WRONG!)

With Gap #16 fix:
Phase 3: Detects CI now failing
Phase 4: Report shows "CI changed - concurrent merge may have broken tests"
```

### Scenario 3: Test Timeout Changes
```
Phase 1: Tests passing (barely within timeout) ✅
Phase 3: System load increased, tests now timeout ❌
Phase 4: Report shows "No CI failures" (WRONG!)

With Gap #16 fix:
Phase 3: Detects timeout failures
Phase 4: Report shows "NEW FAILURES: 3 tests timing out"
```

## Data Structure

### Phase 1: Initial CI State
```bash
# Saved in associative array
declare -A INITIAL_CI_STATE
INITIAL_CI_STATE[3933]=0  # PR #3933 had 0 failures
INITIAL_CI_STATE[3776]=0  # PR #3776 had 0 failures
```

### Phase 3: Fresh CI Data
```json
// /tmp/warden-pr-3933-ci-fresh.json
[
  {
    "name": "TestGetAssociatedMetric",
    "status": "completed",
    "conclusion": "failure",
    "detailsUrl": "https://github.com/.../actions/runs/123"
  },
  {
    "name": "TestTenantCleanup",
    "status": "completed",
    "conclusion": "success"
  }
]
```

### Phase 4: CI Change Tracking
```bash
declare -A CI_CHANGED
declare -A CI_CHANGE_DELTA

CI_CHANGED[3933]=true      # CI changed for PR #3933
CI_CHANGE_DELTA[3933]=1    # +1 new failure

CI_CHANGED[3776]=true      # CI changed for PR #3776
CI_CHANGE_DELTA[3776]=2    # +2 new failures
```

## Enforcement Rules

### Rule 1: MUST re-check CI in Phase 3
```bash
# BLOCKING CHECK
if [ -z "${INITIAL_CI_STATE[$PR_NUM]}" ]; then
  echo "❌ FATAL: Initial CI state not saved in Phase 1"
  exit 1
fi

# Re-fetch CI
CURRENT_CI=$(gh pr checks ${PR_NUM} --json name,status,conclusion)

# Cannot proceed without fresh check
if [ -z "$CURRENT_CI" ]; then
  echo "❌ FATAL: Failed to fetch fresh CI status"
  exit 1
fi
```

### Rule 2: MUST compare initial vs current
```bash
# Compare counts
INITIAL_FAILURES=${INITIAL_CI_STATE[$PR_NUM]}
CURRENT_FAILURES=$(echo "$CURRENT_CI" | jq 'map(select(.conclusion == "failure")) | length')

# Flag if different
if [ "$INITIAL_FAILURES" != "$CURRENT_FAILURES" ]; then
  CI_CHANGED[$PR_NUM]=true
fi
```

### Rule 3: MUST save fresh data if changed
```bash
if [ "${CI_CHANGED[$PR_NUM]}" = "true" ]; then
  echo "$CURRENT_CI" > "/tmp/warden-pr-${PR_NUM}-ci-fresh.json"

  # Verify save succeeded
  if [ ! -f "/tmp/warden-pr-${PR_NUM}-ci-fresh.json" ]; then
    echo "❌ FATAL: Failed to save fresh CI data"
    exit 1
  fi
fi
```

### Rule 4: MUST report CI changes in Phase 4
```bash
# Phase 4 report MUST show CI staleness warnings

if [ "${CI_CHANGED[$PR_NUM]}" = "true" ]; then
  echo "⚠️  CI Status Changed (Gap #16 detection):"
  echo "├─ Phase 1: ${INITIAL_CI_STATE[$PR_NUM]} failures"
  echo "└─ Current:  ${CURRENT_FAILURES} failures (FRESH CHECK)"
else
  echo "CI Status: Stable (${INITIAL_CI_STATE[$PR_NUM]} failures)"
fi
```

## Common Mistakes

### Mistake 1: Only checking CI once
```bash
# ❌ WRONG
Phase 1: gh pr checks 123
Phase 4: Use Phase 1 data (stale!)

# ✅ CORRECT
Phase 1: gh pr checks 123 → Save initial state
Phase 3: gh pr checks 123 → Re-verify, compare, flag changes
Phase 4: Use Phase 3 data (fresh!)
```

### Mistake 2: Not comparing initial vs current
```bash
# ❌ WRONG
Phase 3: gh pr checks 123 → Use new data
         (Don't notice it changed!)

# ✅ CORRECT
Phase 3: gh pr checks 123 → Compare with Phase 1
         → Flag if different
         → Report change to user
```

### Mistake 3: Not flagging staleness in report
```bash
# ❌ WRONG
Phase 4: "CI Status: 2 failures"
         (User doesn't know this is new!)

# ✅ CORRECT
Phase 4: "⚠️  CI Status Changed:
          Phase 1: 0 failures
          Current: 2 failures (FRESH CHECK)
          NEW FAILURES DETECTED"
```

### Mistake 4: Assuming CI is deterministic
```bash
# ❌ DANGEROUS ASSUMPTION
# "CI was passing in Phase 1, so it's still passing"

# ✅ REALITY
# CI can change due to:
# - Flaky tests
# - Concurrent merges
# - System load (timeouts)
# - External dependencies (API rate limits)
# - Time-based tests (date/time sensitive)
```

## Real Example: PR #3933 and PR #3776

**What happened without Gap #16 fix**:
```
Phase 1 (10:00 AM):
  PR #3933: gh pr checks 3933
  Result: 0 failures ✅

  PR #3776: gh pr checks 3776
  Result: 0 failures ✅

Phase 2-3 (10:00-10:03 AM):
  - Analyzing review comments
  - Running code quality checks
  (CI changes during this time)

Phase 4 (10:03 AM):
  Report:
    PR #3933: No CI failures found ✅
    PR #3776: No CI failures found ✅

  Recommendation: Focus on review comments and code quality

  (WRONG! Both PRs now have failing CI)
```

**What happens WITH Gap #16 fix**:
```
Phase 1 (10:00 AM):
  INITIAL_CI_STATE[3933]=0
  INITIAL_CI_STATE[3776]=0

Phase 3 (10:03 AM):
  Re-check CI:

  PR #3933:
    Current failures: 1
    ⚠️  CI STATUS CHANGED!
    Phase 1: 0 failures
    Current: 1 failure
    NEW FAILURE: TestGetAssociatedMetric
      - Expected 2 inventory elements, got 0
      - File: pkg/graph/coreapi/inventory_binding.resolvers_test.go:123

  PR #3776:
    Current failures: 1
    ⚠️  CI STATUS CHANGED!
    Phase 1: 0 failures
    Current: 1 failure
    NEW FAILURE: (need to investigate)

Phase 4 (10:03 AM):
  Report:
    PR #3933:
      ⚠️  CI Status Changed (Gap #16 detection):
      ├─ Phase 1: 0 failures (passing)
      └─ Current:  1 failure (FRESH CHECK)
          - TestGetAssociatedMetric: Expected 2 elements, got 0

      Critical (1):
        [CI] TestGetAssociatedMetric failure (FRESH)

      This is a real bug that needs fixing!

    PR #3776:
      ⚠️  CI Status Changed (Gap #16 detection):
      ├─ Phase 1: 0 failures (passing)
      └─ Current:  1 failure (FRESH CHECK)

      Need to investigate new failure

  Recommendation: Fix CI failures first (they're new!)
```

## Integration with Other Phases

### Phase 1: Save Initial State
```bash
# Phase 1 MUST save initial CI state for Phase 3 comparison
for PR in ${SELECTED_PRS[@]}; do
  INITIAL_CI_STATE[$PR]=$(gh pr checks $PR --json conclusion | \
    jq 'map(select(.conclusion == "failure")) | length')
done

# Export for Phase 3
export INITIAL_CI_STATE
```

### Phase 3: Re-verify and Compare
```bash
# Phase 3 MUST re-check and compare
source phase1_exports.sh  # Import INITIAL_CI_STATE

for PR in ${SELECTED_PRS[@]}; do
  # Re-fetch
  CURRENT_CI=$(gh pr checks $PR --json name,status,conclusion)

  # Compare
  CURRENT_FAILURES=$(echo "$CURRENT_CI" | jq 'map(select(.conclusion == "failure")) | length')
  INITIAL_FAILURES=${INITIAL_CI_STATE[$PR]}

  # Flag changes
  [ "$INITIAL_FAILURES" != "$CURRENT_FAILURES" ] && CI_CHANGED[$PR]=true
done
```

### Phase 4: Report Changes
```bash
# Phase 4 MUST show CI staleness warnings
if [ "${CI_CHANGED[$PR]}" = "true" ]; then
  echo "⚠️  CI Status Changed (Gap #16 detection):"
fi
```

## Testing the Fix

```bash
# Simulate Gap #16 scenario
PR_NUM=3933

# Phase 1: Initial check
INITIAL=$(gh pr checks $PR_NUM --json conclusion | jq 'map(select(.conclusion == "failure")) | length')
echo "Phase 1: $INITIAL failures"

# Simulate time passing (wait for CI to change)
sleep 180  # 3 minutes

# Phase 3: Re-check
CURRENT=$(gh pr checks $PR_NUM --json conclusion | jq 'map(select(.conclusion == "failure")) | length')
echo "Phase 3: $CURRENT failures"

# Detect change
if [ "$INITIAL" != "$CURRENT" ]; then
  echo "✅ Gap #16 prevention: CI change detected!"
  echo "   Initial: $INITIAL failures"
  echo "   Current: $CURRENT failures"
  echo "   Delta: $((CURRENT - INITIAL))"
else
  echo "ℹ️  CI status stable"
fi
```

## See Also

- [WORKFLOW.md](WORKFLOW.md) - Phase 3 CI re-verification details
- [AGENTS.md](AGENTS.md) - Phase integration requirements
- GitHub CI docs: https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows
