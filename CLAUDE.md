# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Warden PR review and fix skill.

## How to Invoke Warden

User must explicitly reference "Warden" for Claude to use this skill:

**Correct invocations**:
- "Run the Warden skill"
- "Execute Warden on my pull requests"
- "Use Warden to review and fix PRs"

**Required**: Navigate to or open the Warden repository so Claude reads this CLAUDE.md file.

## About Warden

Warden is a cross-platform AI skill for comprehensive automated PR review and fixes. Version 1.2 includes contextual review, comprehensive configurability (50+ parameters), and platform-specific optimizations.

**Execution Mode**: Warden executes actual commands and checks exit codes (see AGENTS.md for details).

See [docs/COMMANDS.md](docs/COMMANDS.md) for command discovery from repo docs.

## Skill Overview

Warden analyzes three issue sources (CI failures, review comments, code quality) - see AGENTS.md for details.

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

- **`Explore`** - Fast agent specialized for exploring codebases
- **`Plan`** - Software architect agent for designing implementation plans
- **Task** (default) - General-purpose agent for complex, multi-step tasks

**Note**: Subagents can use the Bash tool for command execution depending on their configuration.

### Subagent Usage by Phase

**Phase 1: Discovery**
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
  2. Review Analysis: `gh pr view --json reviews,comments`
  3. Code Quality: `gh pr diff` + contextual analysis (with PR description, repo instructions, codebase overview)
  4. (Thorough) Security Review: Deep security focus
  5. (Thorough) Performance Review: Deep performance focus
  6. (Comprehensive) Architecture Review: Deep design focus
- **Why**: Complex multi-step analysis requiring autonomy and context
- **Batching Strategy**: Max 5 PRs per batch to prevent overload (see AGENTS.md for details).

**Parallelization per batch**:
  - Standard: 15 agents for 5 PRs (3 per PR)
  - Thorough: 20 agents for 5 PRs (4 per PR)
  - Comprehensive: 25 agents for 5 PRs (5 per PR)

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

**Phase 4: User Interaction (MANDATORY)**
- **Agent**: Main agent
- **Task**: Present report, get approval, WAIT for response
- **Why**: User interaction happens in main agent
- **Details**: See AGENTS.md Phase 4 for complete requirements (report format, approval options, wait protocol)

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
5. **Never modify user's working directory** - always use temporary workspace
6. **Respect test strategy** - skip tests if `--test-strategy none` or file types match `--skip-tests-for`
7. **Use Plan agent for Phase 3** - better at structured aggregation
8. **Shallow clone** for workspace setup (unless `--reuse-workspace`)
9. **Test according to strategy** - affected/full/smart/none
10. **Rollback per-tier** - don't throw away good fixes
11. **Clean up in background** (unless `--keep-workspace`)
12. **Respect fix limits** - honor `--max-fixes-per-tier`
13. **Flag based on strategy** - conservative flags more, aggressive flags less
14. **Comment on PR** if `--comment-on-pr` is set
15. **Respect parallelization limits** - `--max-parallel-prs` and `--max-parallel-agents`
16. **Apply file filters** - honor `--ignore-paths`, `--focus-paths`, `--max-file-size`
17. **Send notifications** if webhook/Slack/Jira configured

## Available Information

- Full workflow documentation: [README.md](README.md)
- Platform-agnostic guidance: [AGENTS.md](AGENTS.md)
- GitHub Copilot instructions: [.github/copilot-instructions.md](.github/copilot-instructions.md)
- Cursor rules: [.cursorrules](.cursorrules)
