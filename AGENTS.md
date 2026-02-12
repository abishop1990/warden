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

See [docs/COMMANDS.md](docs/COMMANDS.md) for exact commands to execute per language.

---

## About Warden

Warden is a cross-platform AI coding assistant skill for comprehensive automated PR review and fixes. Version 1.2 features:
- **Massively parallel execution** across all PRs
- **Contextual review** with PR intent, repo conventions, codebase architecture
- **50+ configuration parameters** for complete control
- **5 specialized reviewers** (security, performance, architecture, maintainability, testing)
- **Flexible test strategies** (none/affected/full/smart)
- **Incremental fix validation** by severity tier
- **PR integration** (comment on PRs, update existing comments)
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

## Workflow Overview

6-phase workflow for PR review and automated fixes:

1. **Discovery** - Batch API call to list PRs (single call, not N calls)
2. **Analysis** - Launch ALL subagents for ALL PRs in parallel analyzing **three issue sources**:
   - **CI failures** (test failures, build errors, lint issues)
   - **Review comments** (requested changes, unresolved feedback)
   - **Code quality** (security, performance, architecture issues)
   - Context: PR description, repo conventions, codebase architecture
   - Review depth: standard/thorough/comprehensive
3. **Planning** - Aggregate all three sources, deduplicate, prioritize by severity
4. **User Interaction** - Present structured report, select fixes
5. **Execution** - Fix all issue types (CI + Review + Code), validate, push
6. **Summary Report** - Metrics and next steps

## Key Optimizations

**Parallel Execution**:
- Analyzing 3 PRs? Launch all 9 analysis subagents simultaneously (3 per PR)
- 2.5x faster than sequential

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

## Platform-Specific Invocation

### Claude Code
```
Review and fix PRs using the pr-review-and-fix workflow [OPTIONS]
```

**Common options**:
- `--reviewers security,performance` - Custom reviewers
- `--test-strategy affected|full|none` - Test approach
- `--fix-strategy conservative|balanced|aggressive` - Fix aggressiveness
- `--comment-on-pr` - Post findings to PR
- `--dry-run` - Preview only

**Implementation**:
- Use `general-purpose` agents for Phase 2 analysis (all in parallel, 3-5 per PR depending on config)
- Gather context: PR description + CLAUDE.md/AGENTS.md + codebase overview
- Use `Plan` agent for Phase 3 aggregation
- Use `Bash` agent for moderate fixes, `general-purpose` for complex fixes
- Respect all configuration parameters

### GitHub Copilot
```
@copilot /pr-review-and-fix
```
- Use `@github` mention for native PR integration
- Leverage GitHub Actions for CI insights

### Cursor
```
Review and fix PRs using the pr-review-and-fix workflow
```
- Use Composer mode for multi-file edits
- Leverage codebase-wide context

## Implementation Guidelines

1. **Use parallel execution** - Launch ALL Phase 2 subagents simultaneously
2. **Batch API calls** - Single `gh pr list --json` not N sequential calls
3. **Shallow clone** - `--depth=1` for 5-10x faster workspace setup
4. **Test targeted** - Only affected packages, not full suite (3-5x faster)
5. **Incremental fixes** - Fix/test/commit by severity tier, rollback per-tier on failure
6. **Background cleanup** - Non-blocking workspace removal
7. **Never modify user's working directory** - Always use `/tmp` workspace
8. **Provide structured reports** - Severity, complexity, affected files, line numbers

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

## Expected Performance

For 3 PRs (~500 lines changed each):

| Phase | Sequential | Optimized | Improvement |
|-------|-----------|-----------|-------------|
| Discovery | 6s | 2s | 3x faster |
| Analysis | 90s | 35s | 2.5x faster |
| Planning | 15s | 10s | 1.5x faster |
| Execution | 180s | 120s | 1.5x faster |
| **Total** | **291s** | **167s** | **1.7x faster** |

## General Guidelines

- Always confirm destructive actions with user
- Provide dry-run options (`--dry-run` parameter)
- Document all changes in detailed commit messages
- Follow repository-specific conventions
- Flag complex/risky changes for manual review
- Never skip tests - rollback instead

## Full Documentation

- Detailed workflow: [README.md](README.md)
- Claude Code specifics: [CLAUDE.md](CLAUDE.md)
- Cursor specifics: [.cursorrules](.cursorrules)
- GitHub Copilot specifics: [.github/copilot-instructions.md](.github/copilot-instructions.md)
