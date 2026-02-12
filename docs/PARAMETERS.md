# Warden - Parameter Reference (v1.2)

**Streamlined for v1.2**: Reduced from 59 to 25 core parameters, focusing on natural language expressibility and avoiding premature optimization.

## Core Parameters (25)

Essential parameters for everyday use. These cover 95% of real-world scenarios.

### PR Selection (4)

#### `--author <username>`
Review PRs by specific author.
- **Default**: Current user (`@me`)
- **Example**: `--author octocat`

#### `--repo <owner/repo>`
Target specific repository.
- **Default**: Current repository
- **Example**: `--repo abishop1990/warden`

#### `--state <open|closed|all>`
PR state to review.
- **Default**: `open`
- **Example**: `--state all`

#### `--limit <n>`
Maximum number of PRs to review.
- **Default**: `10`
- **Example**: `--limit 50`

---

### Review Configuration (1)

#### `--reviewers <list>`
Specify reviewers (comma-separated). This single parameter replaces all review depth/count/focus params.
- **Default**: `generalist`
- **Available reviewers**:
  - `generalist`: Broad coverage across all areas
  - `security`: OWASP, auth, injection, secrets, crypto
  - `performance`: N+1 queries, memory, algorithms, caching
  - `architecture`: Design patterns, SOLID, coupling, scalability
  - `maintainability`: Code clarity, docs, tech debt
  - `testing`: Test coverage, edge cases, test quality
- **Example**: `--reviewers security,performance,testing`
- **Natural language alternative**: Say "use comprehensive review" for multiple reviewers

---

### Test Strategy (3)

#### `--test-strategy <strategy>`
Testing approach.
- **Default**: `affected`
- **Options**:
  - `none`: Skip all tests (for docs/config PRs)
  - `affected`: Only test changed packages (fastest)
  - `full`: Run entire test suite (thorough)
  - `smart`: Affected packages + dependencies (balanced)
- **Example**: `--test-strategy full`

#### `--test-timeout <seconds>`
Maximum seconds per test run.
- **Default**: `300` (5 minutes)
- **Example**: `--test-timeout 600`

#### `--parallel-tests`
Run tests in parallel when supported by test framework.
- **Default**: `true`
- **Example**: `--parallel-tests false`

---

### Fix Strategy (2)

#### `--fix-strategy <strategy>`
Fix approach and aggressiveness.
- **Default**: `balanced`
- **Options**:
  - `conservative`: Only high-confidence fixes (90%+), flag complex
  - `balanced`: Fix most issues (70%+), flag architectural
  - `aggressive`: Attempt all fixes (50%+), attempt complex refactors
- **Example**: `--fix-strategy conservative`

#### `--dry-run`
Preview issues without making any fixes.
- **Default**: `false`
- **Example**: `--dry-run`

---

### Safety (2)

#### `--max-files-changed <n>`
Abort if changes exceed this limit (safety check for runaway changes).
- **Default**: Unlimited
- **Example**: `--max-files-changed 20`

#### `--protect-branches <list>`
Never push to these branches (comma-separated).
- **Default**: `main,master,production`
- **Example**: `--protect-branches main,master,prod,release`

---

### PR Integration (1)

#### `--comment-on-pr`
Post findings as PR comment.
- **Default**: `false`
- **Example**: `--comment-on-pr`

---

### Performance (1)

#### `--max-parallel-prs <n>`
Max concurrent PR analysis (batching).
- **Default**: `5`
- **Example**: `--max-parallel-prs 10`
- **Note**: Prevents system overload and API rate limiting

---

### Workspace (3)

#### `--workspace-root <path>`
Root directory for temporary PR workspaces.
- **Default**: `/tmp/warden-repos`
- **Example**: `--workspace-root /custom/workspace`
- **Behavior**: Creates subdirectories like `/tmp/warden-repos/pr-123-1234567890/`
- **Note**: All PR workspaces organized under this root for easy cleanup

