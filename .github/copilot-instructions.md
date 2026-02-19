# GitHub Copilot Instructions for Warden

## About Warden

Warden v1.2: Cross-platform AI skill for automated PR review and fixes.

**New in v1.2**: Contextual review, streamlined configuration (25 core parameters + config files), 5 specialized reviewers, flexible test strategies, PR integration.

**Execution Mode**: Warden executes actual commands and checks exit codes (see AGENTS.md).

Analyzes three issue sources (CI failures, review comments, code quality).

## How to Invoke

User must explicitly reference "Warden" for GitHub Copilot to use this skill.

**In Copilot Chat (VSCode/IDE)**:
```
"Run the Warden skill"
"Execute Warden on my open PRs"
"Use Warden to analyze PR #123"
```

**Too ambiguous** (Copilot won't know to use Warden):
```
"Review my PRs"  ← Generic, won't use this skill
```

**How it works**:
- Have Warden repository in your workspace
- Copilot automatically reads this `.github/copilot-instructions.md` file
- Say "Run Warden" in Copilot Chat
- Copilot follows the workflow documented here

## Cleanup Operations

User requests: "Clean up Warden workspaces", "Clear Warden data", "Remove Warden temp files"

Execute cleanup:
```bash
WORKSPACE_ROOT=$(grep -A5 "^workspace:" ~/.warden/config.yml 2>/dev/null | grep "root:" | awk '{print $2}' || echo "/tmp/warden-repos")
du -sh "$WORKSPACE_ROOT" 2>/dev/null && rm -rf "$WORKSPACE_ROOT" && echo "Cleaned up Warden workspaces"
```

Deletes: Temp PR workspaces. Preserves: Config files, working directory. See [CONFIGURATION.md](docs/CONFIGURATION.md).

**Installation (Current Workarounds - 2026-02)**:

Ideal (when Copilot skills system is stable):
```bash
gh copilot skill add https://github.com/abishop1990/warden
```

Current workarounds:
```bash
# Option 1: Copy to project
cp ~/warden/AGENTS.md /path/to/project/.github/
cp -r ~/warden/docs /path/to/project/docs/

# Option 2: Keep Warden in workspace (add as workspace folder)

# Update: cd ~/warden && git pull
```

### Key Parameters (25 core + 19 advanced - see PARAMETERS.md)
- `--author <username>` - Review PRs by specific author
- `--repo <owner/repo>` - Target specific repository
- `--reviewers security,performance,architecture` - Custom reviewers
- `--test-strategy none|affected|full|smart` - Test approach
- `--fix-strategy conservative|balanced|aggressive` - Fix aggressiveness
- `--comment-on-pr` - Post findings to PR (opt-in, disabled by default)
- `--dry-run` - Preview without fixing

See [PARAMETERS.md](../docs/PARAMETERS.md) for complete parameter reference.

## Workflow

**CRITICAL**: This skill works with **Pull Requests (PRs)**, NOT branches!

1. **Discovery** - Batch `gh pr list --json` (auto-select top 10 by priority if >10 found)
2. **Analysis** - Parallel analysis of all PRs (CI, reviews, code quality)
3. **Validation** - Verify branch integrity, detect corruption/architectural issues
4. **Planning** - Aggregate, deduplicate, prioritize, flag escalations
5. **User Interaction** - **MANDATORY: Report with metadata, ask approval, WAIT**
6. **Execution** - Fix or escalate (architectural issues flagged for user)
7. **Summary** - Report metrics

See [docs/WORKFLOW.md](../docs/WORKFLOW.md) for complete workflow details.

## Phase 3: Planning (CI Re-verification MANDATORY)

**⚠️ CRITICAL (Gap #16 fix)**: CI status can change between Phase 1 and Phase 4. MUST re-verify before presenting report.

**Step 1: CI Re-verification** (BLOCKING):
```bash
echo "=== Phase 3: CI Re-verification (Gap #16 Prevention) ==="

# For each PR, re-fetch CI and compare with Phase 1
for PR_NUM in ${SELECTED_PRS[@]}; do
  # Fetch FRESH CI status
  CURRENT_CI=$(gh pr checks ${PR_NUM} --json name,status,conclusion)
  CURRENT_FAILURES=$(echo "$CURRENT_CI" | jq 'map(select(.conclusion == "failure")) | length')

  # Compare with Phase 1 initial state
  INITIAL_FAILURES=${INITIAL_CI_STATE[$PR_NUM]}

  if [ "$INITIAL_FAILURES" != "$CURRENT_FAILURES" ]; then
    echo "⚠️  PR #${PR_NUM}: CI STATUS CHANGED!"
    echo "   Phase 1: ${INITIAL_FAILURES} failures"
    echo "   Current: ${CURRENT_FAILURES} failures"

    # Flag for Phase 4 reporting
    CI_CHANGED[$PR_NUM]=true

    # Save fresh CI data
    echo "$CURRENT_CI" > "/tmp/warden-pr-${PR_NUM}-ci-fresh.json"

    # Extract new failures
    if [ $CURRENT_FAILURES -gt $INITIAL_FAILURES ]; then
      echo "   ⚠️  NEW FAILURES DETECTED:"
      echo "$CURRENT_CI" | jq -r '.[] | select(.conclusion == "failure") | "      - \(.name)"'
    fi
  fi
done
```

**Why this matters**:
- Flaky tests can start failing after Phase 1
- Concurrent merges can break CI
- Presenting stale CI data leads to wrong fix recommendations

**Step 2: Aggregate Findings**:
- Deduplicate issues across sources
- Sort by severity (Critical → High → Medium → Low)
- Flag escalations (architectural issues, >100 LOC changes)

See [docs/CI-REVERIFICATION.md](../docs/CI-REVERIFICATION.md) for complete details.

## Phase 4: User Interaction (MANDATORY)

**CRITICAL**: Before executing ANY fixes, you MUST consolidate findings, present comprehensive report, ask for approval, and WAIT for user response.

**See**: AGENTS.md Phase 4 for complete requirements including report format, approval options, and wait protocol.

**Defaults**: Standard review, Affected tests, Balanced fixes. **Batching**: Max 5 PRs per batch. See AGENTS.md for details.

## GitHub Copilot Specific Optimizations

### ⚠️ Critical: Agent Tool Limitations

**GitHub Copilot specialized agents do NOT have access to:**
- `gh` CLI
- GitHub API
- External commands (only local filesystem tools: grep, glob, read)

**This breaks the standard Warden Phase 2 design that assumes subagents can call `gh pr view`, `gh pr checks`, etc.**

**REQUIRED WORKAROUND for Copilot:**

1. **Main agent pre-fetches ALL PR data** using `gh` CLI (Phase 1)
2. **Save PR data to local temp files** for subagents to analyze
3. **Launch subagents with file paths** instead of PR numbers
4. **Subagents read local JSON/diff files** instead of calling GitHub API

**Example Phase 1 data collection:**
```bash
# For each selected PR, main agent fetches and saves locally
for PR_NUM in 3935 3940 3942; do
  gh pr view $PR_NUM --json number,title,body,statusCheckRollup,reviews,comments > /tmp/warden-pr-${PR_NUM}.json
  gh pr diff $PR_NUM > /tmp/warden-pr-${PR_NUM}.diff
  gh pr checks $PR_NUM --json name,status,conclusion > /tmp/warden-pr-${PR_NUM}-checks.json
done
```

**Example Phase 2 subagent invocation:**
```
# ❌ WRONG (doesn't work in Copilot):
"Analyze CI failures for PR #3935 using gh pr checks"

# ✅ CORRECT (works in Copilot):
"Analyze /tmp/warden-pr-3935-checks.json and identify CI failures.
 PR details in /tmp/warden-pr-3935.json, diff in /tmp/warden-pr-3935.diff"
```

### Native Integration

**Leverage GitHub features** (main agent only):
- Use `gh` CLI for all PR operations (main agent fetches data)
- Access CI logs directly through GitHub integration
- View check run details without API calls
- Monitor workflow status in real-time

### Batch Operations

**Single query for multiple PRs**:
```bash
gh pr list --author @me --state open --json number,title,statusCheckRollup,reviewDecision --limit 10
```

**For analysis**, gather data from:
- CI failures and error patterns (`gh pr checks`)
- Review comments (`gh pr view --json reviews,comments`)
- Code quality issues from diff analysis

### GitHub CLI Usage

All GitHub operations use `gh` CLI for **PULL REQUESTS**:
- `gh pr list --state open --json ...` - List open PRs (NOT branches!)
- `gh pr checks <pr-number>` - Get CI status for a PR
- `gh pr view <pr-number> --json reviews,comments` - Get review comments
- `gh pr diff <pr-number>` - Get code changes in a PR

**Critical Commands**:
```bash
# ✅ CORRECT - List pull requests
gh pr list --author @me --state open --json number,title,statusCheckRollup,reviewDecision

# ❌ WRONG - This lists branches, not PRs!
git branch --list

# ❌ WRONG - This shows repo info, not PRs!
gh repo view
```

## Key Optimizations

**Parallel**: All PR analysis runs simultaneously (2.5x faster)
**Incremental**: Fix/test/commit by severity, rollback per-tier
**Targeted**: Shallow clones, test only affected packages
**Performance**: 167s-240s vs 291s sequential = **1.2-1.7x faster** (configuration-dependent)

## Implementation Guidelines

1. **Use gh CLI** - For all GitHub PR operations
2. **Batch API calls** - Single call for all PRs
3. **Shallow clone** - `gh repo clone --depth=1`
4. **Test targeted** - Only changed packages
5. **Incremental fixes** - By severity tier (Critical → High → Medium → Low)
6. **Background cleanup** - Non-blocking workspace removal
7. **Never modify user's working directory** - Use `/tmp` workspace

## Phase 2: Analysis (Parallel with Local Files)

**⚠️ CRITICAL FOR COPILOT**: Main agent must pre-fetch all data before launching subagents!

**Step 1: Main agent fetches and saves data locally** (for each selected PR):
```bash
# Create temp directory for this Warden session
WARDEN_TMP="/tmp/warden-session-$(date +%s)"
mkdir -p "$WARDEN_TMP"

# Get repo info for API calls
OWNER=$(gh repo view --json owner -q .owner.login)
REPO=$(gh repo view --json name -q .name)

# For each PR, fetch all needed data
for PR_NUM in ${SELECTED_PRS[@]}; do
  # PR metadata and review SUMMARIES
  gh pr view $PR_NUM --json number,title,body,author,statusCheckRollup,reviews,comments,updatedAt \
    > "$WARDEN_TMP/pr-${PR_NUM}.json"

  # ⚠️ CRITICAL (Gap #15): Review COMMENT THREADS (separate endpoint!)
  # This is where detailed feedback lives (file-specific comments with bugs/issues)
  gh api "/repos/${OWNER}/${REPO}/pulls/${PR_NUM}/comments" \
    > "$WARDEN_TMP/pr-${PR_NUM}-review-comments.json"

  # PR diff for code analysis
  gh pr diff $PR_NUM > "$WARDEN_TMP/pr-${PR_NUM}.diff"

  # CI check details
  gh pr checks $PR_NUM --json name,status,conclusion,detailsUrl \
    > "$WARDEN_TMP/pr-${PR_NUM}-checks.json"
done

# BLOCKING CHECK: Verify review comment threads were fetched
for PR_NUM in ${SELECTED_PRS[@]}; do
  if [ ! -f "$WARDEN_TMP/pr-${PR_NUM}-review-comments.json" ]; then
    echo "❌ FATAL: Review comment threads not fetched for PR #${PR_NUM}"
    exit 1
  fi
done
```

**Step 2: Launch subagents with local file references** (NOT PR numbers):
```
# For PR #3935, launch 3 parallel subagents:

Subagent 1 - CI Analysis:
"Analyze CI failures in /tmp/warden-session-xxx/pr-3935-checks.json.
 Identify failed checks, categorize by type (test/build/lint).
 PR context in /tmp/warden-session-xxx/pr-3935.json"

Subagent 2 - Review Comments (**MANDATORY: Analyze BOTH files**):
"⚠️ CRITICAL (Gap #15): Analyze review data from BOTH sources:

 File 1: /tmp/warden-session-xxx/pr-3935.json (reviews field)
   - Contains: Review SUMMARIES (APPROVED, CHANGES_REQUESTED states)
   - Who reviewed and overall state

 File 2: /tmp/warden-session-xxx/pr-3935-review-comments.json
   - Contains: Review COMMENT THREADS (detailed feedback)
   - File-specific comments with line numbers
   - Actual bug reports like: 'Line 123: This loop causes data leaks'
   - **THIS IS WHERE CRITICAL FEEDBACK LIVES**

 Parse BOTH files for:
 - **FIRST**: Filter out resolved threads (resolved: true) - already addressed
 - Human reviews (requested changes, suggestions, questions)
 - Bot/AI reviews (GitHub Copilot, security scanners, code analysis bots)
 - Actionable keywords: 'should', 'must', 'concern', 'issue', 'todo', 'recommend', 'bug', 'leak'
 - Unresolved comment threads (no author reply)
 - File/line specific issues

 DON'T skip this even if CI is green - review feedback exists independently of CI status.

 See docs/REVIEW-COMMENTS.md for data structure differences."

Subagent 3 - Code Quality:
"Review code changes in /tmp/warden-session-xxx/pr-3935.diff.
 PR description and intent in /tmp/warden-session-xxx/pr-3935.json.
 Check for security, performance, bugs, best practices."
```

**Step 3: Subagents read local files** (no `gh` access needed):
- Subagents use grep/glob/read tools on local JSON and diff files
- All GitHub data is already fetched and saved locally
- Subagents return findings to main agent

**Step 4: Cleanup after analysis**:
```bash
rm -rf "$WARDEN_TMP"
```

## Phase 5: Execution (Incremental)

**Workspace setup** (optimized with branch verification):
```bash
# MANDATORY: Get actual branch name from PR
PR_BRANCH=$(gh pr view ${PR_NUMBER} --json headRefName --jq '.headRefName')
if [ -z "$PR_BRANCH" ]; then
  echo "ERROR: Could not get branch for PR #${PR_NUMBER}"
  exit 1
fi

WORKSPACE="/tmp/warden-repos/pr-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Clone and checkout PR's actual branch
gh repo clone owner/repo . -- --depth=1
gh pr checkout ${PR_NUMBER}  # RECOMMENDED: Handles branch verification

# Verify branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$PR_BRANCH" ]; then
  echo "ERROR: Branch mismatch! Current: $CURRENT_BRANCH, Expected: $PR_BRANCH"
  exit 1
fi
```

**Fix strategy**:
- Simple (1-5 lines): Inline suggestions
- Moderate (5-20 lines): Chat mode
- Complex (20+ lines): Workspace mode
- Very complex (>5 files): Flag for manual review

**Commit format**:
```
[PR #${PR_NUMBER}] Fix: ${SEVERITY} - ${DESCRIPTION}

Fixed ${ISSUE_COUNT} ${SEVERITY} severity issues:
- [${ISSUE_ID}] ${ISSUE_SUMMARY} (${FILE}:${LINE})

Tested: ${AFFECTED_PACKAGES}
```

**Validation and push** (ABSOLUTE BLOCKING - Gap #16 fix):
```bash
#!/bin/bash
set -euo pipefail  # No bypassing

echo "=== Pre-Push Validation (ABSOLUTE BLOCKING) ==="
echo "HARD RULE: Tests must pass 100% before ANY push"

# Source validation commands from Phase 0
source .warden-validation-commands.sh

# Track failures
VALIDATION_FAILED=false

# Build
eval "$BUILD_CMD" || { echo "❌ BUILD FAILED"; VALIDATION_FAILED=true; }

# Lint
eval "$LINT_CMD" || { echo "❌ LINT FAILED"; VALIDATION_FAILED=true; }

# Format
eval "$FORMAT_CMD" || true

# Tests (ABSOLUTE BLOCKING)
if ! eval "$TEST_CMD"; then
  echo "❌❌❌ TESTS FAILED ❌❌❌"
  echo "DIAGNOSTIC PUSH BLOCKED (Gap #16)"
  echo "Cannot push code with failing tests"
  VALIDATION_FAILED=true
fi

# BLOCKING CHECK
if [ "$VALIDATION_FAILED" = true ]; then
  echo "VALIDATION FAILED - CANNOT PUSH"
  git reset --hard HEAD
  exit 1
fi

# Pre-commit verification
git add .
UNINTENDED=$(git diff --cached --name-only | grep -E '(_debug\.|test_debug\.)' || true)
[ -n "$UNINTENDED" ] && { git reset --hard HEAD; exit 1; }

# Only push if ALL validations passed
echo "✅ ALL VALIDATIONS PASSED"
git commit -m "[PR #${PR_NUMBER}] Fix: ${SEVERITY} - ${DESCRIPTION}"
git push origin $(git branch --show-current)

# Monitor CI
gh pr checks ${PR_NUMBER} --watch
```

See [docs/DIAGNOSTIC-PUSH-PREVENTION.md](../docs/DIAGNOSTIC-PUSH-PREVENTION.md)

## Language-Specific Adaptations

Auto-detect language, then use targeted commands (only changed files):

### Go
```bash
gofmt -s -w $(git diff --name-only origin/main | grep '\.go$')
go test -v ./$(dirname $(git diff --name-only origin/main | grep '\.go$'))/...
golangci-lint run $(git diff --name-only origin/main | grep '\.go$')
```

### Python
```bash
black $(git diff --name-only origin/main | grep '\.py$')
pytest $(dirname $(git diff --name-only origin/main | grep '\.py$')) -v
ruff check $(git diff --name-only origin/main | grep '\.py$')
```

### JavaScript/TypeScript
```bash
prettier --write $(git diff --name-only origin/main | grep -E '\.(js|ts|jsx|tsx)$')
npm test -- --changedSince=origin/main
eslint $(git diff --name-only origin/main | grep -E '\.(js|ts|jsx|tsx)$')
```

### Rust
```bash
cargo fmt -- $(git diff --name-only origin/main | grep '\.rs$')
cargo test --package <affected_package>
cargo clippy -- -D warnings
```

## Error Handling

**Graceful degradation**:
- CI logs unavailable → Skip CI analysis
- Review API fails → Skip review analysis
- Tests fail → Rollback severity tier, continue to next PR

**Rollback strategies**:
- **Per-tier**: Keep Critical fixes if High fails
- **Full**: Abort PR if Critical fails
- **Selective**: Rollback specific commit if isolated failure

**Always**:
- Clean up workspaces (even on failure)
- Continue to next PR if one fails
- Collect failures for summary

## Performance Metrics

For 3 PRs (~500 lines each):

| Phase | Sequential | Optimized | Improvement |
|-------|-----------|-----------|-------------|
| Discovery | 6s | 2s | 3x faster |
| Analysis | 90s | 35s | 2.5x faster |
| Planning | 15s | 10s | 1.5x faster |
| Execution | 180s | 120s | 1.5x faster |
| **Total** | **291s** | **167s** | **1.7x faster** |

## Best Practices

- **Always work with PRs, not branches directly** - Use `gh pr list`, `gh pr view`, `gh pr checkout`
- **Verify branch before pushing** - Use `gh pr view --json headRefName` to get correct branch
- Use `gh pr checkout <pr-number>` (handles branch verification automatically)
- Use `gh` CLI for all GitHub operations
- Batch API calls wherever possible
- Shallow clone for workspace setup
- Test only affected packages
- Provide detailed commit messages
- Rollback per-tier, not full PR
- Clean up in background
- Flag complex changes for manual review

## Common Mistakes to Avoid

❌ **Using `git branch --list`** instead of `gh pr list`
❌ **Assuming branch names** instead of fetching from PR data
❌ **Pushing to wrong branch** - always verify with `gh pr view --json headRefName`
❌ **Trusting cached data** - always fetch fresh PR info from GitHub API

✅ **Use `gh pr checkout <number>`** - safest method
✅ **Verify branch matches PR** before pushing
✅ **Fetch fresh PR data** for each operation

## Full Documentation

See [README.md](README.md) for complete workflow and [AGENTS.md](AGENTS.md) for platform-agnostic guidance.
