# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Warden PR review and fix skill.

## About Warden

Warden is a cross-platform AI skill for comprehensive automated PR review and fixes. It analyzes CI failures, review comments, and code quality, then helps fix identified issues.

## Skill Overview

This skill implements a 6-phase workflow for PR review and automated fixes:

1. **Discovery** - List and select PRs to analyze
2. **Parallel Analysis** - Launch specialized subagents for CI, review comments, and staff engineer review
3. **Planning** - Aggregate findings, deduplicate, prioritize by severity
4. **User Interaction** - Select which issues to fix
5. **Execution** - Make fixes in temporary workspace, test, commit, push
6. **Summary Report** - Comprehensive outcome report

See [README.md](README.md) for complete workflow documentation.

## Claude Code Specific Implementation

### Subagent Usage

When executing this skill in Claude Code, use the Task tool to launch specialized subagents:

**Phase 2: Analysis (Parallel)**
- **task agent** - CI log analysis, test running
- **explore agent** - Code searching, review comment analysis
- **general-purpose agent** - Complex multi-file fixes

Launch these subagents in parallel for maximum efficiency.

### Workflow Execution

1. **Read the full workflow** from README.md before starting
2. **Use parallel tool calls** where operations are independent
3. **Create temporary workspace** for all PR modifications
4. **Never modify user's working directory** directly
5. **Test before committing** - only commit if tests pass
6. **Use appropriate subagents** based on task complexity

### Testing and Validation

For each PR fix:
- Identify affected packages from changed files
- Run language-specific tests (e.g., `go test -v <package>` for Go)
- Run formatting tools (e.g., `gofmt -s -w .` for Go)
- Verify no unintended changes: `git diff`
- Only commit if all tests pass

### Error Handling

- Gracefully degrade if CI logs unavailable
- Provide rollback options for failed fixes
- Flag complex issues for manual review
- Continue with other PRs if one fails
- Always clean up temporary workspaces

## Git Workflow

When making fixes:
- Create temporary workspace: `/tmp/pr-review-{pr-number}-{timestamp}`
- Clone repo and checkout PR branch
- Make minimal, surgical changes
- Test thoroughly
- Commit with format: `[PR #{number}] Fix: {description}`
- Push to PR branch
- Clean up temporary workspace

## Language-Specific Adaptations

The skill automatically adapts based on the repository language. See README.md for complete language-specific commands for Go, Python, JavaScript/TypeScript, and Rust.

## Available Information

All skill documentation is in [README.md](README.md). Platform-agnostic guidance is in [AGENTS.md](AGENTS.md).
