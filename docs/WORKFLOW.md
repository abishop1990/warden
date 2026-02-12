# Warden - Detailed Workflow

How Warden analyzes and fixes PRs, phase by phase.

## TL;DR

1. **Discovery**: Batch fetch all open PRs with `gh pr list`
2. **Analysis**: Launch parallel subagents (CI + Reviews + Code Quality per PR)
3. **Planning**: Aggregate findings, deduplicate, sort by severity
4. **Interaction**: Show structured report, ask what to fix
5. **Execution**: Fix by tier → Test → Commit → Push (incremental validation)
6. **Summary**: Report metrics and next steps

**CRITICAL**: Always validate (run tests) BEFORE committing or pushing. See [VALIDATION-ORDER.md](VALIDATION-ORDER.md).

---

## Phase 1: Discovery (Optimized)

**IMPORTANT**: This skill reviews **Pull Requests (PRs)**, NOT branches.

Use batch GitHub API queries for efficiency:

```bash
# Single batch query with JSON output for PULL REQUESTS
gh pr list --author @me --state open --json number,title,statusCheckRollup,reviewDecision --limit 10

# NOT: git branch --list (this lists branches, not PRs!)
# NOT: gh repo view --json (this is repo info, not PRs!)
```

1. Fetch all **PR data** in one batch API call (number, title, CI status, review status)
2. Parse JSON and display formatted summary table
3. Ask user which PRs to analyze (or "all")

**Common Mistake**: Using `git branch` instead of `gh pr list`. Always use `gh pr list` to get pull requests.

**Optimization**: Single API call instead of N sequential calls for N PRs.

### Branch Verification Protocol (MANDATORY)

Before pushing ANY fixes, follow this protocol to ensure you're on the correct PR branch:

1. **Fetch open PRs with branch names**:
   ```bash
   gh pr list --state open --json number,headRefName,title --author @me > /tmp/pr_map.json
   ```

2. **Build PR→Branch mapping**:
   ```bash
   # For each PR, extract number and branch name (headRefName)
   jq -r '.[] | "\(.number):\(.headRefName)"' /tmp/pr_map.json
   ```

3. **Verify branch exists before checkout**:
   ```bash
   BRANCH=$(jq -r '.[] | select(.number==1234) | .headRefName' /tmp/pr_map.json)
   if [ -z "$BRANCH" ]; then
     echo "ERROR: PR #1234 not found in open PRs"
     exit 1
   fi
   git ls-remote origin "$BRANCH" || { echo "ERROR: Branch $BRANCH does not exist"; exit 1; }
   ```

4. **Checkout PR's actual branch**:
   ```bash
   git fetch origin "$BRANCH"
   git checkout "$BRANCH"
   # OR using gh CLI:
   gh pr checkout 1234  # This automatically checks out the correct branch
   ```

5. **Validate before push**:
   ```bash
   CURRENT_BRANCH=$(git branch --show-current)
   if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
     echo "ERROR: Current branch $CURRENT_BRANCH != expected $BRANCH"
     exit 1
   fi
   ```

**Never trust cached/session data** - always fetch fresh PR data from GitHub API.

**Recommended approach**: Use `gh pr checkout <pr-number>` which automatically handles branch verification.

---

## Phase 2: Analysis (Massively Parallel with Context)

**Key Optimization**: Launch ALL subagents for ALL PRs in parallel, not sequentially.

### Critical Context Gathering (per PR, before analysis)

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

### For Each PR (all in parallel)

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

#### Standard (1 reviewer - generalist)
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

#### Thorough (2 reviewers - specialists)
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

#### Comprehensive (3 reviewers - full coverage)
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

### Platform-Specific Execution

- **Claude Code**: Use 3-5 parallel `general-purpose` agents per PR (depending on review depth)
- **GitHub Copilot**: Leverage `@github` for native PR integration
- **Cursor**: Use Composer mode for multi-file analysis

---

## Phase 3: Planning (Structured Aggregation)

**Platform-Specific Approach**:
- **Claude Code**: Use Plan agent for aggregation
- **Others**: Manual aggregation in main agent

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

### Deduplication Rules

- Same file + line number + similar message = duplicate
- CI failure + review comment on same line = single issue with dual evidence
- Related errors in same function = group together

---

## Phase 4: User Interaction

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

---

## Phase 5: Execution (Incremental with Validation)

**Key Optimization**: Fix by severity tier, validate, push, then continue.

**CRITICAL**: See [VALIDATION-ORDER.md](VALIDATION-ORDER.md) for mandatory validation sequence.

### 5.1 Setup Workspace (Optimized with Branch Verification)