#### `--in-place`
Run in current repository without creating temp workspaces.
- **Default**: `false` (use isolated workspaces)
- **Example**: `--in-place`
- **Use case**: Repos with complex local setup (databases, custom tooling)
- **⚠️ WARNING**:
  - Slower (no parallel processing)
  - Modifies your working directory
  - Ensure clean git state first: `git status`
- **Recommended**: Only use when isolated workspaces can't handle repo setup

#### `--keep-workspace`
Don't clean up workspace after completion (for debugging).
- **Default**: `false`
- **Example**: `--keep-workspace`
- **Note**: Useful when you need to inspect workspace state after errors

---

### Output (2)

#### `--output-format <format>`
Summary report format.
- **Default**: `text`
- **Options**: `text`, `json`, `markdown`, `html`
- **Example**: `--output-format json`

#### `--verbose`
Detailed logging.
- **Default**: `false`
- **Example**: `--verbose`

---

### Language & Tooling (3)

#### `--language <lang>`
Force language detection.
- **Default**: Auto-detect
- **Options**: `go`, `python`, `javascript`, `typescript`, `rust`
- **Example**: `--language go`

#### `--formatter <command>`
Custom formatter command (overrides language default).
- **Example**: `--formatter "black --line-length 100"`

#### `--linter <command>`
Custom linter command (overrides language default).
- **Example**: `--linter "eslint --fix"`

---

### File Filtering (2)

#### `--ignore-paths <patterns>`
Skip paths in review (comma-separated).
- **Default**: `vendor/,node_modules/,*.pb.go,*_generated.go,dist/,build/`
- **Example**: `--ignore-paths "third_party/,generated/"`

#### `--focus-paths <patterns>`
Only review these paths (comma-separated).
- **Example**: `--focus-paths "src/,cmd/"`

---

## Advanced/Experimental Parameters (19)

These parameters may be useful in specific scenarios but aren't core to v1.2. Some may be promoted to core or removed based on real-world usage.

### Safety (Extended)

#### `--require-review-before-push`
Show diff and require confirmation before pushing.
- **Default**: `false`
- **Use case**: Extra safety for sensitive repos

#### `--check-conflicts-before-fix`
Detect merge conflicts before starting fixes.
- **Default**: `true`

#### `--create-rollback-branch`
Create backup branch before making fixes.
- **Default**: `false`
- **Creates**: `warden-rollback-PR#-TIMESTAMP` branch

---

### PR Integration (Extended)

#### `--comment-template <path>`
Custom comment template file.
- **Example**: `--comment-template .github/warden-comment.md`

#### `--update-comment`
Update existing comment instead of adding new.
- **Default**: `false`

#### `--auto-label`
Add labels to PR based on findings.
- **Default**: `false`
- **Labels**: `warden-security`, `warden-performance`, `warden-needs-tests`

#### `--label-prefix <prefix>`
Prefix for auto-generated labels.
- **Default**: `warden-`

---

### Test Strategy (Extended)

#### `--test-on-severity <levels>`
Only test when fixing certain severities.
- **Default**: `all`
- **Example**: `--test-on-severity critical,high`

#### `--skip-tests-for <extensions>`
Skip tests if only these file types changed.
- **Default**: `.md,.yml,.yaml,.json,.txt`

---

### Fix Strategy (Extended)

#### `--max-fixes-per-tier <n>`
Limit fixes per severity tier.
- **Default**: Unlimited

#### `--auto-commit-on-success`
Auto-commit each tier if tests pass.
- **Default**: `true`

---

### Workspace (Extended)

#### `--workspace-dir <path>`
Custom workspace location.
- **Default**: `/tmp/pr-review-*`

#### `--reuse-workspace`
Reuse workspace across PRs from same repo.
- **Default**: `false`

---

### Output (Extended)

#### `--save-report <path>`
Save summary to file.
- **Example**: `--save-report warden-report.md`

