# Workflow

**TL;DR**: Discover validation commands (MANDATORY) → Analyze existing PRs → Identify issues → Fix by tier → Validate → Push → Cleanup

## Why Warden Exists

**The Problem**: Local AI agents (Claude Code, Copilot, Cursor) often miss issues that CI catches, leading to failed PRs and review churn.

**Real Example**: PR #3797 in aha-smt repo
- **What happened**: Claude Code wrote code locally, tests passed locally, pushed to PR
- **Result**: CI immediately failed - tests that passed locally failed in CI
- **Root cause**: Agent skipped the validation protocol and didn't check review comments

**Why this happens**:
1. **No filtering**: Agents analyze all PRs, not just the user's
2. **Wrong priorities**: Agents treat code quality equally with human reviews and CI failures
3. **Skip review comments**: Agents ignore detailed feedback in PR review threads
4. **Skip validation**: Agents push without running build → lint → format → tests
5. **No approval gate**: Agents proceed without user confirmation

**Warden's Solution**:
- ✅ **User filtering**: Only analyze PRs created by current user (Phase 1)
- ✅ **Priority enforcement**: Human reviews (PRIMARY) > CI failures (SECONDARY) > Code quality (TERTIARY) (Phase 2)
- ✅ **Review comment fetching**: Fetch BOTH review summaries AND comment threads (Phase 2)
- ✅ **Bot filtering**: Ignore automated bot comments (Phase 2)
- ✅ **Validation protocol**: Build → Lint → Format → Tests (100% pass required) before ANY push (Phase 5)
- ✅ **User approval**: Present report, wait for confirmation (Phase 4)

**Result**: Every PR is review-ready, reducing review churn and catching issues before human review.

## Phase 0: Command Discovery (MANDATORY)

**⚠️ CRITICAL**: This phase MUST complete before Phase 1. Phase 5 is BLOCKED without this.

**Purpose**: Discover and save validation commands to artifact that Phase 5 will use.

**Artifact**: `$WORKSPACE/.warden-validation-commands.sh`

