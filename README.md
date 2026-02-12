# Warden - PR Review and Fix

Cross-platform AI skill for comprehensive automated PR review and fixes.

## Overview

Warden is an AI coding assistant skill that analyzes CI failures, review comments, and code quality, then helps fix identified issues. It works across multiple AI platforms:

- **Claude Code** - Anthropic's AI pair programmer
- **GitHub Copilot** - GitHub's AI assistant
- **Cursor** - AI-first code editor
- **Codex** - And other AI coding tools

## Features

- **Massively Parallel Analysis**: Analyzes multiple PRs simultaneously with specialized agents
- **CI/CD Integration**: Detects and diagnoses test failures, build errors, and lint issues
- **Review Comment Analysis**: Identifies unresolved feedback requiring action
- **Staff Engineer-Level Review**: Deep code quality analysis for logic errors, security, performance, and best practices
- **Incremental Fixes**: Fixes and validates Critical issues before moving to lower severity
- **Multi-Language Support**: Adapts to Go, Python, JavaScript/TypeScript, Rust, and more
- **Optimized Workspaces**: Shallow clones and smart caching for speed

## Usage

### Claude Code
```
Review and fix PRs using the pr-review-and-fix workflow
```

### GitHub Copilot
```
@copilot /pr-review-and-fix
```

### Cursor
```
Review and fix PRs using the pr-review-and-fix workflow
```

### Optional Parameters
- `--author <username>` - Review PRs by specific author (defaults to current user)
- `--repo <owner/repo>` - Target specific repository (defaults to current)
- `--state open|all` - PR state to review (defaults to open)
- `--limit <n>` - Max number of PRs to review (defaults to 10)
- `--dry-run` - Preview issues without making fixes
- `--severity critical|high|medium|low` - Only show issues at or above this level
- `--review-depth standard|thorough|comprehensive` - Review thoroughness (defaults to standard)
  - `standard`: One generalist reviewer (faster, recommended for most PRs)
  - `thorough`: Two reviewers - security + performance focused (for sensitive code)
  - `comprehensive`: Three reviewers - security + performance + architecture (for core infrastructure)

## Workflow

### Phase 1: Discovery (Optimized)

Use batch GitHub API queries for efficiency:

```bash
# Single batch query with JSON output
gh pr list --author @me --state open --json number,title,statusCheckRollup,reviewDecision --limit 10
```

1. Fetch all PR data in one batch API call (number, title, CI status, review status)
2. Parse JSON and display formatted summary table
3. Ask user which PRs to analyze (or "all")

**Optimization**: Single API call instead of N sequential calls for N PRs.

### Phase 2: Analysis (Massively Parallel with Context)

**Key Optimization**: Launch ALL subagents for ALL PRs in parallel, not sequentially.

**Critical Context Gathering** (per PR, before analysis):

1. **PR Metadata** (understand intent):
   ```bash
   gh pr view <pr-number> --json title,body,author,createdAt,additions,deletions
   ```
   - What is this PR trying to accomplish?
   - Why were these changes made?
   - What context did the author provide?

2. **Repository AI Instructions** (understand project conventions):
   ```bash
   # Platform-dependent: read the repo's AI guidance
   # Claude Code: Read CLAUDE.md, AGENTS.md
   # Cursor: Read .cursorrules, .cursor/rules/*.md
   # GitHub Copilot: Read .github/copilot-instructions.md
   ```
   - Project-specific conventions
   - Technology stack and patterns
   - Code style and review criteria
   - Known issues or technical debt

3. **Codebase Context** (understand architecture):
   ```bash
   # Read key files for context
   cat README.md                    # Project overview
   cat package.json || cat go.mod   # Dependencies and scripts
   cat .github/workflows/*.yml      # CI/CD setup

   # Get project structure
   find . -type f -name "*.go" -o -name "*.py" -o -name "*.ts" | head -50
   ```

**For Each PR** (all in parallel):

**Subagent A: CI Analysis**
- Fetch CI status: `gh pr checks <pr-number> --json name,status,conclusion,detailsUrl`
- If failed, fetch logs from failed checks
- Identify failure patterns: test failures, lint errors, build errors, timeouts
- Extract error messages, file paths, line numbers
- Categorize by type and affected components

