# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Warden PR review and fix skill.

## About Warden

Warden is a cross-platform AI skill for comprehensive automated PR review and fixes. Version 2.0 includes massively parallel execution, incremental fix validation, and platform-specific optimizations.

## Skill Overview

This skill implements a 6-phase workflow for PR review and automated fixes:

1. **Discovery** - Batch API call to list and select PRs
2. **Parallel Analysis** - Launch ALL subagents for ALL PRs simultaneously
3. **Planning** - Use Plan agent to aggregate, deduplicate, and prioritize findings
4. **User Interaction** - Present structured report and select which issues to fix
5. **Execution** - Incremental fixes by severity tier with validation and rollback
6. **Summary Report** - Comprehensive metrics and next steps

See [README.md](README.md) for complete workflow documentation.

## Claude Code Specific Implementation

### Available Subagents

Claude Code provides these specialized agents via the Task tool:

- **`Bash`** - Command execution specialist for running bash commands
- **`general-purpose`** - General-purpose agent for complex, multi-step tasks
- **`Explore`** - Fast agent specialized for exploring codebases
- **`Plan`** - Software architect agent for designing implementation plans

### Subagent Usage by Phase

**Phase 1: Discovery**
- **Agent**: Main agent
- **Task**: Single batch API call with `gh pr list --json`
- **Why**: Simple operation, no subagent needed

**Phase 2: Analysis (Massively Parallel with Context)**
- **Agent**: Multiple `general-purpose` agents (3-5 per PR, all in parallel, depth-dependent)
- **Context Gathering** (before launching subagents):
  1. **PR Metadata**: `gh pr view --json title,body,author` - understand PR intent
  2. **Repo AI Instructions**: Read `CLAUDE.md`, `AGENTS.md` - project conventions
  3. **Codebase Context**: Read README.md, package.json/go.mod, project structure
- **Task**: For each PR, launch parallel agents:
  1. CI Analysis: `gh pr checks` + log parsing
  2. Review Analysis: `gh pr view --json reviews,comments`
  3. Code Quality: `gh pr diff` + contextual analysis (with PR description, repo instructions, codebase overview)
  4. (Thorough) Security Review: Deep security focus
  5. (Thorough) Performance Review: Deep performance focus
  6. (Comprehensive) Architecture Review: Deep design focus
- **Why**: Complex multi-step analysis requiring autonomy and context
- **Parallelization**:
  - Standard: 9 agents for 3 PRs (3 per PR)
  - Thorough: 12 agents for 3 PRs (4 per PR)
  - Comprehensive: 15 agents for 3 PRs (5 per PR)

**Example parallel Task calls** (Standard depth):
```
Task(general-purpose, "Analyze CI failures for PR #123: fetch checks, parse logs, categorize failures")
Task(general-purpose, "Analyze review comments for PR #123: fetch comments, identify unresolved, categorize")
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
- **Task**: Aggregate findings from Phase 2, deduplicate, enrich with severity/complexity, group related issues, generate structured report
- **Why**: Architectural task requiring structured analysis and design thinking
- **Input**: All findings from Phase 2 subagents
- **Output**: Structured issue list per PR with severity, complexity, grouping

**Phase 4: User Interaction**
- **Agent**: Main agent
- **Task**: Present structured report, collect user selection
- **Why**: User interaction happens in main agent

**Phase 5: Execution**
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

**Phase 6: Summary**
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

4. **Incremental fix validation** in Phase 5:
   - Fix Critical tier → Test → Commit → Push
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

**Graceful degradation**:
- CI logs unavailable → Skip CI analysis, proceed with review + code analysis
- Review API fails → Skip review analysis, proceed with CI + code analysis
- Code diff fails → Skip code analysis, proceed with CI + reviews
- Test failures → Rollback severity tier, flag for manual review

**Rollback strategies**:
- **Per-tier**: If High fixes fail tests, rollback only High tier (keep Critical fixes)
- **Full**: If Critical fixes fail, abort entire PR and flag for manual review
- **Selective**: If specific fix causes failure, rollback only that commit

**Continue on failure**:
- If PR #1 fails completely, continue to PR #2
- Collect all failures for Phase 6 summary report
- Always clean up workspaces, even on failure

### Git Workflow

**Workspace setup**:
```bash
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Shallow clone for speed
gh repo clone owner/repo . -- --depth=1
git fetch --depth=1 origin pull/${PR_NUMBER}/head:pr-${PR_NUMBER}
git checkout pr-${PR_NUMBER}
```

**Commit format**:
```bash
git commit -m "[PR #${PR_NUMBER}] Fix: ${SEVERITY} - ${DESCRIPTION}