```bash
# Get PR branch name from GitHub API (MANDATORY)
PR_BRANCH=$(gh pr view ${PR_NUMBER} --json headRefName --jq '.headRefName')
if [ -z "$PR_BRANCH" ]; then
  echo "ERROR: Could not get branch for PR #${PR_NUMBER}"
  exit 1
fi

# Use shallow clone for speed
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Method 1: Clone and checkout PR (RECOMMENDED)
gh repo clone owner/repo . -- --depth=1
gh pr checkout ${PR_NUMBER}  # Handles branch verification automatically

# Method 2: Manual branch checkout (if gh pr checkout unavailable)
gh repo clone owner/repo . -- --depth=1
git fetch --depth=1 origin "${PR_BRANCH}"
git checkout "${PR_BRANCH}"

# Verify we're on the correct branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$PR_BRANCH" ]; then
  echo "ERROR: Branch mismatch! Current: $CURRENT_BRANCH, Expected: $PR_BRANCH"
  exit 1
fi

echo "✓ Verified on correct branch: $PR_BRANCH for PR #${PR_NUMBER}"
```

### 5.2 Incremental Fix Strategy (Critical → High → Medium → Low)

**MANDATORY SEQUENCE** for each severity tier:

```
1. Apply fixes for this tier
   ↓
2. **VALIDATE: Run build** ← GATE 1 (BLOCKING)
   ↓
   Build PASSED?
   ├─ YES → Continue to step 3
   └─ NO  → ROLLBACK fixes, ABORT tier, continue to next tier
   ↓
3. **VALIDATE: Run linter** ← GATE 2 (BLOCKING)
   ↓
   Lint PASSED?
   ├─ YES → Continue to step 4
   └─ NO  → ROLLBACK fixes, ABORT tier, continue to next tier
   ↓
4. Run language-specific formatting (auto-fix style)
   ↓
5. **VALIDATE: Run tests** ← GATE 3 (BLOCKING - CRITICAL)
   ↓
   Tests PASSED?
   ├─ YES → Continue to step 6
   └─ NO  → ROLLBACK fixes, ABORT tier, continue to next tier
   ↓
6. Commit changes (only if ALL validations passed)
   ↓
7. Push to remote (only after successful commit)
   ↓
8. Verify CI starts
   ↓
9. Clean up workspace
   ↓
10. Continue to next severity tier
```

#### Step 1: Fix all issues at this tier
- Simple fixes (1-5 lines): Direct edits
- Moderate fixes (5-20 lines): Use appropriate subagent
- Complex fixes (20+ lines, multi-file): Use specialized subagent or flag for manual review

#### Step 2: **VALIDATE - Run build (BLOCKING)**

**GATE 1: Ensure code compiles**

```bash
# Run build (BLOCKING - wait for completion)
<language-build-command>
# Examples:
# Go: go build ./...
# Python: python -m compileall .
# JavaScript/TypeScript: npm run build or tsc
# Rust: cargo build

BUILD_EXIT_CODE=$?

# Check build result
if [ $BUILD_EXIT_CODE -ne 0 ]; then
  echo "❌ BUILD FAILED - Rolling back fixes for ${TIER} tier"
  git reset --hard HEAD  # Rollback uncommitted changes
  # Mark tier as failed, continue to next tier
  continue  # Skip to next tier - DO NOT CONTINUE
fi

echo "✓ Build passed for ${TIER} tier"
```

#### Step 3: **VALIDATE - Run linter (BLOCKING)**

**GATE 2: Catch code quality issues**

```bash
# Run linter (BLOCKING - wait for completion)
<language-lint-command>
# Examples:
# Go: golangci-lint run
# Python: ruff check . or pylint
# JavaScript/TypeScript: eslint . or npm run lint
# Rust: cargo clippy -- -D warnings

LINT_EXIT_CODE=$?

# Check lint result
if [ $LINT_EXIT_CODE -ne 0 ]; then
  echo "❌ LINT FAILED - Rolling back fixes for ${TIER} tier"
  git reset --hard HEAD  # Rollback uncommitted changes
  # Mark tier as failed, continue to next tier
  continue  # Skip to next tier - DO NOT CONTINUE
fi

echo "✓ Lint passed for ${TIER} tier"
```

#### Step 4: Run formatting (language-specific - auto-fix)

```bash
# Only format changed files, not entire codebase
git diff --name-only origin/main | xargs <formatter>
# This auto-fixes style issues found by linter
```

#### Step 5: **VALIDATE - Run tests (BLOCKING)**

**GATE 3 (CRITICAL): Ensure functionality works**

```bash
# Run tests (BLOCKING - wait for completion)
<language-test-command>
TEST_EXIT_CODE=$?

# Check test result
if [ $TEST_EXIT_CODE -ne 0 ]; then
  echo "❌ TESTS FAILED - Rolling back fixes for ${TIER} tier"
  git reset --hard HEAD  # Rollback uncommitted changes
  # Mark tier as failed, continue to next tier
  continue  # Skip to next tier - DO NOT COMMIT OR PUSH
fi

# ALL validations passed - create validation marker
touch "/tmp/warden-tier-${TIER}-validated"
echo "✓ All validations passed for ${TIER} tier (build + lint + tests)"
```