**Steps**:
1. Create workspace: `/tmp/warden-repos/session-$(date +%s)`
2. Clone target repository
3. Discover commands from:
   - AI instruction files (CLAUDE.md, .cursorrules, etc.)
   - CI configs (.github/workflows/*.yml)
   - Language configs (Makefile, package.json, etc.)
   - Language defaults (fallback)
4. Save to artifact: `.warden-validation-commands.sh`
5. Verify artifact created (BLOCKING)

**Example discovery**:
```bash
# Priority 1: AI instructions
BUILD_CMD=$(grep "Build:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')
LINT_CMD=$(grep "Lint:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')
FORMAT_CMD=$(grep "Format:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')
TEST_CMD=$(grep "Test:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')

# Save to artifact
cat > .warden-validation-commands.sh <<EOF
export BUILD_CMD='$BUILD_CMD'
export LINT_CMD='$LINT_CMD'
export FORMAT_CMD='$FORMAT_CMD'
export TEST_CMD='$TEST_CMD'
EOF

chmod +x .warden-validation-commands.sh
```

**Verification** (BLOCKING):
```bash
if [ ! -f ".warden-validation-commands.sh" ]; then
  echo "❌ FATAL: Phase 0 failed - cannot proceed"
  exit 1
fi
```

See [PHASE-0-DISCOVERY.md](PHASE-0-DISCOVERY.md) for complete specification.

## Phase 1: PR Discovery

**Explicit user filtering** (prevents analyzing other users' PRs):
```bash
# Get current GitHub user
GITHUB_USER=$(gh api user --jq '.login')

# Fetch ONLY user's PRs (--author ensures we only see PRs created by current user)
gh pr list --author "$GITHUB_USER" --state open --json number,title,statusCheckRollup,reviews,updatedAt
```

**Why explicit filtering**:
- Prevents analyzing team members' PRs
- Focuses on work user owns
- Reduces noise and analysis time
- Matches expected behavior: "review MY PRs"

**Recent activity filter** (optional):
```bash
# Only PRs updated in last 2 days (reduces stale PR noise)
CUTOFF_DATE=$(date -u -d '2 days ago' '+%Y-%m-%dT%H:%M:%SZ')
gh pr list --author "$GITHUB_USER" --state open --json number,title,statusCheckRollup,reviews,updatedAt \
  | jq --arg cutoff "$CUTOFF_DATE" '[.[] | select(.updatedAt >= $cutoff)]'
```

**Scope Selection:**
- If ≤10 PRs: Analyze all
- If >10 PRs: Select top 10 by priority and INFORM user:
  ```
  Found 14 open PRs by @yourname. Analyzing top 10 by priority:
  - 3 with failing CI
  - 4 with review comments
  - 3 most recent

  Say "analyze all 14" to override, or "analyze PR #123, #125" for specific PRs.
  ```

**Priority Order:**
1. Failing CI (statusCheckRollup = FAILURE)
2. Has unresolved review comments
3. Most recently updated

**User can override with natural language:**
- "Analyze all my PRs" → Removes limit
- "Only analyze PR #123" → Specific PR
- "Analyze PRs #123, #125, #127" → Multiple specific PRs
- "Analyze last 5 PRs" → Custom limit

## Phase 2: Analysis (Parallel)

**⭐ PRIORITY ENFORCEMENT** - Analyze in this order:

### Priority 1: Human Review Comments (PRIMARY SOURCE)
**Why first**: Human reviewers have already looked at the code and identified real issues
- **Subagent B** - Review comments (CRITICAL: Fetch BOTH endpoints)
- These are KNOWN issues that MUST be fixed
- Takes precedence over automated checks

### Priority 2: CI Failures (SECONDARY SOURCE)
**Why second**: CI caught issues in automated testing environment
- **Subagent A** - CI failures
- Represents issues that will block merge
- More reliable than static analysis

### Priority 3: Code Quality Issues (TERTIARY SOURCE)
**Why third**: These are potential improvements, not blocking issues
- **Subagents C-E** - Code quality (security, performance, architecture)
- Independent analysis, may overlap with human reviews
- Use to catch issues humans missed

**Why this order matters**:
- Human reviewers > Automated CI > Static analysis
- Fixes human feedback first (reduces review churn)
- Respects reviewer time (they already invested effort)
- Prevents fixing low-priority issues while ignoring reviewer requests

---

### Subagent A - CI Failures (SECONDARY)
Test failures, build errors, lint issues
- Even if CI is green, check for warnings or flaky tests

### Subagent B - Review Comments (PRIMARY ⭐)

**MANDATORY: Fetch review summaries AND comment threads**:
1. **Review summaries**: `gh pr view ${PR} --json reviews`
   - Overall state: APPROVED, CHANGES_REQUESTED, COMMENTED
   - Who reviewed and when
2. **Review comment threads**: `gh api /repos/${OWNER}/${REPO}/pulls/${PR}/comments`
   - **THIS IS WHERE DETAILED FEEDBACK LIVES**
   - File-specific comments with line numbers
   - Actual bug reports and issues to fix
   - Thread replies and resolution status

**Bot filtering** (MUST exclude automated bot comments):
```bash
# Filter out bot comments - they're automated, not human review
BOT_USERS=(
  "copilot-pull-request-reviewer"
  "blacksmith-sh"
  "dependabot"
  "dependabot[bot]"
  "github-actions[bot]"
)

# Extract only human comments
HUMAN_COMMENTS=$(jq --argjson bots "$(printf '%s\n' "${BOT_USERS[@]}" | jq -R . | jq -s .)" \
  'map(select(.user.login as $user | $bots | index($user) | not))' \
  /tmp/review-comments.json)
```

**Why filter bots**:
- Bot comments are automated suggestions, not human review feedback
- Human review takes priority (PRIMARY source)
- Reduces noise in analysis
- Focuses on what humans care about

**Parse for** (human comments only):
- **First**: Filter out resolved threads (`resolved: true`) - already addressed
- **Second**: Filter out bot comments (see bot list above)
- Human reviews (requested changes, suggestions, questions)
- Actionable items: "should", "must", "concern", "todo", "recommend", "bug", "leak"
- Unresolved comment threads

**Gap #15**: Only fetching review summaries misses critical feedback like "Line 123: This loop causes data leaks"

See [REVIEW-COMMENTS.md](REVIEW-COMMENTS.md) for complete enforcement details.

### Subagents C-E - Code Quality (TERTIARY)
Security, performance, architecture issues
- Independent of CI and review status
- May find issues humans missed

**Subagent F - Ticket Alignment** (if ticket integration enabled):
- Extract ticket IDs from PR title/body/branch
- Fetch ticket details via MCP or API (JIRA, Aha, Linear, GitHub Issues)
- Compare PR changes to ticket requirements
- Report alignment or divergence (scope creep, missing requirements)
- See [TICKET-INTEGRATION.md](TICKET-INTEGRATION.md) for configuration

**Context gathered**:
1. PR description → Understand intent
2. Repo AI instructions (CLAUDE.md, etc.) → Conventions + **build/test commands**
3. Codebase overview → Architecture

**Command discovery**:
```bash
# Extract from CLAUDE.md
BUILD_CMD=$(grep "Build:" CLAUDE.md | grep '`' | tr -d '`')
TEST_CMD=$(grep "Test:" CLAUDE.md | grep '`' | tr -d '`')

# Fallback to CI configs, Makefile, package.json
# See COMMANDS.md for details
```

## Phase 3: Planning

**Step 1: CI Re-verification (MANDATORY - Gap #16 fix)**

**⚠️ CRITICAL**: CI status can change between Phase 1 and Phase 4. MUST re-check before presenting report.

```bash
echo "=== Re-verifying CI Status (Gap #16 Prevention) ==="

for PR_NUM in ${SELECTED_PRS[@]}; do
  # Fetch fresh CI status
  CURRENT_CI=$(gh pr checks ${PR_NUM} --json name,status,conclusion)

  # Compare with Phase 1 status
  INITIAL_CI_STATE=${PR_CI_STATE[$PR_NUM]}  # Saved from Phase 1
  CURRENT_CI_STATE=$(echo "$CURRENT_CI" | jq -r 'map(select(.conclusion == "failure")) | length')

  if [ "$INITIAL_CI_STATE" != "$CURRENT_CI_STATE" ]; then
    echo "⚠️  PR #${PR_NUM}: CI status changed!"
    echo "   Phase 1: ${INITIAL_CI_STATE} failures"
    echo "   Current: ${CURRENT_CI_STATE} failures"

    # Flag for reporting
    CI_CHANGED[$PR_NUM]=true

    # Re-fetch CI details if status changed
    gh pr checks ${PR_NUM} > "/tmp/warden-pr-${PR_NUM}-ci-fresh.json"
  fi
done
```

**Why this matters**:
- Flaky tests can start failing after Phase 1
- Concurrent merges can break CI
- Presenting stale CI data leads to wrong fix recommendations

**Enforcement**: Phase 4 report MUST include fresh CI data and flag changed statuses.

**Step 1.5: Merge Conflict Detection**

Detect merge conflicts when checking out PR branches. If conflicts found, save details for Phase 4 reporting.

**Resolution options presented to user**:
- Auto-resolve: AI attempts resolution (dependencies, formatting)
- Interactive: Agent guides through each conflict
- Skip: Continue with other fixes, user handles manually

See [MERGE-CONFLICT-HANDLING.md](MERGE-CONFLICT-HANDLING.md) for complete details.

**Step 2: Aggregate Findings**

Aggregate findings from Phase 2, deduplicate, sort by severity (Critical → High → Medium → Low)

## Phase 4: User Interaction

**"Already Responded" Detection** (prevents re-surfacing resolved issues):

```bash
# Detect if user already responded to review comments
# A comment thread with user replies is lower priority than unresolved threads

AUTHOR=$(gh pr view ${PR_NUMBER} --json author -q .author.login)

# For each review comment, check if author replied
for comment_id in $(jq -r '.[].id' /tmp/review-comments.json); do
  # Check if any reply has in_reply_to_id = comment_id AND user = author
  HAS_RESPONSE=$(jq --arg id "$comment_id" --arg author "$AUTHOR" \
    'map(select(.in_reply_to_id == ($id | tonumber) and .user.login == $author)) | length > 0' \
    /tmp/review-comments.json)

  if [ "$HAS_RESPONSE" = "true" ]; then
    # User already responded - lower priority
    echo "  💬 Responded: Comment $comment_id"
  else
    # No response yet - high priority
    echo "  ⚠️  Unresolved: Comment $comment_id"
  fi
done
```

**Status indicators**:
- **⚠️ Unresolved**: No response from PR author (HIGH PRIORITY)
- **💬 Responded**: PR author replied but not marked resolved (MEDIUM PRIORITY)
- **✅ Resolved**: Thread marked resolved (SKIP - already addressed)

---

**Report Format** (with priority structure):

Present report combining all sources (CI + Review + Code + Ticket + Conflicts) with CLEAR priority structure (PRIMARY > SECONDARY > TERTIARY):
```
PR #123: Fix authentication

⚠️  MERGE CONFLICTS (2 files):
├─ src/auth/login.ts (lines 45-52)
│  - Conflict: OAuth2 vs JWT implementation
└─ package.json (lines 15-18)
   - Conflict: express@4.18.2 vs express@4.19.0

Conflict resolution options:
1. Auto-resolve: AI attempts resolution
2. Interactive: Guide me through each conflict
3. Skip: I'll handle manually (continue with other fixes)

⚠️  CI Status Changed (Gap #16 detection):
├─ Phase 1: 0 failures (passing)
└─ Current:  2 failures (FRESH CHECK)
    - TestAuthHandler: Expected 2 elements, got 0
    - TestSessionCleanup: Race condition detected

Ticket Alignment (PROJ-456):
├─ ✅ Core auth implemented (matches ticket)
├─ ⚠️ Missing: Password reset link (acceptance criteria)
└─ 🚨 Scope divergence: Analytics code (not in ticket)

═══════════════════════════════════════════════════════════════
🔴 PRIORITY 1: Unresolved Human Review Comments (PRIMARY)
═══════════════════════════════════════════════════════════════
  1. ⚠️  [CRITICAL] Missing auth check in login.go:45 (@reviewer)
     "This endpoint bypasses authentication - security issue"
     Status: UNRESOLVED (no response from author)

  2. ⚠️  [HIGH] Unvalidated user input in handler.go:23 (@security-team)
     "Need input sanitization to prevent XSS"
     Status: UNRESOLVED (no response from author)

  3. 💬 [MEDIUM] Error handling improvement in auth.go:67 (@reviewer)
     "Should return specific error codes"
     Status: RESPONDED (author replied: "Will fix in next commit")

═══════════════════════════════════════════════════════════════
🟡 PRIORITY 2: CI Issues (SECONDARY)
═══════════════════════════════════════════════════════════════
  4. [CRITICAL] TestAuthHandler (FRESH) - Expected 2 elements, got 0
  5. [HIGH] TestSessionCleanup (FRESH) - Race condition in session handler

═══════════════════════════════════════════════════════════════
🟢 PRIORITY 3: Additional Code Quality Issues (TERTIARY)
═══════════════════════════════════════════════════════════════
  6. [HIGH] Missing error handling in payment flow (security review)
  7. [MEDIUM] Performance: N+1 query in user lookup (performance review)

Recommendation:
- Resolve conflicts first (blocks merge)
- FIX PRIORITY 1 FIRST: Human reviewers waiting on these fixes
- Then Priority 2 (CI) to unblock merge
- Finally Priority 3 (code quality) if time permits
- Split PR: Core auth (matches PROJ-456) + Analytics (new ticket)

Fix: 1) All priorities  2) Priority 1+2 only  3) Priority 1 only  4) Skip
Conflicts: 1) Auto-resolve  2) Interactive  3) Skip
```

## Phase 5: Execution

**⚠️ MANDATORY PRE-CHECK**: Verify Phase 0 artifact exists before ANY fixes:

```bash
# BLOCKING CHECK
ARTIFACT="$WORKSPACE/.warden-validation-commands.sh"

if [ ! -f "$ARTIFACT" ]; then
  echo "❌ FATAL: Phase 0 not completed!"
  echo "Required: $ARTIFACT"
  exit 1
fi

# Load validation commands
source "$ARTIFACT"
```

**Per-PR loop**:

```
FOR EACH PR:

  0. VERIFY Phase 0 artifact exists (BLOCKING)
  1. Create temp workspace: /tmp/warden-repos/pr-${PR_NUMBER}-${TIMESTAMP}/
  2. Clone repo, checkout PR branch
  3. Copy validation artifact to workspace
  4. FOR EACH TIER (Critical → High → Medium → Low):
       a. Apply fixes
       b. Source artifact: source .warden-validation-commands.sh
       c. Validate (ABSOLUTE BLOCKING - Gap #16 fix):
          - Build → Lint → Format → Tests
          - ALL must pass (tests = 100% pass rate)
          - set -euo pipefail (no bypassing)
       d. If pass: Commit → Push
       e. If fail: BLOCK, Rollback, skip tier (NO partial pushes)
  5. Cleanup workspace
  6. Next PR
```

**Workspace modes**:
- **Isolated (default)**: Temp workspace in `/tmp/warden-repos/` - safe, parallel-capable
- **In-place**: Run in current repo - slower, for complex setup (use `--in-place`)

See [CONFIGURATION.md](CONFIGURATION.md) for workspace configuration details.

**Validation sequence** (ABSOLUTE BLOCKING - Gap #16 fix):
```bash
#!/bin/bash
set -euo pipefail  # Exit on ANY error - no bypassing

echo "=== Phase 5: Pre-Push Validation (ABSOLUTE BLOCKING) ==="
echo ""
echo "HARD RULE: Tests must pass 100% before ANY push"
echo ""

# MANDATORY: Source validation commands from Phase 0 artifact
source "$WORKSPACE/.warden-validation-commands.sh"

# Track validation failures
VALIDATION_FAILED=false

# 1. BUILD (BLOCKING)
echo "[1/4] Running build..."
if ! eval "$BUILD_CMD"; then
  echo "❌ BUILD FAILED - CANNOT PUSH"
  VALIDATION_FAILED=true
else
  echo "✅ Build passed"
fi

# 2. LINT (BLOCKING)
echo "[2/4] Running lint..."
if ! eval "$LINT_CMD"; then
  echo "❌ LINT FAILED - CANNOT PUSH"
  VALIDATION_FAILED=true
else
  echo "✅ Lint passed"
fi

# 3. FORMAT (AUTO-FIX)
echo "[3/4] Running format..."
eval "$FORMAT_CMD" || true

# 4. TESTS (ABSOLUTE BLOCKING)
echo "[4/4] Running tests..."
if ! eval "$TEST_CMD"; then
  echo ""
  echo "❌❌❌ TESTS FAILED ❌❌❌"
  echo ""
  echo "DIAGNOSTIC PUSH BLOCKED (Gap #16 enforcement)"
  echo "Cannot push code with failing tests"
  echo ""
  echo "This prevents pushing partial fixes while debugging"
  echo "Tests must pass 100% before ANY push"
  echo ""
  VALIDATION_FAILED=true
else
  echo "✅ Tests passed"
fi

# ABSOLUTE BLOCKING CHECK
if [ "$VALIDATION_FAILED" = true ]; then
  echo ""
  echo "=========================================="
  echo "  VALIDATION FAILED - CANNOT PUSH"
  echo "=========================================="
  echo ""
  git reset --hard HEAD  # Rollback
  echo "Changes rolled back"
  echo ""
  echo "Fix the failures and try again"
  echo "See docs/DIAGNOSTIC-PUSH-PREVENTION.md"
  echo ""
  exit 1
fi

# PRE-COMMIT VERIFICATION (MANDATORY)
git add .
git status --short

# Check for unintended files
UNINTENDED=$(git diff --cached --name-only | grep -E '(_debug\.|test_debug\.|debug_.*\.|\.debug$)' || true)
if [ -n "$UNINTENDED" ]; then
  echo "❌ ERROR: Unintended debug files detected"
  echo "$UNINTENDED"
  git reset --hard HEAD
  exit 1
fi

# Only commit/push if ALL validations passed
echo ""
echo "✅ ALL VALIDATIONS PASSED - Safe to push"
git commit -m "Fix: ${TIER}"
git push origin $(git branch --show-current)
```

**Enforcement**:
- Phase 5 CANNOT proceed without Phase 0 artifact (Gap #13 fix)
- Phase 5 CANNOT push with failing tests (Gap #16 fix - Diagnostic Push Prevention)
- Uses `set -euo pipefail` to make bypassing impossible
- ABSOLUTE BLOCKING - no exceptions without explicit user override

See [PHASE-0-DISCOVERY.md](PHASE-0-DISCOVERY.md) and [DIAGNOSTIC-PUSH-PREVENTION.md](DIAGNOSTIC-PUSH-PREVENTION.md).

**Workspace isolation**:
- Each PR: Own temp directory
- User's working directory: Never touched
- Immediate cleanup after each PR

## Phase 6: Summary

```
Total PRs: 5 | Fixed: 3 | Skipped: 2
Issues Fixed: Critical(4), High(7), Medium(3)
CI Status: PR#123 ✓, PR#125 ✓, PR#127 pending
```

## Key Points

- Works on **existing PRs** (not creating new ones)
- Discovers commands from repo docs (not hard-coded)
- Validates **before** pushing (prevents CI failures)
- Isolated workspaces (never touches your working dir)
- Sequential PR processing (one at a time)

See also: [VALIDATION-ORDER.md](VALIDATION-ORDER.md), [COMMANDS.md](COMMANDS.md)
