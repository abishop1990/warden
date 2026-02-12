# GitHub Copilot Instructions for Warden

## About Warden

Warden v1.2: Cross-platform AI skill for automated PR review and fixes.

**New in v1.2**: Contextual review, 50+ configuration parameters, 5 specialized reviewers, flexible test strategies, PR integration, external webhooks.

## Execution Mode

**THIS IS NOT CONCEPTUAL REVIEW** - You actually execute commands and check exit codes.

- ✅ Checkout PR branches, run build/lint/test commands, check exit codes, fix failures, push fixes
- ❌ NOT: Abstract "review against principles" analysis without running tools

## Three Issue Sources

Warden analyzes and fixes issues from:
1. **CI failures** - Test failures, build errors, lint issues
2. **Review comments** - Requested changes, unresolved feedback from reviewers
3. **Code quality** - Security, performance, architecture issues from analysis

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

1. **Discovery** - Batch `gh pr list --json` (single API call)
   - ✅ Use: `gh pr list --author @me --state open --json ...`
   - ❌ DON'T: `git branch --list` (this lists branches, not PRs!)
2. **Analysis** - Parallel analysis of all PRs (CI, reviews, code quality)
3. **Planning** - Deduplicate, prioritize by severity
4. **User Interaction** - Select fixes
5. **Execution** - Incremental fixes (Critical → High → Medium → Low)
6. **Summary** - Comprehensive report

## GitHub Copilot Specific Optimizations

### Native Integration

**Leverage GitHub features**:
- Access CI logs directly through GitHub integration
- View check run details without API calls
- Monitor workflow status in real-time
- Use `gh` CLI for all PR operations

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

## Phase 2: Analysis (Parallel)

For each PR, analyze:

**CI Analysis**:
```bash
gh pr checks <pr-number> --json name,status,conclusion,detailsUrl
# If failed, fetch logs and categorize failures
```

**Review Comments**:
```bash
gh pr view <pr-number> --json reviews,comments
# Identify unresolved threads and actionable feedback
```

**Code Quality**:
```bash
gh pr diff <pr-number>
# Analyze for bugs, security, performance, best practices
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
