# GitHub Copilot Instructions for Warden

## About Warden

Warden v1.2: Cross-platform AI skill for automated PR review and fixes.

**New in v1.2**: Contextual review, 40+ configuration parameters, 5 specialized reviewers, flexible test strategies, PR integration, external webhooks.

## Invocation

```
@copilot /pr-review-and-fix
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

1. **Discovery** - Batch `gh pr list --json` (single API call)
2. **Analysis** - Parallel analysis of all PRs (CI, reviews, code quality)
3. **Planning** - Deduplicate, prioritize by severity
4. **User Interaction** - Select fixes
5. **Execution** - Incremental fixes (Critical → High → Medium → Low)
6. **Summary** - Comprehensive report

## GitHub Copilot Specific Optimizations

### Native Integration

**Use @github mention**:
```
@github show me CI failures, review comments, and code issues for PRs #123, #125, #127
```

**Leverage GitHub Actions**:
- Access CI logs directly through GitHub integration
- View check run details without API calls
- Monitor workflow status in real-time

### Batch Operations

**Single query for multiple PRs**:
```bash
gh pr list --author @me --state open --json number,title,statusCheckRollup,reviewDecision --limit 10
```

**Parallel PR analysis**:
```
@github analyze PRs #123, #125, #127 for:
- CI failures and error patterns
- Unresolved review comments
- Code quality issues (security, performance, bugs)
```

### GitHub CLI Usage

All GitHub operations use `gh` CLI:
- `gh pr list` - Discovery
- `gh pr checks` - CI status
- `gh pr view --json reviews,comments` - Review comments
- `gh pr diff` - Code changes

## Key Optimizations

**Parallel**: All PR analysis runs simultaneously (2.5x faster)
**Incremental**: Fix/test/commit by severity, rollback per-tier
**Targeted**: Shallow clones, test only affected packages
**Performance**: 167s-240s vs 291s sequential = **1.2-1.7x faster** (configuration-dependent)

## Implementation Guidelines

1. **Use @github for native integration**
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

**Workspace setup** (optimized):
```bash
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
gh repo clone owner/repo . -- --depth=1
git fetch --depth=1 origin pull/${PR_NUMBER}/head:pr-${PR_NUMBER}
git checkout pr-${PR_NUMBER}
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

- Use `@github` for all GitHub operations
- Batch API calls wherever possible
- Shallow clone for workspace setup
- Test only affected packages
- Provide detailed commit messages
- Rollback per-tier, not full PR
- Clean up in background
- Flag complex changes for manual review

## Full Documentation

See [README.md](README.md) for complete workflow and [AGENTS.md](AGENTS.md) for platform-agnostic guidance.