Fixed ${ISSUE_COUNT} ${SEVERITY} severity issues:
- [${ISSUE_ID}] ${ISSUE_1_SUMMARY} (${FILE}:${LINE})
- [${ISSUE_ID}] ${ISSUE_2_SUMMARY} (${FILE}:${LINE})

Tested: ${AFFECTED_PACKAGES}

Co-Authored-By: Warden <noreply@warden.dev>"
```

**Push and verify**:
```bash
git push origin pr-${PR_NUMBER}
sleep 5  # Wait for CI to start
gh pr checks ${PR_NUMBER} --watch
```

**Cleanup**:
```bash
# Background cleanup (non-blocking)
(cd / && rm -rf "$WORKSPACE") &
```

### Performance Expectations

For 3 PRs with ~500 lines changed each:

- **Phase 1**: 2s (batch API call)
- **Phase 2**: 35s (9 parallel agents vs 90s sequential)
- **Phase 3**: 10s (Plan agent aggregation)
- **Phase 4**: User interaction time (variable)
- **Phase 5**: 120s (incremental validation vs 180s sequential)
- **Phase 6**: 5s (summary generation)

**Total**:
- Standard: ~172s (1.7x faster)
- Thorough: ~187s (1.6x faster)
- Comprehensive: ~202s (1.4x faster)

### Subagent Selection Decision Tree

```
Is fix 1-5 lines, single file?
├─ YES → Main agent (direct edit)
└─ NO → Is fix 5-20 lines, 1-2 files?
    ├─ YES → Bash agent (scripted changes)
    └─ NO → Is fix 20+ lines or multi-file?
        ├─ YES → general-purpose agent
        └─ NO → Is fix architectural or >5 files?
            ├─ YES → Flag for manual review
            └─ NO → general-purpose agent
```

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

1. **Always use parallel Task calls** when launching multiple Phase 2 subagents
2. **Never modify user's working directory** - always use temporary workspace
3. **Test before committing** - no exceptions
4. **Use Plan agent for Phase 3** - better at structured aggregation
5. **Shallow clone** for workspace setup - much faster
6. **Test only affected packages** - not full test suite
7. **Rollback per-tier** - don't throw away good fixes
8. **Clean up in background** - don't block on workspace removal
9. **Provide detailed commit messages** - include issue IDs and affected files
10. **Flag complex changes** - don't attempt beyond automation scope

## Example Execution Flow

```
Phase 1: Discovery
→ Main agent: gh pr list --json (2s)

Phase 2: Analysis (Parallel)
→ Task(general-purpose, "CI analysis PR #123")
→ Task(general-purpose, "Review analysis PR #123")
→ Task(general-purpose, "Code review PR #123")
→ Task(general-purpose, "CI analysis PR #125")
→ Task(general-purpose, "Review analysis PR #125")
→ Task(general-purpose, "Code review PR #125")
[All 6 agents run simultaneously: 35s total]

Phase 3: Planning
→ Task(Plan, "Aggregate findings, deduplicate, prioritize")
[10s]

Phase 4: User Interaction
→ Main agent: Present report, get user selection
[User time]

Phase 5: Execution (PR #123)
→ Setup workspace (shallow clone: 5s)
→ Fix Critical tier (main agent: 2 simple fixes)
→ Test Critical (targeted: 8s)
→ Commit + Push Critical
→ Fix High tier (Bash agent: 3 moderate fixes)
→ Test High (targeted: 12s)
→ Commit + Push High
→ Cleanup (background)
[~30s per PR]

Phase 6: Summary
→ Main agent: Generate report (5s)
```

**Total: ~172s for 3 PRs**

## Available Information

- Full workflow documentation: [README.md](README.md)
- Platform-agnostic guidance: [AGENTS.md](AGENTS.md)
- GitHub Copilot instructions: [.github/copilot-instructions.md](.github/copilot-instructions.md)
- Cursor rules: [.cursorrules](.cursorrules)
