# Workflow

**TL;DR**: Discover validation commands (MANDATORY) → Analyze existing PRs → Identify issues → Fix by tier → Validate → Push → Cleanup

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

**Batch fetch existing open PRs:**
```bash
gh pr list --author @me --state open --json number,title,statusCheckRollup,reviews,updatedAt
```

**Scope Selection:**
- If ≤10 PRs: Analyze all
- If >10 PRs: Select top 10 by priority and INFORM user:
  ```
  Found 14 open PRs. Analyzing top 10 by priority:
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

**CRITICAL**: Analyze **ALL sources** for **EVERY PR**, regardless of CI status.

For each PR, launch parallel subagents:

**Subagent A - CI Failures**: Test failures, build errors, lint issues
- Even if CI is green, check for warnings or flaky tests

**Subagent B - Review Comments** (ALL comments, including bots):
- Human reviews (requested changes, suggestions, questions)
- **Bot/AI reviews** (GitHub Copilot, code analysis bots, security scanners)
- Parse for actionable items: "should", "must", "concern", "todo", "recommend"
- Don't skip green-CI PRs - they may have unresolved review feedback

**Subagent C-E - Code Quality**: Security, performance, architecture issues
- Independent of CI and review status

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

Aggregate findings, deduplicate, sort by severity (Critical → High → Medium → Low)

## Phase 4: User Interaction

Present report combining all sources (CI + Review + Code + Ticket), ask what to fix:
```
PR #123: Fix authentication

Ticket Alignment (PROJ-456):
├─ ✅ Core auth implemented (matches ticket)
├─ ⚠️ Missing: Password reset link (acceptance criteria)
└─ 🚨 Scope divergence: Analytics code (not in ticket)

Critical (2):
  [CI] SQL injection in login endpoint
  [Review] Missing auth check per @reviewer

High (3):
  [CI] Test failure: race condition in session handler
  [Review] Unvalidated user input per @security-team
  [Code] Missing error handling in payment flow

Recommendation:
- Split PR: Core auth (matches PROJ-456) + Analytics (new ticket)

Fix: 1) All Critical+High  2) Critical only  3) Skip
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
       c. Validate: $BUILD_CMD → $LINT_CMD → $FORMAT_CMD → $TEST_CMD
       d. If pass: Commit → Push
       e. If fail: Rollback, skip tier
  5. Cleanup workspace
  6. Next PR
```

**Workspace modes**:
- **Isolated (default)**: Temp workspace in `/tmp/warden-repos/` - safe, parallel-capable
- **In-place**: Run in current repo - slower, for complex setup (use `--in-place`)

See [CONFIGURATION.md](CONFIGURATION.md) for workspace configuration details.

**Validation sequence** (MUST source artifact first):
```bash
# MANDATORY: Source validation commands from Phase 0 artifact
source "$WORKSPACE/.warden-validation-commands.sh"

# Execute discovered commands
$BUILD_CMD  || { rollback; exit 1; }
$LINT_CMD   || { rollback; exit 1; }
$FORMAT_CMD  # auto-fix, ignore errors
$TEST_CMD   || { rollback; exit 1; }

# PRE-COMMIT VERIFICATION (MANDATORY)
git add .
git status --short  # Show what will be committed

# Check for unintended files
UNINTENDED=$(git diff --cached --name-only | grep -E '(_debug\.|test_debug\.|debug_.*\.|\.debug$)')
if [ -n "$UNINTENDED" ]; then
  echo "❌ ERROR: Unintended files detected"
  git reset --hard HEAD
  exit 1
fi

# Only commit/push if verification passed
git commit -m "Fix: ${TIER}"
git push origin $(git branch --show-current)
```

**Enforcement**: Phase 5 CANNOT proceed without Phase 0 artifact. See [PHASE-0-DISCOVERY.md](PHASE-0-DISCOVERY.md).

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