**Subagent B: Review Comments Analysis**
- Fetch all comments: `gh pr view <pr-number> --json reviews,comments`
- Identify unresolved threads and requested changes
- Extract actionable feedback vs discussion
- Categorize: bugs, style, performance, security, architecture
- Link comments to specific code locations

**Subagent C/D/E: Code Quality Review** (depth-dependent):

**Standard** (1 reviewer - generalist):
- **Staff Engineer Review**: Broad coverage across all areas
  - Fetch PR diff: `gh pr diff <pr-number>`
  - **Context**: PR description, repo AI instructions, codebase overview
  - Analyze with intent in mind: Does code match PR purpose?
  - Logic errors and edge cases
  - Security issues (injection, XSS, auth)
  - Performance problems
  - Best practices violations
  - Missing tests and documentation
  - Focus on high-signal issues only

**Thorough** (2 reviewers - specialists):
- **Security Reviewer**: Deep security focus
  - OWASP Top 10 vulnerabilities
  - Authentication and authorization flaws
  - Input validation and sanitization
  - Cryptography misuse
  - Secrets management
  - Dependency vulnerabilities

- **Performance Reviewer**: Deep performance focus
  - N+1 query problems
  - Memory leaks and resource exhaustion
  - Algorithmic complexity issues
  - Caching opportunities
  - Database query optimization
  - Unnecessary allocations

**Comprehensive** (3 reviewers - full coverage):
- **Security Reviewer** (as above)
- **Performance Reviewer** (as above)
- **Architecture Reviewer**: Deep design focus
  - Design patterns and anti-patterns
  - Code coupling and cohesion
  - SOLID principles violations
  - Maintainability concerns
  - Scalability issues
  - Technical debt introduction
  - API design and contracts

**Platform-Specific Execution**:
- **Claude Code**: Use 3-5 parallel `general-purpose` agents per PR (depending on review depth)
- **GitHub Copilot**: Leverage `@github` for native PR integration
- **Cursor**: Use Composer mode for multi-file analysis

### Phase 3: Planning (Structured Aggregation)

**Platform-Specific Approach**:

**Claude Code**: Use Plan agent for aggregation
**Others**: Manual aggregation in main agent

1. **Collect findings** from all Phase 2 subagents
2. **Deduplicate** issues across CI, reviews, and code analysis
3. **Enrich** each issue with:
   - Severity (Critical/High/Medium/Low)
   - Fix complexity (Simple/Moderate/Complex)
   - Estimated risk
   - Affected files and line numbers
4. **Group** related issues that should be fixed together
5. **Sort** by: Severity DESC, then Complexity ASC (fix easy Critical issues first)
6. **Generate** structured report per PR with clear action items

**Deduplication Rules**:
- Same file + line number + similar message = duplicate
- CI failure + review comment on same line = single issue with dual evidence
- Related errors in same function = group together

### Phase 4: User Interaction

For each PR, present structured report and ask:

```
PR #123: Fix authentication middleware

Critical Issues (2):
  [C1] SQL injection vulnerability in login endpoint (auth.go:45)
  [C2] Missing authentication check in /admin routes (routes.go:23)

High Issues (3):
  [H1] Race condition in session handler (session.go:67)
  [H2] Unvalidated user input (profile.go:89)
  [H3] Missing error handling in payment flow (payment.go:34)

Medium Issues (5): [collapsed, expand to see]

What would you like to fix?
  1. All Critical + High (recommended)
  2. All Critical only
  3. Select specific issues
  4. Skip this PR
```

### Phase 5: Execution (Incremental with Validation)

**Key Optimization**: Fix by severity tier, validate, push, then continue.

For each PR with selected fixes:

**5.1 Setup Workspace** (Optimized)
```bash
# Use shallow clone for speed
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Shallow clone (faster) - only fetch PR branch with depth=1
gh repo clone owner/repo . -- --depth=1 --single-branch --branch pr-branch

# OR if PR number:
gh repo clone owner/repo . -- --depth=1
git fetch --depth=1 origin pull/${PR_NUMBER}/head:pr-${PR_NUMBER}
git checkout pr-${PR_NUMBER}
```

