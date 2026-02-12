---
name: pr-review-and-fix
description: Comprehensive automated PR review that analyzes CI failures, review comments, and code quality, then helps fix identified issues
version: 1.0.0
platforms:
  - claude-code
  - github-copilot
  - cursor
  - codex
tags:
  - pr-review
  - code-quality
  - ci-analysis
  - automated-fixes
---

# PR Review and Fix Skill

## Overview
Comprehensive automated PR review that analyzes CI failures, review comments, and code quality, then helps fix identified issues.

## Usage

### Claude Code
```
Use the pr-review-and-fix skill to review and fix PRs
```

### GitHub Copilot
```
@copilot /pr-review-and-fix
```

### Cursor / Other AI Assistants
```
Review and fix PRs using the pr-review-and-fix workflow
```

### Optional parameters:
- `--author <username>` - Review PRs by specific author (defaults to current user)
- `--repo <owner/repo>` - Target specific repository (defaults to current)
- `--state open|all` - PR state to review (defaults to open)
- `--limit <n>` - Max number of PRs to review (defaults to 10)

## Workflow

### Phase 1: Discovery
1. List all PRs matching criteria (author, repo, state)
2. Display summary table with PR number, title, CI status, review status
3. Ask user which PRs to analyze (or "all")

### Phase 2: Analysis (Parallel)
For each selected PR, launch parallel analysis using subagents:

**Subagent A: CI Analysis** (task agent)
- Check CI/CD status for the PR
- If failed, fetch logs and identify failure reasons
- Categorize failures: test failures, lint errors, build errors, etc.
- Extract specific error messages and file locations

**Subagent B: Review Comments Analysis** (explore agent)
- Fetch all review comments (including resolved)
- Identify unresolved comments requiring action
- Categorize comments: bugs, style, performance, security, etc.
- Extract specific code locations mentioned

**Subagent C: Staff Engineer Review** (code-review agent)
- Perform deep code review looking for:
  - Logic errors and edge cases
  - Performance issues
  - Security vulnerabilities
  - Design patterns and best practices
  - Code maintainability
  - Missing tests
  - Documentation gaps
- Focus on high-signal issues only (not style/formatting)

### Phase 3: Planning
1. Aggregate all findings from subagents
2. Deduplicate issues across sources
3. Prioritize by severity: Critical > High > Medium > Low
4. Group related issues that can be fixed together
5. Present structured recommendation list per PR with severity indicators

### Phase 4: User Interaction
For each PR, ask user what to fix:
- All Critical + High
- All Critical only
- Select specific issues
- Skip this PR

### Phase 5: Execution
For each PR with selected fixes:

1. **Setup**
   - Create temporary workspace: `/tmp/pr-review-{pr-number}-{timestamp}`
   - Clone repository and checkout PR branch

2. **Fix Issues** (in order: Critical → High → Medium → Low)
   - Use appropriate subagent based on complexity
   - Make minimal, surgical changes
   - Run language-specific formatting (e.g., `gofmt -s -w .` for Go)
   - Run relevant unit tests
   - Only commit if tests pass

3. **Commit Strategy**
   - One commit per logical fix or group
   - Format: `[PR #{number}] Fix: {description}`
   - Include context: what was fixed, why, what was tested

4. **Push and Verify**
   - Push commits to PR branch
   - Monitor CI status briefly
   - Report outcome

5. **Cleanup**
   - Remove temporary workspace

### Phase 6: Summary Report
Provide comprehensive summary:
- How many PRs analyzed/fixed/skipped
- Issues fixed by category
- CI status updates
- Next steps and items needing manual attention

## Implementation Notes

### Temporary Workspace Management
```bash
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
gh repo clone owner/repo .
git fetch origin pull/${PR_NUMBER}/head:pr-${PR_NUMBER}
git checkout pr-${PR_NUMBER}
# Work...
cd / && rm -rf "$WORKSPACE"
```

### Subagent Usage (Claude Code Specific)

**task agent** - Test running, CI log analysis
**explore agent** - Code searching, review comment analysis
**code-review agent** - Deep code quality review (report only)
**general-purpose agent** - Complex multi-file fixes

### Testing Strategy
1. Identify affected packages from changed files
2. Run language-specific tests (e.g., `go test -v <package>` for Go)
3. Run formatting tools (e.g., `gofmt -s -w .` for Go)
4. Verify no unintended changes: `git diff`
5. Only commit if all tests pass

### Error Handling
- Graceful degradation if CI logs unavailable
- Rollback options for failed fixes
- Flag complex issues for manual review
- Continue with other PRs if one fails

## Language-Specific Adaptations

### Go Projects
- Formatting: `gofmt -s -w .`
- Testing: `go test -v <package>`
- Linting: `golangci-lint run`

### Python Projects
- Formatting: `black .` or `ruff format`
- Testing: `pytest <path>` or `python -m pytest`
- Linting: `ruff check` or `pylint`

### JavaScript/TypeScript Projects
- Formatting: `prettier --write .`
- Testing: `npm test` or `yarn test`
- Linting: `eslint .`

### Rust Projects
- Formatting: `cargo fmt`
- Testing: `cargo test`
- Linting: `cargo clippy`

## Future Enhancements
- Multiple repository support in single run
- Integration with project management tools (Aha, Jira, Linear)
- Learning from fix acceptance rates
- Customizable review rules per repo
- Dry-run mode
- Auto-comment on PRs with summary
- Historical pattern analysis
- Code owner integration
- Notification integrations (Slack, email, Discord)
