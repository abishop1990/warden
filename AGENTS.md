# AI Coding Agent Instructions

This file provides unified instructions for all AI coding assistants working with the Warden PR review and fix skill.

## CRITICAL: Execution Mode

**THIS IS NOT CONCEPTUAL REVIEW** - You actually execute commands and check exit codes.

**What you do**:
- ✅ Checkout existing PR branches in temp workspaces
- ✅ Run actual build/lint/format/test commands
- ✅ Check exit codes (0 = pass, non-zero = fail)
- ✅ Fix failures when commands fail
- ✅ Push fixes back to the PR

**What you DON'T do**:
- ❌ Abstract "review against principles" analysis
- ❌ Manual inspection without running tools
- ❌ Conceptual suggestions without hands-on fixes
- ❌ Skip review comments on green-CI PRs
- ❌ Ignore bot/AI review comments (Copilot, security bots, etc.)

**CRITICAL**: Analyze **ALL three sources** (CI + Review + Code) for **EVERY PR** regardless of CI status.

See [docs/COMMANDS.md](docs/COMMANDS.md) for exact commands to execute per language.

---

## About Warden

Warden is a cross-platform AI coding assistant skill for comprehensive automated PR review and fixes. Version 1.2 features:
- **Massively parallel execution** across all PRs
- **Contextual review** with PR intent, repo conventions, codebase architecture
- **Streamlined configuration** with 25 core parameters (44 total) and config file support
- **5 specialized reviewers** (security, performance, architecture, maintainability, testing)
- **Flexible test strategies** (none/affected/full/smart)
- **Incremental fix validation** by severity tier
- **PR integration** (opt-in comment on PRs via `--comment-on-pr`, disabled by default)
- **External integrations** (Slack, Jira, webhooks)
- **Platform-specific optimizations** for each AI assistant
- **1.2-1.7x faster** than sequential (configuration-dependent)

Works across: Claude Code, GitHub Copilot, Cursor, Codex, and other AI assistants.

## How to Invoke

AI assistants need explicit reference to "Warden" to use this skill:

**Correct**:
- "Run the Warden skill"
- "Execute the Warden protocol"
- "Use Warden to review my PRs"

**Too ambiguous**:
- "Review my code" ← AI won't know to use Warden
- "Fix my PRs" ← Could use generic workflow instead

**How it works**:
1. Open/navigate to the Warden repository
2. AI reads platform-specific instructions (CLAUDE.md, .cursorrules, etc.)
3. Say "Run Warden" explicitly
4. AI follows the documented workflow

## Cleanup Operations

When user requests workspace cleanup:

**Natural language patterns**:
- "Clean up Warden workspaces"
- "Clear Warden data"
- "Delete Warden temp directories"

**Implementation**:
1. Determine workspace root from config or use default `/tmp/warden-repos`
2. Show disk usage before cleanup
3. Remove workspace directory: `rm -rf <workspace-root>`
4. Report freed disk space

**What gets deleted**: Temporary PR workspaces in configured workspace root
**What is preserved**: Config files (`~/.warden/config.yml`, `.warden/config.yml`), user's working directory

See [CONFIGURATION.md](docs/CONFIGURATION.md) for detailed cleanup instructions.

## Workflow Overview

8-phase workflow for PR review and automated fixes:

0. **Command Discovery (MANDATORY)** - Discover and save validation commands to artifact - BLOCKING for Phase 6
1. **PR Discovery** - Batch API call to list PRs, save initial CI state, analyze ALL by default (user can specify subset)
2. **Analysis** - Launch ALL subagents for ALL PRs analyzing ALL sources (CI + Review + Code + Ticket) regardless of CI status
3. **Validation** - Verify PR branch integrity, run build to check compilation
4. **Planning** - **CI Re-verification (Gap #16 fix): Re-check CI, compare with Phase 1, flag changes** → Aggregate findings, deduplicate, prioritize by severity, flag escalations
5. **User Interaction** - **MANDATORY: Compile report with FRESH CI data and staleness warnings, ask approval, WAIT for response**
6. **Execution** - **MANDATORY: Verify Phase 0 artifact exists, source commands, validate before push**
7. **Summary** - Report metrics and next steps

## Default Configuration

When user doesn't specify parameters, use these defaults:

- **Workspace**: Isolated temp workspaces in `/tmp/warden-repos/` (never modify user's working directory)
- **Review Depth**: Standard (1 generalist reviewer per PR)
- **Test Strategy**: Affected (test only changed packages)
- **Fix Strategy**: Balanced (high + medium confidence fixes)

**Configuration Files**: Load settings from `~/.warden/config.yml` (global) or `.warden/config.yml` (project-specific). See [CONFIGURATION.md](docs/CONFIGURATION.md) for setup.

**Workspace Modes**:
- **Isolated (default)**: Temp workspaces in `/tmp/warden-repos/pr-{number}-{timestamp}/` - safe, parallel-capable
- **In-place**: Run in user's current repo - slower, for complex setup (databases, custom tooling)

**Examples of user specifying non-defaults:**
- "Use comprehensive review" → 3+ reviewers per PR
- "Run full test suite" → All tests, not just affected
- "Be conservative with fixes" → High confidence only
- "Run in my current repo" → In-place mode (slower but handles complex setup)

## Phase 0: Command Discovery (MANDATORY & BLOCKING)

**⚠️ CRITICAL**: This phase is MANDATORY and must complete BEFORE Phase 1. Phase 6 (Execution) is BLOCKED until this completes.

**Purpose**: Discover and save exact validation commands (build/lint/format/test) to an artifact that Phase 6 MUST use.

**Why mandatory**: If agents can skip this, they WILL skip validation commands, causing immediate CI failures after push.

**Artifact required**: `$WORKSPACE/.warden-validation-commands.sh`

**Discovery priority**:
1. AI instruction files (CLAUDE.md, .cursorrules, .github/copilot-instructions.md)
2. CI configs (.github/workflows/*.yml)
3. Language configs (Makefile, package.json, Cargo.toml, etc.)
4. Language defaults (fallback only)

**Implementation**:
```bash
# Create workspace
WORKSPACE="/tmp/warden-repos/session-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Clone target repo
gh repo clone <repo> .

# Discover commands (see PHASE-0-DISCOVERY.md for full script)
./discover-commands.sh > .warden-validation-commands.sh
chmod +x .warden-validation-commands.sh

# BLOCKING CHECK
if [ ! -f ".warden-validation-commands.sh" ]; then
  echo "❌ FATAL: Phase 0 failed - cannot proceed"
  exit 1
fi

# Verify commands discovered
source .warden-validation-commands.sh
echo "Discovered commands:"
echo "  BUILD:  ${BUILD_CMD:-[none]}"
echo "  LINT:   ${LINT_CMD:-[none]}"
echo "  FORMAT: ${FORMAT_CMD:-[none]}"
echo "  TEST:   ${TEST_CMD:-[none]}"
```

**Enforcement**: Phase 6 MUST check this artifact exists before making ANY fixes. See [PHASE-0-DISCOVERY.md](docs/PHASE-0-DISCOVERY.md) for complete specification.

## Phase 3: Validation Pre-Check

**Purpose**: Detect branch corruption and architectural issues before attempting fixes.

**Step 1: Discover validation commands** (see [COMMANDS.md](docs/COMMANDS.md)):
```bash
# Priority: AI instructions → CI config → Language defaults
BUILD_CMD=$(grep "Build:" CLAUDE.md | grep '`' | tr -d '`')
LINT_CMD=$(grep "Lint:" CLAUDE.md | grep '`' | tr -d '`')
TEST_CMD=$(grep "Test:" CLAUDE.md | grep '`' | tr -d '`')

# Fallback to CI workflow if not in CLAUDE.md
[ -z "$BUILD_CMD" ] && BUILD_CMD=$(grep "run:.*build" .github/workflows/*.yml | head -1 | sed 's/.*run: //')
```

**Step 2: Verify each PR**:
1. **Branch integrity**: Compare local vs GitHub file counts
   - If mismatch >20%: Flag as "⚠️ Branch corruption"
2. **Compilation**: Run `$BUILD_CMD` in PR branch
   - If fails: Categorize (fixable vs architectural)
3. **File count anomalies**: Check for 1000+ file changes
   - Usually indicates merge issues or massive refactoring

**Output classifications:**
- ✅ **Clean PR**: Files match, compiles, normal scope
- ⚠️ **Needs Investigation**: File count mismatch, doesn't compile
- 🚨 **Architectural Issue**: Design problems beyond simple fixes (escalate to user)

**Example**:
```bash
# Check file count match
LOCAL_FILES=$(git show HEAD --stat | wc -l)
GH_FILES=$(gh pr view 3875 --json files -q '.files | length')
if [ $((GH_FILES - LOCAL_FILES)) -gt $((LOCAL_FILES / 5)) ]; then
  echo "⚠️ File count mismatch: Local=$LOCAL_FILES, GitHub=$GH_FILES"
fi
```

## Phase 4: Planning

**Step 1: CI Re-verification (MANDATORY - Gap #16 fix)**

**⚠️ CRITICAL**: CI status can change between Phase 1 and Phase 5. MUST re-check before presenting report.

For each PR:
1. Re-fetch CI status: `gh pr checks ${PR} --json name,status,conclusion`
2. Compare with Phase 1 initial state
3. Flag PRs where CI changed (failures increased/decreased)
4. Save fresh CI data for Phase 5 report
5. Cannot proceed to Phase 5 without fresh CI check

**Why this matters**:
- Flaky tests can start failing after Phase 1
- Concurrent merges can break CI
- Presenting stale CI data leads to wrong fix recommendations

See [docs/CI-REVERIFICATION.md](docs/CI-REVERIFICATION.md) for complete enforcement details.

**Step 2: Aggregate Findings**

**Aggregate findings** from Phase 2 (Analysis), Phase 3 (Validation), and FRESH CI data.

**Categorize by severity** and **identify escalation triggers**:
- Fix requires API changes (adding fields, changing signatures)
- Fix requires >100 LOC changes
- Test failures reveal design issues (not just typos)
- Multi-tenant or cross-cutting concerns involved
- Branch corruption detected in Phase 3
- CI status changed since Phase 1 (new failures or resolutions)

**Output**: Structured issue list with severity, complexity, escalation flags, CI status changes.

## Phase 5: User Interaction (MANDATORY)

**CRITICAL**: Before executing ANY fixes, you MUST:

1. **Consolidate all findings** from Phase 2 analysis and Phase 4 CI re-check (all PRs, all sources)
   - Aggregate CI failures (FRESH from Phase 4), review comments, and code quality issues
   - Remove duplicates across different sources
   - Enrich with severity (Critical/High/Medium/Low) and complexity
   - Flag PRs where CI status changed since Phase 1 (Gap #16 fix)

2. **Present comprehensive report** with severity breakdown:
   ```
   === Warden Analysis Report ===

   Found N issues across M PRs:

   PR #123: Feature XYZ
   ├─ Critical (2): [Issue IDs with file:line]
   ├─ High (3): [Issue IDs with file:line]
   └─ Medium (1): [Issue IDs with file:line]

   PR #125: Bug Fix ABC
   └─ High (1): [Issue IDs with file:line]

   Total: X Critical, Y High, Z Medium, W Low
   ```

3. **Ask user for approval** with clear options:
   - "Fix all issues?" (default)
   - "Fix only Critical and High?"
   - "Fix specific PRs only?"
   - "Preview detailed findings first?"
   - "Abort (no changes)"

4. **WAIT for user response** - Do NOT proceed to Phase 5 without explicit approval
   - User may want to review detailed findings
   - User may want to exclude certain PRs or issue types
   - User may want to adjust severity thresholds

**Enhanced report format** (include metadata and CI staleness warnings):
```
=== Warden Analysis Report ===

Analysis Metadata:
- PRs analyzed: 14
- Analysis time: ~12 minutes
- Subagents launched: 42 (3 per PR × 14)
- CI re-verified: ✅ (Gap #16 prevention)
- CI status changes: 2 PRs (flagged below)
- Anomalies detected: 1 (PR #3875 file count mismatch)

Priority Distribution:
- 🚨 Critical (CI failures): 3 PRs
- ⚠️ High (breaking changes): 2 PRs
- ℹ️ Medium (refactors): 5 PRs
- ✅ Clean (ready to merge): 4 PRs

Issues Found:

PR #123: Feature XYZ
⚠️  CI Status Changed (Gap #16 detection):
├─ Phase 1: 0 failures (passing)
└─ Current:  2 failures (FRESH CHECK)
    - TestAuthHandler: Expected 2 elements, got 0
    - TestSessionCleanup: Race condition detected

├─ Critical (2): [Issue IDs with file:line]
├─ High (3): [Issue IDs with file:line]
└─ Medium (1): [Issue IDs with file:line]

Escalations Required:
- PR #3875: Architectural issue (incomplete multi-tenant refactoring)
```

**Common mistake**: Jumping directly from Planning to Execution without user approval.

## Phase 6: Execution

**⚠️ MANDATORY PRE-CHECK**: Before making ANY fixes, verify Phase 0 artifact exists:

```bash
# BLOCKING CHECK - runs before any fix attempt
ARTIFACT="$WORKSPACE/.warden-validation-commands.sh"

if [ ! -f "$ARTIFACT" ]; then
  echo "❌ FATAL: Phase 0 not completed!"
  echo "Required artifact: $ARTIFACT"
  echo "CANNOT proceed without validation commands."
  exit 1
fi

# Source validation commands
source "$ARTIFACT"

echo "✅ Phase 0 verification passed"
echo "Validation commands loaded:"
echo "  BUILD:  ${BUILD_CMD:-[skip]}"
echo "  LINT:   ${LINT_CMD:-[skip]}"
echo "  FORMAT: ${FORMAT_CMD:-[skip]}"
echo "  TEST:   ${TEST_CMD:-[skip]}"
```

**Validation sequence** (ABSOLUTE BLOCKING - Gap #16 fix):

```bash
#!/bin/bash
set -euo pipefail  # Exit on any error - NO BYPASSING

echo "=== Phase 6: Pre-Push Validation (ABSOLUTE BLOCKING) ==="
echo "HARD RULE: Tests must pass 100% before ANY push"

# 1. Apply fixes
apply_fixes()

# 2. Track validation state
VALIDATION_FAILED=false

# 3. Run validations (track failures, don't exit immediately)
eval "$BUILD_CMD" || { echo "❌ BUILD FAILED"; VALIDATION_FAILED=true; }
eval "$LINT_CMD" || { echo "❌ LINT FAILED"; VALIDATION_FAILED=true; }
eval "$FORMAT_CMD" || true  # Auto-fix

# 4. TESTS (ABSOLUTE BLOCKING)
if ! eval "$TEST_CMD"; then
  echo ""
  echo "❌❌❌ TESTS FAILED ❌❌❌"
  echo "DIAGNOSTIC PUSH BLOCKED (Gap #16 enforcement)"
  echo ""
  echo "Cannot push code with failing tests"
  echo "This prevents 'push to save progress' while debugging"
  echo ""
  VALIDATION_FAILED=true
fi

# 5. ABSOLUTE BLOCKING CHECK
if [ "$VALIDATION_FAILED" = true ]; then
  echo "=========================================="
  echo "  VALIDATION FAILED - CANNOT PUSH"
  echo "=========================================="
  git reset --hard HEAD  # Rollback
  echo "Changes rolled back"
  exit 1
fi

# 6. PRE-COMMIT VERIFICATION
git add .
git status --short
UNINTENDED=$(git diff --cached --name-only | grep -E '(_debug\.|test_debug\.)' || true)
if [ -n "$UNINTENDED" ]; then
  echo "❌ Unintended debug files detected"
  git reset --hard HEAD
  exit 1
fi

# 7. Only commit/push if ALL validations passed
echo "✅ ALL VALIDATIONS PASSED - Safe to push"
git commit -m "Fix: ${TIER}"
git push origin $(git branch --show-current)
```

**HARD RULE**: Tests must pass 100% before ANY push. No exceptions.

**Diagnostic Push Prevention** (Gap #16):
- If tests fail → BLOCK and rollback
- No "push to save progress" allowed
- No "will fix later" allowed
- No partial fixes pushed

See [PHASE-0-DISCOVERY.md](docs/PHASE-0-DISCOVERY.md), [VALIDATION-ORDER.md](docs/VALIDATION-ORDER.md), and [DIAGNOSTIC-PUSH-PREVENTION.md](docs/DIAGNOSTIC-PUSH-PREVENTION.md).

**Auto-fix** simple issues, **escalate** complex/architectural ones.

**Escalation Triggers** (do NOT auto-fix, present to user):
1. Fix requires API changes (adding fields, changing method signatures)
2. Fix requires >100 LOC changes
3. Test failures reveal design issues (not just typos/formatting)
4. Multi-tenant or cross-cutting concerns involved
5. Branch corruption detected (file count mismatch, won't compile)

**Escalation Template**:
```
🚨 ESCALATION REQUIRED: PR #{number}

Root Cause: [What actually happened - git history investigation]
Problem: [Design issue, not simple bug]
Investigation: [Git log analysis, affected components]

Fix Options:
1. [Option A] - [Trade-offs]
2. [Option B] - [Trade-offs]

Recommendation: [Preferred approach with rationale]
```

**For fixable issues**: Apply fixes incrementally by severity tier, validate, push.

## Git History Investigation

**When to investigate**: Branch corruption, unexpected failures, architectural issues.

**Standard investigation workflow**:
```bash
# 1. Compare local commit vs GitHub PR
LOCAL_FILES=$(git show HEAD --stat | wc -l)
GH_FILES=$(gh pr view {num} --json files -q '.files | length')

# 2. Check for merge issues
git log --oneline --graph HEAD~10..HEAD

# 3. Find original implementation
git log --all -S "function_name" -- path/to/file

# 4. Check recent changes to affected files
git log -p --follow -- path/to/file | head -100
```

**Document findings** in Phase 5 report for user review.

## Key Optimizations

**Parallel Execution with Batching**:
- **Max 5 PRs analyzed in parallel** (15 subagents for Standard depth)
- If more PRs selected: Process in batches of 5
- Example: 14 PRs = 3 batches (5 + 5 + 4)
- **Why**: Prevents system overload, API rate limiting, agent runtime limits
- Within each batch: All subagents run simultaneously (2.5x faster than sequential)

**Incremental Validation**:
- Fix Critical tier → Test → Commit → Push
- Only proceed to High if Critical succeeded
- Per-tier rollback preserves good fixes

**Targeted Operations**:
- Batch API calls (Phase 1)
- Shallow clones (Phase 5 workspace)
- Test only affected packages (Phase 5)
- Format only changed files (Phase 5)

**Performance**:
- Standard (1 reviewer): 172s vs 291s = **1.7x faster**
- Thorough (2 reviewers): 187s vs 291s = **1.6x faster**
- Comprehensive (3 reviewers): 202s vs 291s = **1.4x faster**

## Platform Tool Limitations

**CRITICAL**: Different platforms have different subagent/task tool access:

### Claude Code ✅
- **Subagents HAVE**: Bash tool (can run `gh` CLI directly)
- **Phase 2**: Subagents can call `gh pr view`, `gh pr checks`, etc.
- **No workaround needed**

### GitHub Copilot ⚠️
- **Subagents DON'T HAVE**: `gh` CLI or external commands
- **Subagents ONLY HAVE**: Local file tools (grep, glob, read)
- **Phase 2 Workaround**: Main agent pre-fetches all PR data, saves to local files, passes file paths to subagents
- **See**: `.github/copilot-instructions.md` for detailed workaround

### Cursor ⚠️
- **Status**: Unknown - likely similar to Copilot (local files only)
- **Recommendation**: Test and document; may need same workaround as Copilot

### Codex ❓
- **Status**: Unknown - needs testing
- **Recommendation**: Document findings after testing

## Subagent Selection (Complexity-Based)

**Simple** (1-5 lines, single file): Main agent direct edits
**Moderate** (5-20 lines, 1-2 files): Scripted or focused agent
**Complex** (20+ lines, multi-file): Specialized agent with autonomy
**Very Complex** (architectural, >5 files): Flag for manual review

## Language-Specific Commands

Auto-detect language from changed files, then adapt:

- **Go**: `gofmt -s -w`, `go test -v ./package/...`, `golangci-lint run`
- **Python**: `black`, `pytest path/ -v`, `ruff check`
- **JavaScript/TypeScript**: `prettier --write`, `npm test -- --changedSince=origin/main`, `eslint`
- **Rust**: `cargo fmt`, `cargo test --package`, `cargo clippy`

**Key**: Only format/test **changed files**, not entire codebase.

## Error Handling

**Graceful Degradation**:
- CI unavailable → Skip CI analysis, proceed with reviews + code analysis
- Reviews API fails → Skip reviews, proceed with CI + code analysis
- Tests fail → Rollback that severity tier only, continue to next PR

**Rollback Strategies**:
- **Per-tier**: Keep Critical fixes if High fails tests
- **Full**: Abort PR if Critical fixes fail tests
- **Selective**: Rollback specific commit if isolated failure

**Always**:
- Clean up workspaces (even on failure)
- Continue to next PR if one fails
- Collect failures for summary report

## Performance

Parallel execution with batching: **1.2-1.7x faster** than sequential (varies by config).
- Standard (1 reviewer): 1.7x faster
- Thorough (2 reviewers): 1.6x faster
- Comprehensive (3 reviewers): 1.4x faster

## Full Documentation

- Detailed workflow: [README.md](README.md)
- Claude Code specifics: [CLAUDE.md](CLAUDE.md)
- Cursor specifics: [.cursorrules](.cursorrules)
- GitHub Copilot specifics: [.github/copilot-instructions.md](.github/copilot-instructions.md)