**5.2 Incremental Fix Strategy** (Critical → High → Medium → Low)

For each severity tier:

1. **Fix all issues at this tier**
   - Simple fixes (1-5 lines): Direct edits
   - Moderate fixes (5-20 lines): Use appropriate subagent
   - Complex fixes (20+ lines, multi-file): Use specialized subagent or flag for manual review

2. **Run targeted tests**
   ```bash
   # Identify affected packages from changed files
   git diff --name-only origin/main | xargs <language-specific-test-cmd>

   # Examples:
   # Go: go test ./path/to/package/...
   # Python: pytest path/to/package/
   # JS: npm test -- path/to/package
   ```

3. **Run formatting** (language-specific)
   ```bash
   # Only format changed files, not entire codebase
   git diff --name-only origin/main | xargs <formatter>
   ```

4. **Verify no unintended changes**
   ```bash
   git diff
   ```

5. **Commit if tests pass**
   ```bash
   git commit -m "[PR #${PR_NUMBER}] Fix: ${SEVERITY} - ${DESCRIPTION}

   Fixed ${ISSUE_COUNT} ${SEVERITY} severity issues:
   - ${ISSUE_1_SUMMARY}
   - ${ISSUE_2_SUMMARY}

   Tested: ${AFFECTED_PACKAGES}

   Co-Authored-By: Warden <noreply@warden.dev>"
   ```

6. **Push and verify**
   ```bash
   git push origin pr-${PR_NUMBER}

   # Wait briefly for CI to start
   sleep 5
   gh pr checks ${PR_NUMBER} --watch
   ```

7. **If tests fail, rollback tier**
   ```bash
   git reset --hard HEAD~1
   # Flag issues for manual review
   # Continue to next tier only if current tier succeeded
   ```

**Platform-Specific Subagent Selection**:

**Claude Code**:
- Simple fixes: Direct edits in main agent
- Moderate fixes: `Bash` agent for scripted changes
- Complex fixes: `general-purpose` agent
- Multi-file refactors: `general-purpose` agent with clear file list

**Cursor**:
- Use Composer mode for multi-file edits
- Leverage codebase context for cross-file dependencies

**GitHub Copilot**:
- Use inline suggestions for simple fixes
- Chat mode for moderate complexity
- Workspace mode for complex changes

**5.3 Cleanup** (Background)
```bash
# Cleanup in background to not block next PR
(cd / && rm -rf "$WORKSPACE") &
```

### Phase 6: Summary Report

Provide comprehensive summary with metrics:

```
PR Review Summary
=================

Total PRs Analyzed: 5
Total PRs Fixed: 3
Total PRs Skipped: 2

Issues Fixed by Severity:
  Critical: 4
  High: 7
  Medium: 3
  Low: 0

Issues Fixed by Category:
  Security: 6
  Bugs: 5
  Performance: 2
  Code Quality: 1

CI Status:
  ✓ PR #123: All checks passing
  ✓ PR #125: All checks passing
  ⚠ PR #127: 1 check pending

Manual Review Required:
  PR #129: Complex refactor flagged (auth system overhaul)
  PR #131: Merge conflict detected

Next Steps:
  1. Monitor CI for PR #127
  2. Manually review flagged issues in PR #129
  3. Resolve merge conflict in PR #131
```

## Implementation Notes

### Subagent Selection Criteria

**Simple Fix** (1-5 lines, single file):
- No subagent needed
- Direct edit in main agent

**Moderate Fix** (5-20 lines, 1-2 files):
- **Claude Code**: `Bash` agent for scripted changes
- **Others**: Main agent with focused context

**Complex Fix** (20+ lines, multiple files, or requires analysis):
- **Claude Code**: `general-purpose` agent
- **Cursor**: Composer mode
- **Copilot**: Chat/workspace mode

**Flag for Manual Review** when:
- Architectural changes required
- Security-critical code paths
- Fix impacts >5 files
- Requires domain knowledge
- Estimated risk is High

