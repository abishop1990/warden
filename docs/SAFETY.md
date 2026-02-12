# Warden - Safety Features

Warden includes multiple safety mechanisms to prevent unintended changes and protect your codebase.

## Built-in Safety (Always Active)

### 1. Isolated Workspaces
- **Never modifies your working directory**
- All changes happen in `/tmp/pr-review-*`
- Original code remains untouched

### 2. Branch Verification
- **Verifies PR branch before checkout**
- Uses `gh pr view --json headRefName` to get correct branch
- Aborts if branch mismatch detected
- Recommended: Use `gh pr checkout <number>` for automatic verification

### 3. Test-Before-Commit
- **No commits without passing tests**
- Tests run after each severity tier
- Automatic rollback if tests fail
- Only commits if all tests pass

### 4. Per-Tier Rollback
- **Preserves good fixes if later tier fails**
- Critical fixes kept even if High tier fails tests
- Each tier committed separately
- Can rollback individual tiers without losing all work

### 5. User Confirmation
- **Asks before fixing each PR**
- Shows structured report of issues
- User selects which fixes to apply
- Can skip problematic PRs

## Configurable Safety Features

### Pre-Push Review
```bash
--require-review-before-push
```
- Shows full diff before pushing
- Asks "Push these changes? (y/N)"
- Allows manual inspection
- Can abort at any time

**When to use**: Production code, sensitive changes, learning Warden

### Branch Protection
```bash
--protect-branches main,master,production,release
```
- Prevents pushing to protected branches
- Aborts with clear error message
- Default: `main,master,production`
- **Critical**: Prevents accidental main branch pushes

**When to use**: Always enable in CI/CD, team environments

### File Change Limits
```bash
--max-files-changed 20
```
- Aborts if changes exceed limit
- Safety check for runaway fixes
- Prevents massive unexpected changes

**When to use**: Conservative fix strategies, automated runs

### Conflict Detection
```bash
--check-conflicts-before-fix  # default: true
```
- Detects merge conflicts before starting
- Aborts PR if conflicts found
- Saves time and prevents wasted effort

**When to use**: Always enabled (default)

### Rollback Branches
```bash
--create-rollback-branch
```
- Creates `warden-rollback-PR#-TIMESTAMP` branch
- Backup of original state
- Easy undo with `git reset --hard warden-rollback-...`

**When to use**: Experimental fixes, aggressive mode, learning

### Rate Limiting
```bash
--respect-rate-limits  # default: true
```
- Auto-throttles GitHub API calls
- Prevents hitting rate limits
- Waits and retries if limit hit

**When to use**: Always enabled (default), batch operations

## Safety by Fix Strategy

### Conservative (Safest)
```bash
--fix-strategy conservative
```
- Only fixes with 90%+ confidence
- Flags all complex/architectural changes
- Never attempts risky refactors
- **Recommended for**: Production code, automated CI/CD

### Balanced (Default)
```bash
--fix-strategy balanced
```
- Fixes with 70%+ confidence
- Flags architectural changes
- Attempts moderate complexity
- **Recommended for**: Most PRs, daily use

### Aggressive (Riskiest)
```bash
--fix-strategy aggressive
```
- Fixes with 50%+ confidence
- Attempts complex refactors
- Only flags if >5 files or architectural
- **Recommended for**: Draft PRs, experimental, with `--dry-run`

## Dry Run Mode
```bash
--dry-run
```
- **Zero risk - makes no changes**
- Shows exactly what would be fixed
- Generates full report
- Perfect for:
  - Learning Warden
  - Previewing changes
  - Validating configuration
  - CI/CD validation checks

## Recommended Safety Configurations

### Production/Main Branch PRs
```bash
warden \
  --fix-strategy conservative \
  --test-strategy full \
  --require-review-before-push \
  --protect-branches main,master \
  --create-rollback-branch \
  --max-files-changed 30
```

### Daily Development
```bash
warden \
  --fix-strategy balanced \
  --test-strategy affected \
  --protect-branches main,master
```

### Experimental/Learning
```bash
warden \
  --dry-run \
  --verbose
```

### Automated CI/CD
```bash
warden \
  --fix-strategy conservative \
  --test-strategy full \
  --protect-branches main,master,release \
  --comment-on-pr \
  --no-auto-commit-on-success
```

## Safety Checklist

Before running Warden in a new environment:

- [ ] Start with `--dry-run` to preview behavior
- [ ] Verify `--protect-branches` includes your important branches
- [ ] Test on a draft/experimental PR first
- [ ] Understand rollback mechanism
- [ ] Configure appropriate test strategy
- [ ] Enable `--create-rollback-branch` for first runs
- [ ] Review generated commits before pushing

## What If Something Goes Wrong?

### Rollback a Fix
```bash
# If using --create-rollback-branch
git checkout warden-rollback-PR123-TIMESTAMP
git push -f origin pr-branch-name

# If not using rollback branch
git reset --hard origin/pr-branch-name  # Loses Warden's commits
```

### Undo Last Commit
```bash
git reset --hard HEAD~1  # Remove last commit
# Or
git revert HEAD  # Create reverse commit
```

### Stop Warden Mid-Run
- `Ctrl+C` to interrupt
- Workspaces cleaned up automatically
- No partial commits (commits are atomic per tier)

### Recovering from Failed Push
- Warden won't push if tests fail
- Check error messages
- Fix manually if needed
- Warden won't overwrite your manual fixes

## Security Considerations

### Secrets in Code
- Warden doesn't scan for secrets (use separate tools)
- Review fixes before pushing
- Don't commit `.env` files or credentials

### Untrusted Repositories
- Only run Warden on repos you trust
- Review generated code before pushing
- Use `--dry-run` first on unknown repos

### CI/CD Security
- Use read-only tokens where possible
- Limit PR permissions
- Never run with `--fix-strategy aggressive` in CI
- Always use `--protect-branches`

## Monitoring & Auditing

### Save Metrics
```bash
--save-metrics .warden/metrics.json
```
Tracks:
- PRs reviewed
- Issues found
- Fixes applied
- Success/failure rates

### Save Reports
```bash
--save-report warden-report-$(date +%Y%m%d).md
```
Creates audit trail of all Warden runs.

## Best Practices

1. **Always start with `--dry-run`** on new repos
2. **Enable branch protection** for important branches
3. **Use conservative mode** for production code
4. **Create rollback branches** when learning
5. **Review diffs** before approving pushes
6. **Test incrementally** (start with one PR)
7. **Monitor metrics** to track effectiveness
8. **Document exceptions** when skipping safety features

## See Also

- [PARAMETERS.md](PARAMETERS.md) - All safety parameters
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [WORKFLOW.md](WORKFLOW.md) - How Warden works
