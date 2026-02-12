# AI Coding Agent Instructions

This file provides unified instructions for all AI coding assistants working with the Warden PR review and fix skill.

## About Warden

Warden is a cross-platform AI coding assistant skill for comprehensive automated PR review and fixes. It works across:
- Claude Code
- GitHub Copilot
- Cursor
- Codex
- Other AI coding assistants

## What This Skill Does

Analyzes CI failures, review comments, and code quality, then helps fix identified issues through a structured 6-phase workflow:

1. **Discovery** - List and select PRs to analyze
2. **Analysis** - Parallel analysis using multiple specialized agents (CI, review comments, staff engineer review)
3. **Planning** - Aggregate findings, deduplicate, and prioritize by severity
4. **User Interaction** - Select which issues to fix
5. **Execution** - Make fixes in temporary workspace, test, commit, and push
6. **Summary Report** - Comprehensive outcome report

## Key Features

- **Multi-platform Support**: Works across all major AI coding assistants
- **Parallel Analysis**: Uses specialized subagents for comprehensive review
- **CI/CD Integration**: Detects and diagnoses failures
- **Language-Agnostic**: Adapts to Go, Python, JavaScript/TypeScript, Rust, and more
- **Safe Execution**: Temporary workspaces, automated testing, rollback options

## Invocation

### Claude Code
Request PR review using natural language, referencing the pr-review-and-fix workflow.

### GitHub Copilot
```
@copilot /pr-review-and-fix
```

### Cursor
Request PR review in chat/composer using the pr-review-and-fix workflow.

## Implementation Guidelines

When executing this skill:

1. **Follow the 6-phase workflow** documented in README.md
2. **Use parallel execution** where possible (Phase 2 analysis)
3. **Prioritize by severity**: Critical > High > Medium > Low
4. **Make minimal changes**: Surgical fixes only
5. **Test before committing**: Always verify tests pass
6. **Use temporary workspaces**: Never modify user's working directory
7. **Handle errors gracefully**: Continue with other PRs if one fails
8. **Provide clear summaries**: Report what was done and what needs manual attention

## Language-Specific Commands

The skill adapts to the target repository's language:

- **Go**: `gofmt -s -w .`, `go test -v <package>`, `golangci-lint run`
- **Python**: `black .`, `pytest`, `ruff check`
- **JavaScript/TypeScript**: `prettier --write .`, `npm test`, `eslint .`
- **Rust**: `cargo fmt`, `cargo test`, `cargo clippy`

## General Guidelines

- Always confirm destructive actions with the user
- Provide dry-run or preview options when making changes
- Use appropriate error handling and graceful degradation
- Support multiple programming languages
- Document all changes in commit messages
- Follow repository-specific conventions and patterns