### Workspace Optimization

**Shallow Clones**:
```bash
# 10-100x faster for large repos
gh repo clone owner/repo . -- --depth=1 --single-branch --branch pr-branch
```

**Workspace Reuse** (same repo):
```bash
# If fixing multiple PRs from same repo, reuse workspace
if [ -d "/tmp/pr-review-cache/owner-repo" ]; then
  cd "/tmp/pr-review-cache/owner-repo"
  git fetch origin pull/${PR_NUMBER}/head:pr-${PR_NUMBER}
  git checkout pr-${PR_NUMBER}
else
  # Fresh clone
fi
```

**Background Cleanup**:
```bash
# Non-blocking cleanup
(sleep 1 && rm -rf "$WORKSPACE") &
```

### Testing Strategy (Targeted)

**Only test affected code**:

```bash
# Identify changed packages
CHANGED_FILES=$(git diff --name-only origin/main)

# Go: Extract package paths
PACKAGES=$(echo "$CHANGED_FILES" | grep '\.go$' | xargs -n1 dirname | sort -u)
for pkg in $PACKAGES; do
  go test -v ./$pkg
done

# Python: Test only changed modules
MODULES=$(echo "$CHANGED_FILES" | grep '\.py$' | xargs -n1 dirname | sort -u)
for mod in $MODULES; do
  pytest $mod -v
done

# JavaScript: Use Jest's changed files mode
npm test -- --changedSince=origin/main
```

### Error Handling

**Graceful Degradation**:
- CI logs unavailable → Skip CI analysis, proceed with review analysis
- Review comments API fails → Skip review analysis, proceed with code analysis
- Test failures → Rollback changes for that severity tier, continue to next PR

**Rollback Strategy**:
- Per-tier rollback: If High severity fixes fail tests, rollback High tier only
- Full rollback: If Critical fixes fail, abort PR and flag for manual review
- Selective rollback: If specific issue fix causes failure, rollback that commit only

**Continue on Failure**:
- If PR #1 fails, continue to PR #2
- Collect all failures for summary report
- Never leave workspace in dirty state

## Language-Specific Adaptations

### Go Projects
- Formatting: `gofmt -s -w $(git diff --name-only origin/main | grep '\.go$')`
- Testing: `go test -v ./$(dirname $(git diff --name-only origin/main | grep '\.go$'))/...`
- Linting: `golangci-lint run $(git diff --name-only origin/main | grep '\.go$')`
- Build verification: `go build ./...`

### Python Projects
- Formatting: `black $(git diff --name-only origin/main | grep '\.py$')`
- Testing: `pytest $(dirname $(git diff --name-only origin/main | grep '\.py$')) -v`
- Linting: `ruff check $(git diff --name-only origin/main | grep '\.py$')`
- Type checking: `mypy $(git diff --name-only origin/main | grep '\.py$')`

### JavaScript/TypeScript Projects
- Formatting: `prettier --write $(git diff --name-only origin/main | grep -E '\.(js|ts|jsx|tsx)$')`
- Testing: `npm test -- --changedSince=origin/main`
- Linting: `eslint $(git diff --name-only origin/main | grep -E '\.(js|ts|jsx|tsx)$')`
- Type checking: `tsc --noEmit`

### Rust Projects
- Formatting: `cargo fmt -- $(git diff --name-only origin/main | grep '\.rs$')`
- Testing: `cargo test --package $(cargo metadata --format-version 1 | jq -r '.packages[] | select(.targets[].src_path | IN($(git diff --name-only origin/main))) | .name')`
- Linting: `cargo clippy -- -D warnings`
- Build verification: `cargo build`

## Platform-Specific Optimizations

### Claude Code

**Subagent Usage**:
- **Phase 1**: Main agent (batch API call)
- **Phase 2**: 3-5x `general-purpose` agents per PR (parallel, depth-dependent)
  - Standard: 3 agents (CI + Reviews + Code Quality)
  - Thorough: 4 agents (CI + Reviews + Security + Performance)
  - Comprehensive: 5 agents (CI + Reviews + Security + Performance + Architecture)
