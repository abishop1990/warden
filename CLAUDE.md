# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Warden PR review and fix skill.

## How to Invoke Warden

User must explicitly reference "Warden" for Claude to use this skill:

**Correct invocations**:
- "Run the Warden skill"
- "Execute Warden on my pull requests"
- "Use Warden to review and fix PRs"

**Required**: Navigate to or open the Warden repository so Claude reads this CLAUDE.md file.

## Cleanup Operations

When user requests cleanup (natural language examples):
- "Clean up Warden workspaces"
- "Clear Warden data"
- "Delete Warden temp directories"
- "Remove Warden files"

**Execute cleanup**:
```bash
# Get workspace root from config or use default
WORKSPACE_ROOT=$(grep -A5 "^workspace:" ~/.warden/config.yml 2>/dev/null | grep "root:" | awk '{print $2}' || echo "/tmp/warden-repos")

# Show disk usage before cleanup
echo "Warden workspace usage:"
du -sh "$WORKSPACE_ROOT" 2>/dev/null || echo "No workspaces found"

# Clean up workspaces
if [ -d "$WORKSPACE_ROOT" ]; then
  FREED=$(du -sh "$WORKSPACE_ROOT" | awk '{print $1}')
  rm -rf "$WORKSPACE_ROOT"
  echo "Cleaned up $FREED from $WORKSPACE_ROOT"
else
  echo "No Warden workspaces to clean (workspace root: $WORKSPACE_ROOT)"
fi
```

**What is deleted**: Temporary PR workspaces
**What is preserved**: Configuration files, user's working directory, git repositories

## Git Workflow (IMPORTANT)

**Use PR-based workflow, NOT direct pushes to main**

When making changes to the Warden repository itself (fixing gaps, adding features, updating docs):

### Standard Workflow

1. **Create feature branch**:
   ```bash
   git checkout -b gap-N-description
   # Examples:
   # - gap-17-fix-timeout-handling
   # - feature-add-gitlab-support
   # - docs-update-examples
   ```

2. **Make changes and commit**:
   ```bash
   # Make your changes
   git add <files>
   git commit -m "Descriptive commit message"
   ```

3. **Push branch to remote**:
   ```bash
   git push origin gap-N-description
   ```

4. **Create pull request**:
   ```bash
   gh pr create --title "Fix Gap #N: Brief description" --body "$(cat <<'EOF'
   ## The Gap
   [Explain what was wrong]

   ## The Fix
   [Explain the solution]

   ## Changes
   [List key files/changes]

   ## Testing
   [How to verify the fix works]
   EOF
   )"
   ```

5. **Wait for review/approval** - Do NOT merge immediately

6. **After approval** - User will merge or give permission to merge

### Why PR Workflow?

- ✅ Allows code review before merging
- ✅ Tracks progress across multiple changes
- ✅ Enables collaboration (others can comment/suggest)
- ✅ Maintains clean merge history
- ✅ Prevents accidental breaking changes

### Emergency Hotfixes

Only push directly to main if:
- User explicitly requests it
- Critical production issue requiring immediate fix
- User says "push to main" or "skip PR"

**Default**: Always use PRs unless instructed otherwise.

## About Warden

Warden is a cross-platform AI skill for comprehensive automated PR review and fixes. Version 1.2 includes contextual review, streamlined configuration (25 core parameters + config files), and platform-specific optimizations.

**Execution Mode**: Warden executes actual commands and checks exit codes (see AGENTS.md for details).

See [docs/COMMANDS.md](docs/COMMANDS.md) for command discovery from repo docs.

## Skill Overview

Warden analyzes three issue sources (CI failures, review comments, code quality) - see AGENTS.md for details.

This skill implements an 8-phase workflow for PR review and automated fixes:

0. **Command Discovery (MANDATORY)** - Create `.warden-validation-commands.sh` artifact (BLOCKING for Phase 6)
1. **PR Discovery** - Batch API call to list and select PRs
2. **Parallel Analysis** - Launch ALL subagents for ALL PRs simultaneously
3. **Validation** - Verify PR branch integrity, run build checks
4. **Planning** - Use Plan agent to aggregate, deduplicate, and prioritize findings
5. **User Interaction** - Present structured report and select which issues to fix
6. **Execution** - **MANDATORY: Verify Phase 0 artifact, source commands, validate before push**
7. **Summary Report** - Comprehensive metrics and next steps

See [README.md](README.md) for complete workflow documentation and [PHASE-0-DISCOVERY.md](docs/PHASE-0-DISCOVERY.md) for Phase 0 enforcement.

## Claude Code Specific Implementation

### Available Subagents

Claude Code provides these specialized agents via the Task tool:

- **`Explore`** - Fast agent specialized for exploring codebases
- **`Plan`** - Software architect agent for designing implementation plans
- **Task** (default) - General-purpose agent for complex, multi-step tasks

**Note**: Subagents can use the Bash tool for command execution depending on their configuration.

### Subagent Usage by Phase

**Phase 0: Command Discovery (MANDATORY)**
- **Agent**: Main agent (Bash tool)
- **Task**: Discover build/lint/format/test commands from repo
- **Artifact**: Create `$WORKSPACE/.warden-validation-commands.sh`
- **Commands**:
  ```bash
  # Create workspace
  WORKSPACE="/tmp/warden-repos/session-$(date +%s)"
  mkdir -p "$WORKSPACE"
  cd "$WORKSPACE"

  # Clone target repo
  gh repo clone <owner/repo> .

  # Discover commands (priority: AI files → CI configs → defaults)
  BUILD_CMD=$(grep "Build:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')
  LINT_CMD=$(grep "Lint:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')
  FORMAT_CMD=$(grep "Format:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')
  TEST_CMD=$(grep "Test:" CLAUDE.md | grep -o '`[^`]*`' | tr -d '`')

  # Create artifact
  cat > .warden-validation-commands.sh <<EOF
  export BUILD_CMD='$BUILD_CMD'
  export LINT_CMD='$LINT_CMD'
  export FORMAT_CMD='$FORMAT_CMD'
  export TEST_CMD='$TEST_CMD'
  EOF

  chmod +x .warden-validation-commands.sh

  # BLOCKING CHECK
  if [ ! -f ".warden-validation-commands.sh" ]; then
    echo "❌ FATAL: Phase 0 failed"
    exit 1
  fi
  ```
- **Why**: Phase 6 CANNOT execute without these commands
- **Critical**: If this phase fails, STOP - do not proceed to Phase 1

**Phase 1: PR Discovery**
- **Agent**: Main agent
- **Task**: Single batch API call with `gh pr list --json` to get **PULL REQUESTS** (not branches!)
- **Command**: `gh pr list --state open --json number,headRefName,title,statusCheckRollup,reviews,updatedAt`
- **Why**: Simple operation, no subagent needed
- **Common mistake**: Using `git branch --list` - this lists branches, not PRs!

**Scope Selection:**
- If ≤10 PRs: Analyze all
- If >10 PRs: Auto-select top 10 by priority and INFORM user
- **Priority**: Failing CI > Review comments > Most recently updated
- **User can override**: "analyze all PRs", "only PR #123", "analyze PR #123, #125"

**Default Configuration**: Standard review depth, Affected test strategy, Balanced fix strategy (see AGENTS.md for details and overrides).

## Model Selection (Claude Code)

**⚠️ Note**: Model selection via Task tool's `model` parameter is currently non-functional in Claude Code 2.1.12+. Use the `/model` command before creating tasks instead.

**Recommended models by phase**:
- **Phase 2 Analysis** (CI/Review/Simple code review): Haiku (fast, cost-effective)
- **Phase 2 Analysis** (Complex code quality review): Sonnet (better for nuanced analysis)
- **Phase 3 Planning**: Sonnet (requires structured thinking)
- **Phase 5 Execution**: Sonnet (requires code generation quality)

**To set model**: Use `/model sonnet` or `/model haiku` before invoking Task tool.

## Platform Tool Access

**Claude Code Task agents HAVE full tool access:**
- ✅ Bash tool - Can run `gh` CLI commands directly
- ✅ Read, Grep, Glob - Local file operations
- ✅ WebFetch - Can access URLs if needed

**This means Claude Code subagents CAN directly call:**
```bash
gh pr view 123 --json reviews,comments
gh pr checks 123 --json name,status,conclusion
gh pr diff 123
```

**Note**: Other platforms (GitHub Copilot, Cursor) may have subagent tool limitations. See their platform-specific files for workarounds.

**Phase 2: Analysis (Parallel with Batching)**
- **Agent**: Multiple `general-purpose` agents (3-5 per PR, all in parallel, depth-dependent)
- **Context Gathering** (before launching subagents):
  1. **PR Metadata**: `gh pr view --json title,body,author` - understand PR intent
  2. **Repo AI Instructions**: Read `CLAUDE.md`, `AGENTS.md` - project conventions
  3. **Codebase Context**: Read README.md, package.json/go.mod, project structure
- **Task**: For each PR, launch parallel agents:
  1. CI Analysis: `gh pr checks` + log parsing
  2. Review Analysis (**MUST fetch BOTH** - Gap #15 fix):
     - Review summaries: `gh pr view --json reviews`
     - Review comment threads: `gh api /repos/{owner}/{repo}/pulls/{pr}/comments`
     - Parse BOTH for actionable items (see docs/REVIEW-COMMENTS.md)
  3. Code Quality: `gh pr diff` + contextual analysis (with PR description, repo instructions, codebase overview)
  4. (Thorough) Security Review: Deep security focus
  5. (Thorough) Performance Review: Deep performance focus
  6. (Comprehensive) Architecture Review: Deep design focus
  7. (If ticket integration enabled) Ticket Alignment: Extract ticket ID, fetch requirements, compare to PR scope
- **Why**: Complex multi-step analysis requiring autonomy and context
- **Batching Strategy**: Max 5 PRs per batch to prevent overload (see AGENTS.md for details).

**Parallelization per batch**:
  - Standard: 15 agents for 5 PRs (3 per PR)
  - Thorough: 20 agents for 5 PRs (4 per PR)
  - Comprehensive: 25 agents for 5 PRs (5 per PR)

**Example parallel Task calls** (Standard depth):
```
Task(general-purpose, "Analyze CI failures for PR #123: fetch checks, parse logs, categorize failures")
Task(general-purpose, "Analyze review comments for PR #123 (Gap #15 fix):
  MUST fetch BOTH:
  1. Review summaries: gh pr view 123 --json reviews
  2. Review comment threads: gh api /repos/{owner}/{repo}/pulls/123/comments
  Parse BOTH for actionable items, unresolved threads, critical feedback")
Task(general-purpose, "Perform code review for PR #123 WITH CONTEXT:
  - PR description: [title and body from gh pr view]
  - Repo conventions: [content from CLAUDE.md and AGENTS.md]
  - Codebase overview: [README.md summary, project structure]
  - Analyze: Does code match PR intent? Any bugs/security/performance issues?")
Task(general-purpose, "Analyze CI failures for PR #125...")
Task(general-purpose, "Analyze review comments for PR #125...")
Task(general-purpose, "Perform code review for PR #125 WITH CONTEXT...")
# ... and so on for all selected PRs
```

**Example parallel Task calls** (Comprehensive depth):
```
Task(general-purpose, "Analyze CI failures for PR #123...")
Task(general-purpose, "Analyze review comments for PR #123...")
Task(general-purpose, "Security review PR #123 WITH CONTEXT: focus on OWASP Top 10, auth, input validation")
Task(general-purpose, "Performance review PR #123 WITH CONTEXT: focus on N+1 queries, memory, algorithms")
Task(general-purpose, "Architecture review PR #123 WITH CONTEXT: focus on design patterns, coupling, SOLID")
# ... repeat for other PRs
```

**Phase 3: Planning**
- **Agent**: `Plan` agent
- **Task**:
  1. **CI Re-verification (MANDATORY - Gap #16 fix)**: Re-check CI status for all PRs, compare with Phase 1, flag changes
     ```bash
     # For each PR, re-fetch CI and compare
     gh pr checks ${PR} --json name,status,conclusion
     # Flag if failures changed since Phase 1
     # See docs/CI-REVERIFICATION.md
     ```
  2. **Aggregate findings**: From Phase 2, deduplicate, enrich with severity/complexity, group related issues
  3. **Generate structured report**: With FRESH CI data and staleness warnings
- **Why**: Architectural task requiring structured analysis and design thinking
- **Input**: All findings from Phase 2 subagents + FRESH CI data
- **Output**: Structured issue list per PR with severity, complexity, grouping, CI status changes

**Phase 4: User Interaction (MANDATORY)**
- **Agent**: Main agent
- **Task**: Present report with FRESH CI data (from Phase 3 re-check), get approval, WAIT for response
- **Why**: User interaction happens in main agent
- **CI Staleness Warnings** (Gap #16 fix): Report MUST show if CI changed since Phase 1
- **Details**: See AGENTS.md Phase 4 for complete requirements (report format, approval options, wait protocol)

**Phase 6: Execution**
- **⚠️ MANDATORY PRE-CHECK**: Before ANY fixes, verify Phase 0 artifact:
  ```bash
  # BLOCKING CHECK
  ARTIFACT="$WORKSPACE/.warden-validation-commands.sh"
  if [ ! -f "$ARTIFACT" ]; then
    echo "❌ FATAL: Phase 0 not completed - cannot execute fixes"
    exit 1
  fi

  # Source validation commands
  source "$ARTIFACT"
  ```

- **Validation sequence** (ABSOLUTE BLOCKING - Gap #16 fix):
  ```bash
  #!/bin/bash
  set -euo pipefail  # No bypassing allowed

  # 1. Apply fixes
  apply_fixes()

  # 2. ABSOLUTE BLOCKING VALIDATION
  VALIDATION_FAILED=false

  # Build
  eval "$BUILD_CMD" || { echo "❌ BUILD FAILED"; VALIDATION_FAILED=true; }

  # Lint
  eval "$LINT_CMD" || { echo "❌ LINT FAILED"; VALIDATION_FAILED=true; }

  # Format (auto-fix)
  eval "$FORMAT_CMD" || true

  # Tests (ABSOLUTE BLOCKING)
  if ! eval "$TEST_CMD"; then
    echo "❌❌❌ TESTS FAILED ❌❌❌"
    echo "DIAGNOSTIC PUSH BLOCKED (Gap #16)"
    echo "Cannot push code with failing tests"
    VALIDATION_FAILED=true
  fi

  # BLOCKING CHECK
  if [ "$VALIDATION_FAILED" = true ]; then
    git reset --hard HEAD  # Rollback
    echo "VALIDATION FAILED - CANNOT PUSH"
    exit 1
  fi

  # 3. PRE-COMMIT VERIFICATION
  git add .
  UNINTENDED=$(git diff --cached --name-only | grep -E '(_debug\.|test_debug\.)' || true)
  [ -n "$UNINTENDED" ] && { git reset --hard HEAD; exit 1; }

  # 4. Only commit/push if ALL validations passed
  git commit -m "Fix: ${TIER}"
  git push origin $(git branch --show-current)
  ```

  **HARD RULE**: Tests must pass 100% before ANY push. No "diagnostic pushes" allowed.
  See [docs/DIAGNOSTIC-PUSH-PREVENTION.md](docs/DIAGNOSTIC-PUSH-PREVENTION.md)

- **Complexity-based routing**:

  **Simple fixes** (1-5 lines, single file):
  - **Agent**: Main agent
  - **Task**: Direct edits using Edit tool
  - **Why**: Straightforward, no need for subagent overhead

  **Moderate fixes** (5-20 lines, 1-2 files):
  - **Agent**: `Bash` agent
  - **Task**: Scripted changes, testing, formatting
  - **Why**: Command-oriented workflow fits Bash agent

  **Complex fixes** (20+ lines, multiple files):
  - **Agent**: `general-purpose` agent
  - **Task**: Multi-file edits, refactoring, testing
  - **Why**: Requires autonomy and context management

  **Very complex** (architectural changes, >5 files):
  - **Action**: Flag for manual review
  - **Why**: Beyond automated fix scope

**Phase 7: Summary**
- **Agent**: Main agent
- **Task**: Collect results, generate summary report
- **Why**: Simple aggregation and presentation

### Workflow Execution (Optimized)

**Key Optimizations**:

1. **Batch API calls** in Phase 1:
   ```bash
   gh pr list --author @me --state open --json number,title,statusCheckRollup,reviewDecision --limit 10
   ```

2. **Parallel subagent launch** in Phase 2:
   - Don't wait for PR #1 analysis to complete before starting PR #2
   - Launch all subagents simultaneously in a single message with multiple Task tool calls
   - 2.5x faster than sequential execution

3. **Use Plan agent** in Phase 3:
   - Structured aggregation and prioritization
   - Better at deduplication and grouping than main agent

4. **Incremental fix validation** in Phase 6:
   - Source `.warden-validation-commands.sh` artifact (MANDATORY)
   - Fix Critical tier → Validate ($BUILD → $LINT → $FORMAT → $TEST) → Commit → Push
   - Only proceed to High tier if Critical succeeded
   - Per-tier rollback on failure

5. **Shallow clones** for workspace setup:
   ```bash
   gh repo clone owner/repo . -- --depth=1 --single-branch --branch pr-branch
   ```
   - 5-10x faster than full clone
   - Sufficient for PR fixes

6. **Targeted testing**:
   ```bash
   # Only test changed packages, not entire suite
   git diff --name-only origin/main | grep '\.go$' | xargs -n1 dirname | sort -u | xargs -I{} go test -v ./{}
   ```
   - 3-5x faster than full test suite

7. **Background cleanup**:
   ```bash
   (cd / && rm -rf "$WORKSPACE") &
   ```
   - Non-blocking, don't wait for cleanup

### Testing and Validation

**For each severity tier** in Phase 5:

1. **Apply fixes** at this tier
2. **Run targeted tests** on affected packages only
3. **Run formatting** on changed files only
4. **Verify** no unintended changes with `git diff`
5. **Commit** only if tests pass
6. **Push** and verify CI starts
7. **Rollback** if tests fail, continue to next tier only if successful

**Language-specific test commands** (see README.md for full list):
- Go: `go test -v ./path/to/changed/package/...`
- Python: `pytest path/to/changed/module/ -v`
- JavaScript: `npm test -- --changedSince=origin/main`
- Rust: `cargo test --package affected_package`

### Error Handling

See AGENTS.md for full error handling and rollback strategies.

### Git Workflow

**Key steps**: Get PR branch via API → Create temp workspace → `gh pr checkout` → Verify branch → Fix → Test → Commit → Push → Cleanup

See `.github/copilot-instructions.md` for detailed bash examples.

### Language-Specific Adaptations

The skill automatically detects repository language and adapts commands.

**Auto-detection**:
```bash
# Detect language from changed files
CHANGED_FILES=$(gh pr diff ${PR_NUMBER} --name-only)

if echo "$CHANGED_FILES" | grep -q '\.go$'; then
  LANGUAGE="go"
elif echo "$CHANGED_FILES" | grep -q '\.py$'; then
  LANGUAGE="python"
elif echo "$CHANGED_FILES" | grep -q '\.\(js\|ts\)$'; then
  LANGUAGE="javascript"
elif echo "$CHANGED_FILES" | grep -q '\.rs$'; then
  LANGUAGE="rust"
fi
```

See README.md for complete language-specific command reference.

## Best Practices

1. **Work with PRs, not branches** - Use `gh pr list`, `gh pr view`, `gh pr checkout`
2. **Always verify branch** - Get branch name from `gh pr view --json headRefName` before checkout
3. **Use `gh pr checkout <number>`** - Safest method (handles verification automatically)
4. **Always use parallel Task calls** when launching multiple Phase 2 subagents
5. **Use isolated workspaces** - default `/tmp/warden-repos/` (never modify user's working directory unless `--in-place`)
6. **Respect test strategy** - skip tests if `--test-strategy none` or file types match `--skip-tests-for`
7. **Use Plan agent for Phase 3** - better at structured aggregation
8. **Shallow clone** for workspace setup (unless `--reuse-workspace`)
9. **Test according to strategy** - affected/full/smart/none
10. **Rollback per-tier** - don't throw away good fixes
11. **Clean up workspaces** after each PR (unless `--keep-workspace`)
12. **Respect fix limits** - honor `--max-fixes-per-tier`
13. **Flag based on strategy** - conservative flags more, aggressive flags less
14. **Comment on PR** if `--comment-on-pr` is set
15. **Respect parallelization limits** - `--max-parallel-prs` batching
16. **Apply file filters** - honor `--ignore-paths`, `--focus-paths`, `--max-file-size`
17. **Load configuration** from `~/.warden/config.yml` or `.warden/config.yml` if present

## Available Information

- Full workflow documentation: [README.md](README.md)
- Platform-agnostic guidance: [AGENTS.md](AGENTS.md)
- Configuration system: [docs/CONFIGURATION.md](docs/CONFIGURATION.md)
- GitHub Copilot instructions: [.github/copilot-instructions.md](.github/copilot-instructions.md)
- Cursor rules: [.cursorrules](.cursorrules)

## Development & Maintenance

**IMPORTANT**: See "Git Workflow" section above - always use PR-based workflow, NOT direct pushes to main.

When making significant changes to Warden (new features, workflow changes, enforcement mechanisms):

**Update README.md**:
- Keep it high-level and user-facing
- Update "How it works" workflow steps if phases change
- Update "Features" list for new capabilities
- Update "How Warden Ensures Quality" for validation changes
- Add new documentation references to appropriate sections
- **Avoid bloat**: Don't duplicate detailed parameter/configuration info (belongs in PARAMETERS.md, CONFIGURATION.md, EXAMPLES.md)

**Check for context bloat (but preserve enforcement)**:
- Detailed configuration examples → Move to EXAMPLES.md or PARAMETERS.md
- Technical implementation details → Move to platform-specific docs (CLAUDE.md, AGENTS.md)
- Verbose explanations → Keep README concise, link to detailed docs

**⚠️ CRITICAL: What is NOT bloat**:
- **Explicit enforcement instructions** - MANDATORY steps, BLOCKING checks, verification requirements
- **Required command sequences** - Phase 0 artifact creation, validation order, pre-commit checks
- **Error conditions** - What triggers rollback, what causes failures
- **"MUST" requirements** - These prevent agents from skipping steps
- **Verification scripts** - Concrete examples of checks to perform

**Principle**: If removing it would let an agent skip a step or misinterpret requirements, it's NOT bloat - it's enforcement. Bloat is redundant explanations and verbose examples, not mechanical requirements.

**README should contain**:
- Overview (what, why, how)
- Quick installation
- Basic usage patterns
- Key features summary
- Links to detailed documentation

**README should NOT contain**:
- Exhaustive parameter lists (→ PARAMETERS.md)
- Detailed configuration examples (→ EXAMPLES.md)
- Technical implementation details (→ AGENTS.md, WORKFLOW.md)
- Platform-specific instructions (→ CLAUDE.md, .cursorrules, etc.)
