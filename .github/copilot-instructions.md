# GitHub Copilot Instructions for Warden

## About Warden

Warden v1.2: Cross-platform AI skill for automated PR review and fixes.

**New in v1.2**: Contextual review, 50+ configuration parameters, 5 specialized reviewers, flexible test strategies, PR integration, external webhooks.

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

### Key Parameters (40+ available - see README.md)
- `--author <username>` - Review PRs by specific author
- `--repo <owner/repo>` - Target specific repository
- `--reviewers security,performance,architecture` - Custom reviewers
- `--test-strategy none|affected|full|smart` - Test approach
- `--fix-strategy conservative|balanced|aggressive` - Fix aggressiveness
- `--comment-on-pr` - Post findings to PR
- `--notify-slack <webhook>` - Send summary to Slack
- `--dry-run` - Preview without fixing

See README.md for complete parameter reference.

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

# For each PR, fetch all needed data
for PR_NUM in ${SELECTED_PRS[@]}; do
  # PR metadata and reviews
  gh pr view $PR_NUM --json number,title,body,author,statusCheckRollup,reviews,comments,updatedAt \
    > "$WARDEN_TMP/pr-${PR_NUM}.json"

  # PR diff for code analysis
  gh pr diff $PR_NUM > "$WARDEN_TMP/pr-${PR_NUM}.diff"

  # CI check details
  gh pr checks $PR_NUM --json name,status,conclusion,detailsUrl \
    > "$WARDEN_TMP/pr-${PR_NUM}-checks.json"
done
```

**Step 2: Launch subagents with local file references** (NOT PR numbers):
```
# For PR #3935, launch 3 parallel subagents:

Subagent 1 - CI Analysis:
"Analyze CI failures in /tmp/warden-session-xxx/pr-3935-checks.json.
 Identify failed checks, categorize by type (test/build/lint).
 PR context in /tmp/warden-session-xxx/pr-3935.json"

Subagent 2 - Review Comments (ALL reviews, including bots):
"Analyze ALL review comments in /tmp/warden-session-xxx/pr-3935.json (reviews and comments fields).

 CRITICAL: Include bot/AI reviews (GitHub Copilot, security scanners, code analysis bots).
 Parse for actionable keywords: 'should', 'must', 'concern', 'issue', 'todo', 'recommend'.
 Identify unresolved threads and actionable feedback.
 Categorize by severity.

 DON'T skip this even if CI is green - review feedback exists independently of CI status."

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

WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
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

Co-Authored-By: Warden <noreply@warden.dev>
```

**Test and push**:
```bash
# Test only affected packages
git diff --name-only origin/main | xargs <language-specific-test>

# Push and verify
git push origin pr-${PR_NUMBER}
gh pr checks ${PR_NUMBER} --watch
```

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
