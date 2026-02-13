# Warden - Troubleshooting Guide

Common issues and their solutions.

## TL;DR Quick Fixes

- **Tests pushed before validation**: See [Validation Order Issues](#validation-order-issues)
- **Wrong branch checked out**: Use `gh pr checkout <number>` instead of git commands
- **CI fails after Warden push**: Check test output, rollback if needed
- **Out of memory**: Reduce `--max-parallel-prs` and `--max-parallel-agents`
- **Slow performance**: Enable `--reuse-workspace` and `--cache-pr-data`
- **Broken code pushed**: Check `--fix-strategy`, use `conservative` for safety

---

## Validation Order Issues

### Problem: Code pushed before tests validated

**Symptoms**:
- CI fails after Warden pushes
- Commits appear before test results
- Broken code on PR branch

**Root Cause**:
Agent is pushing code BEFORE running tests or without waiting for test completion.

**Solution**:
See [VALIDATION-ORDER.md](VALIDATION-ORDER.md) for the MANDATORY validation sequence:

```bash
# CORRECT ORDER (MANDATORY):
1. Apply fixes
2. Run formatting
3. **RUN TESTS** (BLOCKING - must complete)
4. Check test exit code
   - If FAIL: rollback (git reset --hard HEAD), abort tier
   - If PASS: continue
5. Commit (only if tests passed)
6. Push (only after commit)
```

**Enforcement**:
Add validation markers to ensure order:

```bash
# After tests pass:
touch "/tmp/warden-tier-${TIER}-validated"

# Before commit:
if [ ! -f "/tmp/warden-tier-${TIER}-validated" ]; then
  echo "ERROR: Cannot commit without validation!"
  exit 1
fi

# Before push:
if [ ! -f "/tmp/warden-tier-${TIER}-validated" ]; then
  echo "ERROR: Cannot push without validation!"
  exit 1
fi
```

**Prevention**:
- Use `--require-review-before-push` to manually approve before pushing
- Add pre-push git hooks (see `examples/pre-commit.sh`)
- Always check test output before proceeding

---

## Branch and PR Issues

### Problem: Wrong branch checked out

**Symptoms**:
- Pushing to wrong branch
- PR not updated after push
- "Branch doesn't exist" errors

**Root Cause**:
Using git branch commands instead of GitHub PR API.

**Solution**:
Always use `gh pr checkout <pr-number>`:

```bash
# ✅ CORRECT
gh pr checkout 123

# ❌ WRONG
git checkout feature-branch  # May not be the PR branch!
```

**Branch Verification Protocol**:

```bash
# 1. Get PR's actual branch name
PR_BRANCH=$(gh pr view ${PR_NUMBER} --json headRefName --jq '.headRefName')

# 2. Verify branch exists
git ls-remote origin "$PR_BRANCH" || exit 1

# 3. Checkout PR
gh pr checkout ${PR_NUMBER}

# 4. Verify current branch matches
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "$PR_BRANCH" ]; then
  echo "ERROR: Branch mismatch!"
  exit 1
fi
```

### Problem: Listing branches instead of PRs

**Symptoms**:
- Seeing branches that aren't PRs
- Missing actual open PRs
- Wrong PR count

**Root Cause**:
Using `git branch` or `git branch -r` instead of `gh pr list`.

**Solution**:

```bash
# ✅ CORRECT - List pull requests
gh pr list --author @me --state open --json number,title

# ❌ WRONG - Lists branches, not PRs
git branch --list
git branch -r
```

---

## Test Failures

### Problem: Tests fail after Warden fixes

**Symptoms**:
- CI red after Warden push
- Local tests pass but CI fails
- Intermittent test failures

**Diagnosis**:

```bash
# 1. Check what tests failed
gh pr checks <pr-number>

# 2. Get CI logs
gh run view <run-id> --log-failed

# 3. Run tests locally
<language-test-command>
```

**Common Causes**:

1. **Incomplete fixes**:
   - Warden fixed part of the issue but not all occurrences
   - Solution: Review fix, complete manually or use `--fix-strategy aggressive`

2. **Test environment differences**:
   - Different dependencies or environment variables
   - Solution: Match CI environment locally, check `.github/workflows/`

3. **Race conditions**:
   - Tests timing-dependent
   - Solution: Fix tests or skip tier, flag for manual review

4. **Over-aggressive fixes**:
   - Warden changed too much
   - Solution: Use `--fix-strategy conservative`, rollback and retry

**Rollback**:

```bash
# If tests fail after push
git reset --hard HEAD~1  # Remove last commit
git push -f origin pr-branch  # Force push (use with caution)

# Or revert
git revert HEAD
git push origin pr-branch
```

### Problem: Tests timeout

**Symptoms**:
- Tests don't complete
- Warden hangs on test phase
- "Test timeout" errors

**Solution**:

```bash
# Increase timeout
warden --test-timeout 900  # 15 minutes

# Or use affected tests only
warden --test-strategy affected

# Or skip slow tests
warden --test-command "npm test -- --testPathIgnorePatterns slow"
```

---

## Performance Issues

### Problem: Warden is slow

**Symptoms**:
- Takes minutes per PR
- High memory usage
- Workspace setup is slow

**Solutions**:

1. **Enable workspace reuse**:
   ```bash
   warden --reuse-workspace
   ```

2. **Reduce parallelization** (if resource-constrained):
   ```bash
   warden --max-parallel-prs 5 --max-parallel-agents 10
   ```

3. **Use affected tests only**:
   ```bash
   warden --test-strategy affected
   ```

4. **Cache PR data**:
   ```bash
   warden --cache-pr-data 3600  # 1 hour
   ```

5. **Use standard review depth**:
   ```bash
   warden --review-depth standard  # 1 reviewer instead of 3+
   ```

### Problem: Out of memory

**Symptoms**:
- Process killed
- "Cannot allocate memory" errors
- System becomes unresponsive

**Solution**:

```bash
# Reduce concurrent operations
warden \
  --max-parallel-prs 3 \
  --max-parallel-agents 5 \
  --limit 10

# Process PRs in smaller batches
warden --limit 5
# Then run again for next 5
```

---

## Git and GitHub Issues

### Problem: Push rejected (non-fast-forward)

**Symptoms**:
- "Updates were rejected" error
- "tip of your current branch is behind"

**Cause**:
Remote branch was updated while Warden was working.

**Solution**:

```bash
# Fetch and rebase
git fetch origin
git rebase origin/pr-branch

# Resolve conflicts if any
git add .
git rebase --continue

# Push
git push origin pr-branch
```

### Problem: GitHub API rate limit

**Symptoms**:
- "API rate limit exceeded" errors
- Requests timing out
- 403 Forbidden responses

**Solution**:

```bash
# Check rate limit status
gh api rate_limit

# Enable rate limit respect (default: true)
warden --respect-rate-limits

# Reduce batch size
warden --limit 5

# Use authenticated requests (higher limit)
gh auth login
```

### Problem: Permission denied

**Symptoms**:
- "Permission denied" when pushing
- "You don't have write access"

**Cause**:
Insufficient GitHub permissions.

**Solution**:

```bash
# Check permissions
gh auth status

# Refresh authentication
gh auth refresh

# Check repo permissions
gh repo view owner/repo --json viewerPermission
```

---

## Fix Strategy Issues

### Problem: Fixes are too aggressive

**Symptoms**:
- Unexpected code changes
- Breaking changes introduced
- Too many files modified

**Solution**:

```bash
# Use conservative strategy
warden --fix-strategy conservative

# Limit files changed
warden --max-files-changed 10

# Require review before push
warden --require-review-before-push

# Preview first
warden --dry-run
```

### Problem: Not fixing enough issues

**Symptoms**:
- Critical issues still present
- Warden skips fixable issues
- "Flagged for manual review" too often

**Solution**:

```bash
# Use aggressive strategy
warden --fix-strategy aggressive

# Increase fixes per tier
warden --max-fixes-per-tier 50

# Lower severity threshold
warden --severity low
```

---

## Configuration Issues

### Problem: Parameters not working

**Symptoms**:
- Parameters ignored
- Unexpected default behavior
- Conflicts between parameters

**Check Parameter Precedence**:

```
--reviewers (explicit list)
  > --reviewer-count (numeric)
  > --review-depth (preset)

--focus-paths (applied first)
  > --ignore-paths (applied second)

--test-strategy none
  > --test-on-severity (ignored if none)

--dry-run
  > disables all fix operations
```

**Solution**:

```bash
# Explicit is better than implicit
warden --reviewers security,testing  # Better than --review-depth

# Check effective config with verbose
warden --verbose --dry-run
```

### Problem: Custom rules file not loaded

**Symptoms**:
- `.warden-rules.yml` ignored
- Default rules used

**Solution**:

```bash
# Specify rules file explicitly
warden --review-rules .warden-rules.yml

# Check file exists and is valid YAML
cat .warden-rules.yml | yq .  # Requires yq

# Validate syntax
yamllint .warden-rules.yml
```

---

## Language-Specific Issues

### Problem: Formatter not found

**Symptoms**:
- "command not found: gofmt/black/prettier"
- Formatting step fails

**Solution**:

```bash
# Install language-specific formatter
# Go:
go install golang.org/x/tools/cmd/gofmt@latest

# Python:
pip install black

# JavaScript:
npm install -g prettier

# Or specify full path
warden --formatter "/usr/local/bin/black"
```

### Problem: Tests not found

**Symptoms**:
- "No tests found"
- Test command fails
- Wrong test runner

**Solution**:

```bash
# Specify test command explicitly
warden --test-command "npm test"
warden --test-command "pytest -v"
warden --test-command "go test ./..."

# Or force language detection
warden --language python --test-command "pytest"
```

---

## Workspace Issues

### Problem: Workspace not cleaned up

**Symptoms**:
- `/tmp/pr-review-*` directories remain
- Disk space filling up

**Solution**:

```bash
# Manual cleanup
rm -rf /tmp/pr-review-*

# Check current workspaces
ls -lh /tmp/pr-review-*

# Warden should clean up automatically (background)
# If not, check for errors in verbose output
warden --verbose
```

### Problem: Workspace conflicts

**Symptoms**:
- "Directory already exists"
- Stale checkout interfering

**Solution**:

```bash
# Clean stale workspaces
rm -rf /tmp/pr-review-*

# Use unique workspace directory
warden --workspace-dir /tmp/warden-$(date +%s)

# Or don't reuse workspaces
warden --reuse-workspace false
```

---

## Integration Issues

### Problem: Slack notifications not working

**Symptoms**:
- No Slack message sent
- Webhook errors

**Solution**:

```bash
# Test webhook manually
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from Warden"}' \
  https://hooks.slack.com/services/YOUR/WEBHOOK

# Check webhook URL format
warden --notify-slack https://hooks.slack.com/services/T00/B00/XX

# Use verbose to see error details
warden --notify-slack $WEBHOOK --verbose
```

### Problem: PR comments not posting

**Symptoms**:
- `--comment-on-pr` doesn't work
- No comment appears on PR

**Solution**:

```bash
# Check GitHub permissions
gh api repos/owner/repo/pulls/123/comments

# Verify authentication
gh auth status

# Test manually
gh pr comment 123 --body "Test comment"

# Use verbose mode
warden --comment-on-pr --verbose
```

---

## Debugging Tips

### Enable Verbose Logging

```bash
warden --verbose 2>&1 | tee warden-debug.log
```

### Check Validation Markers

```bash
# List validation markers
ls -la /tmp/warden-* /tmp/tier-*

# Check marker content
cat /tmp/warden-tier-critical-validated
```

### Inspect Git State

```bash
# Check current branch
git branch --show-current

# Check uncommitted changes
git status

# Check commits not pushed
git log origin/pr-branch..HEAD

# Check what would be pushed
git diff origin/pr-branch HEAD
```

### Test Workflow Manually

```bash
# 1. Get PR info
gh pr view 123 --json headRefName,title

# 2. Checkout PR
gh pr checkout 123

# 3. Make test fix
echo "test" >> README.md

# 4. Run tests
npm test  # or appropriate test command

# 5. Check exit code
echo $?  # Should be 0 for pass

# 6. Commit
git add README.md
git commit -m "Test commit"

# 7. Push
git push origin $(git branch --show-current)
```

---

## Common Error Messages

### "CRITICAL ERROR: VALIDATION ORDER VIOLATION"

**Meaning**: Attempting to push without running tests first.

**Fix**: See [VALIDATION-ORDER.md](VALIDATION-ORDER.md) - ensure tests run and pass before commit/push.

### "ERROR: Branch mismatch"

**Meaning**: Current branch doesn't match expected PR branch.

**Fix**: Use `gh pr checkout <pr-number>` to checkout correct branch.

### "Tests failed - aborting"

**Meaning**: Tests failed, changes will be rolled back.

**Fix**: Review test output, fix issues manually or adjust `--fix-strategy`.

### "Permission denied (publickey)"

**Meaning**: SSH key authentication failed.

**Fix**:
```bash
# Check SSH keys
ssh -T git@github.com

# Or use HTTPS instead
gh auth login
```

### "fatal: not a git repository"

**Meaning**: Command run outside a git repository.

**Fix**: Run Warden from inside a git repository, or specify `--repo owner/repo`.

---

## Getting Help

### Check Documentation

- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [PARAMETERS.md](PARAMETERS.md) - All configuration options
- [WORKFLOW.md](WORKFLOW.md) - How Warden works
- [VALIDATION-ORDER.md](VALIDATION-ORDER.md) - Critical validation sequence
- [SAFETY.md](SAFETY.md) - Safety features

### Report Issues

If you encounter a bug:

1. Run with `--verbose` to capture detailed logs
2. Save the output: `warden --verbose 2>&1 | tee bug-report.log`
3. Open an issue at: https://github.com/abishop1990/warden/issues
4. Include:
   - Warden version
   - Platform (Claude Code, Copilot, Cursor)
   - Command used
   - Error message
   - Verbose logs

---

## Best Practices to Avoid Issues

1. **Always start with `--dry-run`** on new repos
2. **Use `gh pr checkout <number>`** instead of git commands
3. **Enable `--require-review-before-push`** for production code
4. **Set `--protect-branches`** to prevent accidents
5. **Use `conservative` fix strategy** for critical code
6. **Enable verbose logging** when debugging
7. **Check test output** before accepting changes
8. **Review validation order** in VALIDATION-ORDER.md
9. **Monitor CI status** after pushes
10. **Keep workspaces clean** (automatic cleanup should work)

---

## See Also

- [VALIDATION-ORDER.md](VALIDATION-ORDER.md) - **CRITICAL**: Mandatory validation sequence
- [SAFETY.md](SAFETY.md) - Safety features to prevent issues
- [WORKFLOW.md](WORKFLOW.md) - Understanding how Warden works
- [EXAMPLES.md](EXAMPLES.md) - Real-world usage examples