**Test Strategy Examples**:

```bash
# Identify affected packages from changed files
git diff --name-only origin/main | xargs <language-specific-test-cmd>

# Go: Extract package paths
PACKAGES=$(git diff --name-only origin/main | grep '\.go$' | xargs -n1 dirname | sort -u)
for pkg in $PACKAGES; do
  go test -v ./$pkg
done

# Python: Test only changed modules
MODULES=$(git diff --name-only origin/main | grep '\.py$' | xargs -n1 dirname | sort -u)
for mod in $MODULES; do
  pytest $mod -v
done

# JavaScript: Use Jest's changed files mode
npm test -- --changedSince=origin/main
```

#### Step 6: Commit (ONLY if ALL validations passed)

```bash
# Verify validation marker exists
if [ ! -f "/tmp/warden-tier-${TIER}-validated" ]; then
  echo "ERROR: Attempting to commit without validation!"
  exit 1
fi

# Commit changes
git add <changed-files>
git commit -m "[PR #${PR_NUMBER}] Fix: ${SEVERITY} - ${DESCRIPTION}

Fixed ${ISSUE_COUNT} ${SEVERITY} severity issues:
- ${ISSUE_1_SUMMARY}
- ${ISSUE_2_SUMMARY}

Tested: ${AFFECTED_PACKAGES}

Co-Authored-By: Warden <noreply@warden.dev>"

# Verify commit was created
if ! git diff --quiet HEAD~1; then
  echo "✓ Commit created successfully"
else
  echo "ERROR: Commit failed"
  exit 1
fi
```

#### Step 7: Push (ONLY after successful commit)

```bash
# Verify validation marker still exists
if [ ! -f "/tmp/warden-tier-${TIER}-validated" ]; then
  echo "CRITICAL ERROR: Validation order violation!"
  echo "Attempting to push without validation!"
  exit 1
fi

# Push to PR branch
git push origin ${PR_BRANCH}

# Verify push succeeded
if [ $? -eq 0 ]; then
  echo "✓ Pushed to ${PR_BRANCH}"
else
  echo "ERROR: Push failed"
  exit 1
fi

# Clean up validation marker
rm "/tmp/warden-tier-${TIER}-validated"
```

#### Step 8: Verify CI starts

```bash
# Wait briefly for CI to start
sleep 5
gh pr checks ${PR_NUMBER} --watch
```

#### Step 9: Clean up workspace

```bash
# Synchronous cleanup - ensure it completes
if [ -d "$WORKSPACE" ]; then
  echo "Cleaning up workspace: $WORKSPACE"
  cd /
  rm -rf "$WORKSPACE"

  # Verify cleanup completed
  if [ -d "$WORKSPACE" ]; then
    echo "⚠️  WARNING: Workspace cleanup failed"
  else
    echo "✓ Workspace cleaned up successfully"
  fi
else
  echo "✓ Workspace already cleaned"
fi
```

#### Step 10: If any validation fails, rollback tier

```bash
# This was already handled in Steps 2, 3, and 5
# git reset --hard HEAD  # Rollback uncommitted changes
# Flag issues for manual review
# Continue to next tier without committing or pushing
```

### Platform-Specific Subagent Selection

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

### 5.3 Cleanup (Verified)

**IMPORTANT**: Cleanup must complete successfully to avoid disk space issues.

```bash
# Synchronous cleanup per tier - ensures completion
if [ -d "$WORKSPACE" ]; then
  echo "Cleaning up workspace: $WORKSPACE"
  WORKSPACE_TO_DELETE="$WORKSPACE"
  cd /  # Change out of workspace before deleting

  rm -rf "$WORKSPACE_TO_DELETE"

  # Verify cleanup completed
  if [ -d "$WORKSPACE_TO_DELETE" ]; then
    echo "⚠️  WARNING: Workspace cleanup failed for $WORKSPACE_TO_DELETE"
    echo "Manual cleanup required"
  else
    echo "✓ Workspace cleaned up successfully"
  fi
fi

# After all tiers complete, verify no lingering workspaces
echo "Checking for lingering workspaces..."
LINGERING=$(find /tmp -maxdepth 1 -name "pr-review-*" -type d 2>/dev/null | wc -l)
if [ "$LINGERING" -gt 0 ]; then
  echo "⚠️  WARNING: $LINGERING workspace(s) not cleaned up"
  find /tmp -maxdepth 1 -name "pr-review-*" -type d 2>/dev/null
else
  echo "✓ All workspaces cleaned up"
fi
```

---

## Phase 6: Summary Report

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

---

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

---

## See Also

- [VALIDATION-ORDER.md](VALIDATION-ORDER.md) - **CRITICAL**: Correct validation sequence
- [PARAMETERS.md](PARAMETERS.md) - All configuration parameters
- [SAFETY.md](SAFETY.md) - Safety features and best practices
- [EXAMPLES.md](EXAMPLES.md) - Usage examples
