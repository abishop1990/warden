# Warden - Quick Start (5 Minutes)

Get started with Warden in 5 minutes or less.

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- AI coding assistant (Claude Code, GitHub Copilot, or Cursor)
- Warden repository in your workspace/directory

## How It Works

1. **Open the Warden repository** in your editor/workspace
2. **AI reads the instructions** (CLAUDE.md, .cursorrules, or copilot-instructions.md)
3. **Say "Run Warden"** explicitly
4. **AI executes the workflow** automatically

## Basic Usage

### 1. Review Your PRs (Default Settings)

```
"Run the Warden skill"
"Execute Warden on my open PRs"
```

This runs with safe defaults:
- Standard review depth (1 generalist reviewer)
- Tests affected packages only
- Balanced fix strategy
- Auto-commit on success

### 2. Preview Without Fixes (Dry Run)

```
"Run Warden in dry-run mode"
"Execute Warden without making changes to preview issues"
```

### 3. Security-Focused Review

```
"Run Warden with security and testing reviewers, use full test suite"
```
→ Uses: `--reviewers security,testing --test-strategy full`

### 4. Fast Review (Documentation PRs)

```
"Run Warden and skip tests for doc-only changes"
```
→ Uses: `--test-strategy none`

## Common Scenarios

### Scenario 1: Quick Daily Review
```
"Run Warden quietly with affected tests only"
```
→ Uses: `--quiet --test-strategy affected`

### Scenario 2: Production Code Review
```
"Run Warden with conservative fixes, full tests, and review before pushing"
```
→ Uses: `--fix-strategy conservative --test-strategy full --require-review-before-push`

### Scenario 3: Fix Specific PR
```
"Run Warden on PR #123"
"Execute Warden to fix PR #456"
```

### Scenario 4: Comprehensive Audit
```
"Run Warden with security, performance, and architecture reviewers, full test suite, conservative fixes"
```
→ Uses: `--reviewers security,performance,architecture --test-strategy full --fix-strategy conservative`

## What Warden Does

1. **Discovers PRs** - Finds your open pull requests
2. **Analyzes Three Sources**:
   - CI failures (test failures, build errors)
   - Review comments (requested changes)
   - Code quality (security, performance issues)
3. **Prioritizes** - Sorts by severity (Critical → High → Medium → Low)
4. **Asks Permission** - Shows you what it found, asks what to fix
5. **Fixes & Validates**:
   - Applies fixes
   - Runs: Build → Lint → Format → Test
   - Only commits if ALL validations pass
6. **Pushes Changes** - Updates the PR with fixes
7. **Reports** - Shows summary of what was fixed

## Key Features

- ✅ **Works on existing PRs** - Not creating new ones
- ✅ **Discovers commands from your repo** - Reads CLAUDE.md, CI configs for build/test commands
- ✅ **Validates before pushing** - Build + Lint + Test must pass
- ✅ **Isolated workspaces** - Never touches your working directory
- ✅ **Incremental fixes** - Fix by severity tier, rollback if tests fail

## Parameters

You can specify parameters in natural language. The AI understands:

**Review depth**:
- "Use security and performance reviewers"
- "Run comprehensive review with all specialists"

**Test strategy**:
- "Use full test suite"
- "Test affected packages only"
- "Skip tests"

**Fix strategy**:
- "Use conservative fixes"
- "Be aggressive with fixes"
- "Balanced approach"

**Safety**:
- "Require review before pushing"
- "Create rollback branch"
- "Protect main and master branches"

See [PARAMETERS.md](docs/PARAMETERS.md) for all 50+ options.

## Next Steps

- **Detailed workflow**: [WORKFLOW.md](docs/WORKFLOW.md)
- **All parameters**: [PARAMETERS.md](docs/PARAMETERS.md)
- **Safety features**: [SAFETY.md](docs/SAFETY.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Remember

Always say **"Run Warden"** or **"Execute the Warden skill"** so the AI knows to use this specific workflow!