- **Phase 3**: `Plan` agent for aggregation
- **Phase 5 (simple)**: Main agent
- **Phase 5 (moderate)**: `Bash` agent
- **Phase 5 (complex)**: `general-purpose` agent

**Parallel Execution** (Standard depth):
```
# For 3 PRs, launch all 9 analysis agents at once
Task(general-purpose, "Analyze CI for PR #123")
Task(general-purpose, "Analyze reviews for PR #123")
Task(general-purpose, "Code review PR #123 with context: PR description + CLAUDE.md + codebase overview")
Task(general-purpose, "Analyze CI for PR #125")
Task(general-purpose, "Analyze reviews for PR #125")
Task(general-purpose, "Code review PR #125 with context: PR description + CLAUDE.md + codebase overview")
Task(general-purpose, "Analyze CI for PR #127")
Task(general-purpose, "Analyze reviews for PR #127")
Task(general-purpose, "Code review PR #127 with context: PR description + CLAUDE.md + codebase overview")
```

**Parallel Execution** (Comprehensive depth):
```
# For 3 PRs, launch all 15 analysis agents at once
Task(general-purpose, "Analyze CI for PR #123")
Task(general-purpose, "Analyze reviews for PR #123")
Task(general-purpose, "Security review PR #123 with context")
Task(general-purpose, "Performance review PR #123 with context")
Task(general-purpose, "Architecture review PR #123 with context")
# ... repeat for PR #125 and #127
```

### GitHub Copilot

**Native Integration**:
- Use `@github` mention for PR operations
- Leverage GitHub Actions integration for CI insights
- Use `gh` CLI for all GitHub operations

**Batch Operations**:
```
@github show me CI failures, review comments, and code issues for PRs #123, #125, #127
```

### Cursor

**Composer Mode**:
- Use Composer for multi-file edits in Phase 5
- Leverage codebase-wide context for cross-file dependencies
- Use Rules for language-specific conventions

**Multi-file Edits**:
- Select all affected files before initiating fixes
- Use "Apply to all" for similar patterns across files

## Performance Metrics

**Expected Timings** (for 3 PRs, ~500 lines changed each):

| Phase | Sequential | Optimized (Standard) | Optimized (Thorough) | Optimized (Comprehensive) |
|-------|-----------|----------------------|----------------------|---------------------------|
| Phase 1 | 6s | 2s | 2s | 2s |
| Phase 2 | 90s | 40s | 50s | 60s |
| Phase 3 | 15s | 10s | 15s | 20s |
| Phase 5 | 180s | 120s | 120s | 120s |
| **Total** | **291s** | **172s** | **187s** | **202s** |
| **Speedup** | — | **1.7x faster** | **1.6x faster** | **1.4x faster** |

**Review Depth Trade-offs**:
- **Standard** (default): Fastest, good for most PRs, broad coverage
- **Thorough**: 15s slower, better for security-sensitive or performance-critical code
- **Comprehensive**: 30s slower, best for core infrastructure or architectural changes

**Optimization Impact**:
- Parallel subagents: 2.5x faster Phase 2
- Contextual review: Higher quality findings (PR description + repo conventions + codebase context)
- Shallow clones: 5-10x faster workspace setup
- Targeted testing: 3-5x faster test execution
- Batch API calls: 3x faster Phase 1

## Platform Configuration

Warden automatically works with your AI assistant through platform-specific configuration files:
- Claude Code reads `CLAUDE.md` and `AGENTS.md`
- Cursor reads `.cursorrules` and `AGENTS.md`
- GitHub Copilot reads `.github/copilot-instructions.md`

## Future Enhancements
- Workspace caching across invocations
- Integration with project management tools (Aha, Jira, Linear)
- Learning from fix acceptance rates
- Customizable review rules per repo
- Auto-comment on PRs with summary
- Historical pattern analysis
- Code owner integration
- Notification integrations (Slack, email, Discord)

## Contributing

Contributions welcome! This is an open-source skill designed to work across all AI coding assistants.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Version

**2.0.0** - Optimized release with parallel execution, incremental fixes, and platform-specific enhancements
