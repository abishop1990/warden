# Warden - Quick Start (5 Minutes)

Get started with Warden in 5 minutes or less.

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Git repository with open pull requests

## Basic Usage

### 1. Review Your PRs (Default Settings)

```bash
# Review all your open PRs with standard settings
warden
```

This runs with safe defaults:
- Standard review depth (1 generalist reviewer)
- Test affected packages only
- Balanced fix strategy
- Auto-commit on success

### 2. Preview Without Fixes (Dry Run)

```bash
# See what issues Warden finds without making changes
warden --dry-run
```

### 3. Security-Focused Review

```bash
# Deep security review with full test suite
warden --reviewers security,testing --test-strategy full
```

### 4. Fast Review (Documentation PRs)

```bash
# Skip tests for doc-only changes
warden --test-strategy none
```

## Common Scenarios

### Scenario 1: Quick Daily Review
```bash
warden --quiet --test-strategy affected
```

### Scenario 2: Pre-Release Security Audit
```bash
warden \
  --reviewers security,performance,architecture \
  --test-strategy full \
  --fix-strategy conservative \
  --comment-on-pr
```

### Scenario 3: Fix Critical Issues Only
```bash
warden \
  --test-on-severity critical \
  --max-fixes-per-tier 5
```

## Key Parameters (Most Used)

| Parameter | What It Does | Example |
|-----------|--------------|---------|
| `--dry-run` | Preview only, no fixes | `warden --dry-run` |
| `--reviewers` | Choose specialists | `--reviewers security,performance` |
| `--test-strategy` | How to test | `--test-strategy none\|affected\|full` |
| `--fix-strategy` | Fix aggressiveness | `--fix-strategy conservative` |
| `--comment-on-pr` | Post findings to PR | `--comment-on-pr` |
| `--quiet` | Minimal output | `--quiet` |

## Understanding Output

Warden provides a summary after each run:

```
PR Review Summary
=================
Total PRs Analyzed: 3
Total PRs Fixed: 2

Issues Fixed by Severity:
  Critical: 2
  High: 5
  Medium: 3

CI Status:
  ✓ PR #123: All checks passing
  ✓ PR #125: All checks passing
```

## What Happens When You Run Warden?

1. **Discovery**: Lists your open PRs
2. **Analysis**: Reviews code, CI failures, comments (in parallel)
3. **Planning**: Prioritizes issues by severity
4. **User Interaction**: Asks which issues to fix
5. **Execution**: Fixes issues, tests, commits, pushes (by severity tier)
6. **Summary**: Shows results and next steps

## Safety Features

Warden is safe by default:
- ✅ Works in temporary workspace (never modifies your working directory)
- ✅ Tests before committing (rollback if tests fail)
- ✅ Per-tier commits (doesn't lose good fixes if later tier fails)
- ✅ Verifies correct PR branch before pushing
- ✅ Asks before fixing each PR

## Next Steps

- **Full parameter reference**: See [docs/PARAMETERS.md](docs/PARAMETERS.md)
- **Detailed workflow**: See [docs/WORKFLOW.md](docs/WORKFLOW.md)
- **More examples**: See [docs/EXAMPLES.md](docs/EXAMPLES.md)
- **Troubleshooting**: See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Safety features**: See [docs/SAFETY.md](docs/SAFETY.md)

## Getting Help

- **Platform-specific docs**:
  - Claude Code: [CLAUDE.md](CLAUDE.md)
  - GitHub Copilot: [.github/copilot-instructions.md](.github/copilot-instructions.md)
  - Cursor: [.cursorrules](.cursorrules)
- **General guidance**: [AGENTS.md](AGENTS.md)
- **Issues**: https://github.com/abishop1990/warden/issues

## Default Behavior

Without any parameters, Warden:
- Reviews PRs by current user
- Uses 1 generalist reviewer (standard depth)
- Tests only affected packages
- Uses balanced fix strategy
- Auto-commits when tests pass
- Processes up to 10 PRs
- Shows results in terminal

**Safe to try!** Start with `warden --dry-run` to see what it would do.