#### `--quiet`
Minimal output.
- **Default**: `false`

#### `--severity <level>`
Only show issues at or above this level.
- **Options**: `critical`, `high`, `medium`, `low`

---

### File Filtering (Extended)

#### `--max-file-size <lines>`
Skip files larger than N lines.
- **Default**: Unlimited

#### `--skip-generated`
Automatically skip generated files.
- **Default**: `true`
- **Patterns**: `*.pb.go`, `*_generated.*`, `dist/`, `build/`

---

### Advanced Options

#### `--review-rules <path>`
Custom review rules YAML file.
- **Default**: `.warden-rules.yml` (if exists)

#### `--diff-context <lines>`
Lines of context in diffs.
- **Default**: `3`

#### `--incremental-review`
Only review files changed since last Warden run.
- **Default**: `false`

#### `--include-drafts`
Include draft PRs in review.
- **Default**: `false`

#### `--draft-strategy <strategy>`
How to handle draft PRs.
- **Default**: `review-only`
- **Options**: `review-only`, `fix`, `skip`

#### `--baseline-commit <sha>`
Review changes since this commit.
- **Example**: `--baseline-commit abc123`

---

## Removed from v1.2

The following parameters were removed to simplify the API and avoid premature optimization. They may return in v2.0 based on real-world demand.

### Caching (7 parameters removed)
**Rationale**: Premature optimization. Implement with smart defaults when needed.
- `--cache-pr-data <seconds>`
- `--cache-location <path>`
- `--cache-analysis`
- `--cache-ttl <seconds>` (not in v1.1, speculative)
- And related caching params

**Alternative**: Warden will implement intelligent caching transparently when beneficial.

---

### Integration Hooks (3 parameters removed)
**Rationale**: YAGNI for v1.2. These add complexity without proven demand.
- `--notify-slack <webhook>`
- `--update-jira <ticket-id>`
- `--webhook <url>`

**Alternative**: For v1.2, use `--output-format json` and pipe to external tools. May return in v2.0.

---

### Review Over-Parameterization (8 parameters removed)
**Rationale**: Consolidated into single `--reviewers` parameter for natural language expressibility.

Removed:
- `--review-depth <standard|thorough|comprehensive>`
- `--reviewer-count <n>`
- `--review-focus <area>`
- And related review configuration params

**Alternative**: Use `--reviewers security,performance,testing` or natural language ("use comprehensive review").

---

### Testing (2 parameters removed)
**Rationale**: Should always test before pushing; test commands discovered from repo docs.

Removed:
- `--test-before-fix` - Tests always run before pushing (validation sequence)
- `--test-command <command>` - Discovered from CLAUDE.md, CI config, or language defaults

**Alternative**: See [docs/COMMANDS.md](COMMANDS.md) for command discovery process.

---

### Other Removals
- `--save-metrics <path>` - Premature optimization, no proven use case
- `--respect-rate-limits` - Always respected, no need for flag
- `--max-parallel-agents <n>` - Calculated automatically based on reviewers × PRs

---

## Parameter Precedence

When multiple parameters conflict:

1. `--focus-paths` applied before `--ignore-paths`
2. `--dry-run` disables all fix operations
3. `--test-strategy none` overrides `--test-on-severity`

---

## Migration from v1.1

If you were using removed parameters:

| Old (v1.1) | New (v1.2) |
|------------|------------|
| `--review-depth thorough` | `--reviewers security,performance` |
| `--reviewer-count 3` | `--reviewers security,performance,architecture` |
| `--test-command "npm test"` | Add to CLAUDE.md: `Test: \`npm test\`` |
| `--cache-pr-data 3600` | Removed (smart defaults) |
| `--notify-slack <url>` | Use `--output-format json \| your-script` |

---

## See Also

- **Command discovery**: [COMMANDS.md](COMMANDS.md)
- **Workflow details**: [WORKFLOW.md](WORKFLOW.md)
- **Natural language examples**: See README.md
