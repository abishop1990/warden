# Workflow

**TL;DR**: Analyze existing PRs → Identify issues → Fix by tier → Validate → Push → Cleanup

## Phase 1: Discovery

Batch fetch existing open PRs:
```bash
gh pr list --author @me --state open --json number,title,statusCheckRollup --limit 10
```

## Phase 2: Analysis (Parallel)

For each PR, launch parallel subagents to analyze **three issue sources**:

**Subagent A**: Analyze CI failures (test failures, build errors, lint issues)
**Subagent B**: Analyze review comments (requested changes, unresolved feedback)
**Subagent C-E**: Code quality review (security, performance, architecture)

**Context gathered**:
1. PR description → Understand intent
2. Repo AI instructions (CLAUDE.md, etc.) → Conventions + **build/test commands**
3. Codebase overview → Architecture

**Command discovery**:
```bash
# Extract from CLAUDE.md
BUILD_CMD=$(grep "Build:" CLAUDE.md | grep '`' | tr -d '`')
TEST_CMD=$(grep "Test:" CLAUDE.md | grep '`' | tr -d '`')

# Fallback to CI configs, Makefile, package.json
# See COMMANDS.md for details
```

## Phase 3: Planning

Aggregate findings, deduplicate, sort by severity (Critical → High → Medium → Low)

## Phase 4: User Interaction

Present report combining all three issue sources, ask what to fix:
```
PR #123: Fix authentication

Critical (2):
  [CI] SQL injection in login endpoint
  [Review] Missing auth check per @reviewer

High (3):
  [CI] Test failure: race condition in session handler
  [Review] Unvalidated user input per @security-team
  [Code] Missing error handling in payment flow

Fix: 1) All Critical+High  2) Critical only  3) Skip
```

## Phase 5: Execution

**Per-PR loop**:

```
FOR EACH PR:

  1. Create temp workspace: /tmp/pr-review-${PR_NUMBER}-${TIMESTAMP}/
  2. Clone repo, checkout PR branch
  3. FOR EACH TIER (Critical → High → Medium → Low):
       a. Apply fixes
       b. Validate: Build → Lint → Format → Test
       c. If pass: Commit → Push
       d. If fail: Rollback, skip tier
  4. Cleanup workspace
  5. Next PR
```

**Validation sequence** (see VALIDATION-ORDER.md):
```bash
$BUILD_CMD  || { rollback; exit 1; }
$LINT_CMD   || { rollback; exit 1; }
$FORMAT_CMD
$TEST_CMD   || { rollback; exit 1; }
git commit && git push
```

**Workspace isolation**:
- Each PR: Own temp directory
- User's working directory: Never touched
- Immediate cleanup after each PR

## Phase 6: Summary

```
Total PRs: 5 | Fixed: 3 | Skipped: 2
Issues Fixed: Critical(4), High(7), Medium(3)
CI Status: PR#123 ✓, PR#125 ✓, PR#127 pending
```

## Key Points

- Works on **existing PRs** (not creating new ones)
- Discovers commands from repo docs (not hard-coded)
- Validates **before** pushing (prevents CI failures)
- Isolated workspaces (never touches your working dir)
- Sequential PR processing (one at a time)

See also: [VALIDATION-ORDER.md](VALIDATION-ORDER.md), [COMMANDS.md](COMMANDS.md)
