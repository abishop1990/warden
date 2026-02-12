# GitHub Copilot Instructions for Warden

## About Warden

Warden is a cross-platform AI skill for comprehensive automated PR review and fixes. It analyzes CI failures, review comments, and code quality, then helps fix identified issues.

This skill works across GitHub Copilot, Claude Code, Cursor, and other AI coding assistants.

## Skill Workflow

Warden implements a structured 6-phase workflow:

1. **Discovery** - List and select PRs to analyze
2. **Parallel Analysis** - CI analysis, review comments, and staff engineer-level code review
3. **Planning** - Aggregate findings, deduplicate, and prioritize by severity (Critical > High > Medium > Low)
4. **User Interaction** - Select which issues to fix
5. **Execution** - Make fixes in temporary workspace, test, commit, and push
6. **Summary Report** - Comprehensive outcome report

See [README.md](README.md) for complete workflow documentation.

## Invocation with GitHub Copilot

```
@copilot /pr-review-and-fix
```

### Optional Parameters
- `--author <username>` - Review PRs by specific author (defaults to current user)
- `--repo <owner/repo>` - Target specific repository (defaults to current)
- `--state open|all` - PR state to review (defaults to open)
- `--limit <n>` - Max number of PRs to review (defaults to 10)

## Key Features

- **Multi-platform Support**: Works across all major AI coding assistants
- **Parallel Analysis**: Uses specialized analysis for CI, review comments, and code quality
- **CI/CD Integration**: Detects and diagnoses test failures, build errors, lint issues
- **Language-Agnostic**: Adapts to Go, Python, JavaScript/TypeScript, Rust, and more
- **Safe Execution**: Temporary workspaces, automated testing, rollback options

## Implementation Guidelines

When executing this skill:

1. **Follow the 6-phase workflow** documented in README.md
2. **Use parallel execution** where possible (Phase 2 analysis)
3. **Prioritize by severity**: Critical > High > Medium > Low
4. **Make minimal changes**: Surgical fixes only, no unnecessary refactoring
5. **Test before committing**: Always verify tests pass
6. **Use temporary workspaces**: `/tmp/pr-review-{pr-number}-{timestamp}`
7. **Handle errors gracefully**: Continue with other PRs if one fails
8. **Provide clear summaries**: Report what was done and what needs manual attention

## Temporary Workspace Management

```bash
WORKSPACE="/tmp/pr-review-${PR_NUMBER}-$(date +%s)"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
gh repo clone owner/repo .
git fetch origin pull/${PR_NUMBER}/head:pr-${PR_NUMBER}
git checkout pr-${PR_NUMBER}
# Work...
cd / && rm -rf "$WORKSPACE"
```

## Language-Specific Adaptations

The skill automatically adapts based on the repository language:

### Go Projects
- Formatting: `gofmt -s -w .`
- Testing: `go test -v <package>`
- Linting: `golangci-lint run`

### Python Projects
- Formatting: `black .` or `ruff format`
- Testing: `pytest <path>` or `python -m pytest`
- Linting: `ruff check` or `pylint`

### JavaScript/TypeScript Projects
- Formatting: `prettier --write .`
- Testing: `npm test` or `yarn test`
- Linting: `eslint .`

### Rust Projects
- Formatting: `cargo fmt`
- Testing: `cargo test`
- Linting: `cargo clippy`

## GitHub-Specific Features

When implementing with GitHub Copilot:
- Use `gh` CLI for GitHub operations (PR listing, comments, status)
- Leverage GitHub Actions for CI/CD integration
- Use Copilot Chat for complex multi-step workflows
- Test in different repository contexts

## Best Practices

- Keep fixes focused and minimal
- Provide clear, actionable commit messages
- Include examples for common use cases
- Handle errors gracefully with rollback options
- Confirm destructive actions with users
- Support dry-run modes where applicable
- Clean up temporary workspaces after completion

## Error Handling

- Graceful degradation if CI logs unavailable
- Rollback options for failed fixes
- Flag complex issues for manual review
- Continue with other PRs if one fails
- Always clean up temporary workspaces, even on failure
