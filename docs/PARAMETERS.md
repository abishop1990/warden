# Warden - Complete Parameter Reference

All 50+ configuration parameters for complete control over Warden's behavior.

## Quick Reference by Category

| Category | Count | Jump To |
|----------|-------|---------|
| PR Selection | 4 | [↓](#pr-selection) |
| Review Config | 10 | [↓](#review-configuration) |
| Test Strategy | 6 | [↓](#test-strategy) |
| Fix Strategy | 4 | [↓](#fix-strategy) |
| Safety | 6 | [↓](#safety-features-new) |
| PR Integration | 3 | [↓](#pr-integration) |
| Performance | 5 | [↓](#performance--limits) |
| Workspace | 4 | [↓](#workspace-management) |
| Output | 5 | [↓](#output--reporting) |
| Language | 4 | [↓](#language--tooling) |
| File Filtering | 3 | [↓](#file-filtering) |
| Integrations | 3 | [↓](#integration-hooks) |
| Advanced | 4 | [↓](#advanced-options) |

---

## PR Selection

### `--author <username>`
Review PRs by specific author.
- **Default**: Current user (`@me`)
- **Example**: `--author octocat`

### `--repo <owner/repo>`
Target specific repository.
- **Default**: Current repository
- **Example**: `--repo abishop1990/warden`

### `--state <open|closed|all>`
PR state to review.
- **Default**: `open`
- **Example**: `--state all`

### `--limit <n>`
Maximum number of PRs to review.
- **Default**: `10`
- **Example**: `--limit 50`

---

## Review Configuration

### `--review-depth <standard|thorough|comprehensive>`
Preset review depths.
- **Default**: `standard`
- **Options**:
  - `standard`: 1 generalist reviewer (fastest)
  - `thorough`: 2 reviewers (security + performance)
  - `comprehensive`: 3 reviewers (security + performance + architecture)
- **Example**: `--review-depth thorough`

### `--reviewers <list>`
Custom reviewer selection (comma-separated).
- **Default**: `generalist`
- **Available reviewers**:
  - `generalist`: Broad coverage across all areas
  - `security`: OWASP, auth, injection, secrets, crypto
  - `performance`: N+1 queries, memory, algorithms, caching
  - `architecture`: Design patterns, SOLID, coupling, scalability
  - `maintainability`: Code clarity, docs, tech debt
  - `testing`: Test coverage, edge cases, test quality
- **Example**: `--reviewers security,testing`
- **Overrides**: Takes precedence over `--review-depth`

### `--reviewer-count <1-5>`
Number of reviewers (overrides presets).
- **Default**: `1`
- **Range**: 1-5
- **Example**: `--reviewer-count 3`

### `--review-focus <area>`
Target specific concern area.
- **Default**: `all`
- **Options**: `security`, `performance`, `architecture`, `maintainability`, `all`
- **Example**: `--review-focus security`

---

## Test Strategy

### `--test-strategy <strategy>`
Testing approach.
- **Default**: `affected`
- **Options**:
  - `none`: Skip all tests (for docs/config PRs)
  - `affected`: Only test changed packages (fastest)
  - `full`: Run entire test suite (thorough)
  - `smart`: Affected packages + dependencies (balanced)
- **Example**: `--test-strategy full`

### `--test-on-severity <levels>`
Only test when fixing certain severities.
- **Default**: `all`
- **Options**: `critical,high`, `critical`, `all`, `none`
- **Example**: `--test-on-severity critical,high`

### `--test-timeout <seconds>`
Maximum seconds per test run.
- **Default**: `300` (5 minutes)
- **Example**: `--test-timeout 600`

### `--skip-tests-for <extensions>`
Skip tests if only these file types changed.
- **Default**: `.md,.yml,.yaml,.json,.txt`
- **Example**: `--skip-tests-for .md,.rst,.adoc`

### `--test-before-fix`
Run tests before making changes to verify CI failure.
- **Default**: `false`
- **Example**: `--test-before-fix`

### `--test-command <command>`
Custom test command (overrides language default).
- **Example**: `--test-command "npm run test:ci"`

---

## Fix Strategy

### `--fix-strategy <strategy>`
Fix approach and aggressiveness.
- **Default**: `balanced`
- **Options**:
  - `conservative`: Only high-confidence fixes (90%+), flag complex
  - `balanced`: Fix most issues (70%+), flag architectural
  - `aggressive`: Attempt all fixes (50%+), attempt complex refactors
- **Example**: `--fix-strategy conservative`

### `--max-fixes-per-tier <n>`
Limit fixes per severity tier.
- **Default**: Unlimited
- **Example**: `--max-fixes-per-tier 10`

### `--auto-commit-on-success`
Auto-commit each tier if tests pass.
- **Default**: `true`
- **Example**: `--auto-commit-on-success false`

### `--dry-run`
Preview issues without making any fixes.
- **Default**: `false`
- **Example**: `--dry-run`

---

## Safety Features (NEW!)

### `--require-review-before-push`
Show diff and require confirmation before pushing.
- **Default**: `false`
- **Example**: `--require-review-before-push`
- **Behavior**: Shows full diff and asks "Push these changes? (y/N)"

### `--protect-branches <list>`
Never push to these branches (comma-separated).
- **Default**: `main,master,production`
- **Example**: `--protect-branches main,master,prod,release`
- **Behavior**: Aborts with error if trying to push to protected branch

### `--max-files-changed <n>`
Abort if changes exceed this limit.
- **Default**: Unlimited
- **Example**: `--max-files-changed 20`
- **Behavior**: Safety check to prevent runaway changes

### `--check-conflicts-before-fix`
Detect merge conflicts before starting fixes.
- **Default**: `true`
- **Example**: `--check-conflicts-before-fix false`
- **Behavior**: Aborts PR if merge conflicts detected

### `--create-rollback-branch`
Create backup branch before making fixes.
- **Default**: `false`
- **Example**: `--create-rollback-branch`
- **Behavior**: Creates `warden-rollback-PR#-TIMESTAMP` branch

### `--respect-rate-limits`
Auto-throttle GitHub API calls to respect rate limits.
- **Default**: `true`
- **Example**: `--respect-rate-limits false`

---

## PR Integration

### `--comment-on-pr`
Post findings as PR comment.
- **Default**: `false`
- **Example**: `--comment-on-pr`

### `--comment-template <path>`
Custom comment template file.
- **Example**: `--comment-template .github/warden-comment.md`

### `--update-comment`
Update existing comment instead of adding new.
- **Default**: `false`
- **Example**: `--update-comment`

### `--auto-label`
Add labels to PR based on findings.
- **Default**: `false`
- **Example**: `--auto-label`
- **Labels**: `warden-security`, `warden-performance`, `warden-needs-tests`

### `--label-prefix <prefix>`
Prefix for auto-generated labels.
- **Default**: `warden-`
- **Example**: `--label-prefix bot-`

---

## Performance & Limits

### `--max-parallel-prs <n>`
Max concurrent PR analysis.
- **Default**: `10`
- **Example**: `--max-parallel-prs 20`

### `--max-parallel-agents <n>`
Max total concurrent subagents.
- **Default**: Unlimited (determined by reviewers × PRs)
- **Example**: `--max-parallel-agents 15`

### `--cache-pr-data <seconds>`
Cache PR metadata for N seconds.
- **Default**: `0` (no caching)
- **Example**: `--cache-pr-data 3600` (1 hour)

### `--cache-location <path>`
Where to store cached data.
- **Default**: `.warden/cache/`
- **Example**: `--cache-location /tmp/warden-cache/`

---

## Workspace Management

### `--keep-workspace`
Don't clean up workspace (for debugging).
- **Default**: `false`
- **Example**: `--keep-workspace`

### `--workspace-dir <path>`
Custom workspace location.
- **Default**: `/tmp/pr-review-*`
- **Example**: `--workspace-dir /custom/workspace`

### `--reuse-workspace`
Reuse workspace across PRs from same repo.
- **Default**: `false`
- **Example**: `--reuse-workspace`

---

## Output & Reporting

### `--output-format <format>`
Summary report format.
- **Default**: `text`
- **Options**: `text`, `json`, `markdown`, `html`
- **Example**: `--output-format json`

### `--save-report <path>`
Save summary to file.
- **Default**: Console only
- **Example**: `--save-report warden-report.md`

### `--verbose`
Detailed logging.
- **Default**: `false`
- **Example**: `--verbose`

### `--quiet`
Minimal output.
- **Default**: `false`
- **Example**: `--quiet`

### `--severity <level>`
Only show issues at or above this level.
- **Default**: Show all
- **Options**: `critical`, `high`, `medium`, `low`
- **Example**: `--severity high`

### `--save-metrics <path>`
Track metrics over time.
- **Default**: Disabled
- **Example**: `--save-metrics .warden/metrics.json`
- **Tracks**: PRs reviewed, issues found, fixes applied, success rate

---

## Language & Tooling

### `--language <lang>`
Force language detection.
- **Default**: Auto-detect
- **Options**: `go`, `python`, `javascript`, `typescript`, `rust`
- **Example**: `--language go`

### `--formatter <command>`
Custom formatter command.
- **Overrides**: Language default
- **Example**: `--formatter "black --line-length 100"`

### `--linter <command>`
Custom linter command.
- **Example**: `--linter "eslint --fix"`

### `--skip-generated`
Automatically skip generated files.
- **Default**: `true`
- **Patterns**: `*.pb.go`, `*_generated.*`, `dist/`, `build/`
- **Example**: `--skip-generated false`

---

## File Filtering

### `--ignore-paths <patterns>`
Skip paths in review (comma-separated).
- **Default**: `vendor/,node_modules/,*.pb.go,*_generated.go,dist/,build/`
- **Example**: `--ignore-paths "third_party/,generated/"`

### `--focus-paths <patterns>`
Only review these paths (comma-separated).
- **Example**: `--focus-paths "src/,cmd/"`

### `--max-file-size <lines>`
Skip files larger than N lines.
- **Default**: Unlimited
- **Example**: `--max-file-size 5000`

---

## Integration Hooks

### `--notify-slack <webhook-url>`
Send summary to Slack.
- **Example**: `--notify-slack https://hooks.slack.com/...`

### `--update-jira <ticket-id>`
Update Jira ticket with findings.
- **Example**: `--update-jira PROJ-123`

### `--webhook <url>`
POST summary JSON to webhook.
- **Example**: `--webhook https://api.example.com/pr-review`

---

## Advanced Options

### `--review-rules <path>`
Custom review rules YAML file.
- **Default**: `.warden-rules.yml` (if exists)
- **Example**: `--review-rules custom-rules.yml`

### `--diff-context <lines>`
Lines of context in diffs.
- **Default**: `3`
- **Example**: `--diff-context 5`

### `--cache-analysis`
Cache CI logs and review comments.
- **Default**: `false`
- **Duration**: 1 hour
- **Example**: `--cache-analysis`

### `--incremental-review`
Only review files changed since last Warden run.
- **Default**: `false`
- **Example**: `--incremental-review`

### `--include-drafts`
Include draft PRs in review.
- **Default**: `false`
- **Example**: `--include-drafts`

### `--draft-strategy <strategy>`
How to handle draft PRs.
- **Default**: `review-only`
- **Options**: `review-only`, `fix`, `skip`
- **Example**: `--draft-strategy skip`

### `--baseline-commit <sha>`
Review changes since this commit.
- **Example**: `--baseline-commit abc123`

---

## Parameter Precedence

When multiple parameters conflict:

1. `--reviewers` (explicit list) > `--reviewer-count` > `--review-depth`
2. `--test-strategy none` overrides `--test-on-severity`
3. `--focus-paths` applied before `--ignore-paths`
4. `--dry-run` disables all fix operations

## See Also

- **Quick examples**: [EXAMPLES.md](EXAMPLES.md)
- **Detailed workflow**: [WORKFLOW.md](WORKFLOW.md)
- **Safety features**: [SAFETY.md](SAFETY.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
