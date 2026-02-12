# Warden - PR Review and Fix

Cross-platform AI skill for comprehensive automated PR review and fixes.

[![Version](https://img.shields.io/badge/version-1.2.0-blue)](https://github.com/abishop1990/warden)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Parameters](https://img.shields.io/badge/parameters-50+-orange)](docs/PARAMETERS.md)

## Overview

Warden is an AI coding assistant skill that reviews **existing Pull Requests**, identifies issues (CI failures, review comments, code quality problems), and automatically fixes them by pushing validated changes back to the PR.

**How it works**:
1. Developer creates PR (may have CI failures, review feedback, code issues)
2. Warden analyzes **three issue sources**: CI failures + review comments + code quality
3. **Warden discovers validation commands** from repo's AI instructions (CLAUDE.md, .github/workflows/, etc.)
4. Warden identifies and prioritizes issues by severity
5. Warden makes fixes addressing **all three sources** and validates using **the repo's own commands**
6. Warden pushes fixes back to the same PR
7. PR is updated with fixes, CI runs again

Works across multiple AI platforms:
- **Claude Code** - Anthropic's AI pair programmer
- **GitHub Copilot** - GitHub's AI assistant
- **Cursor** - AI-first code editor
- **Codex** - And other AI coding tools

## Features

- **Isolated Workspaces**: Each PR in its own temp directory - never modifies your working directory
- **Massively Parallel Analysis**: Analyzes multiple PRs simultaneously with specialized agents
- **Contextual Review**: Understands PR intent, repo conventions, and codebase architecture
- **Complete Validation**: Build + Lint + Test before every push (prevents CI failures)
- **Fully Configurable**: 50+ parameters for review depth, testing, fixes, output, and integrations
- **Multiple Review Specialists**: Security, performance, architecture, maintainability, testing experts
- **Flexible Test Strategies**: none/affected/full/smart with granular control
- **CI/CD Integration**: Detects and diagnoses test failures, build errors, and lint issues
- **Incremental Validation**: Fixes and tests by severity tier with per-tier rollback
- **Safety Features**: Branch protection, pre-push review, rollback branches, validation enforcement
- **Multi-Language Support**: Auto-detects or override for Go, Python, JavaScript/TypeScript, Rust, and more

## Quick Start

**5-minute introduction**: See [QUICKSTART.md](QUICKSTART.md)

### How to Use

This is an AI skill - your AI assistant reads the instruction files in this repository and executes the workflow.

**Claude Code** (in this repo directory):
```
"Run the Warden skill"
"Execute the Warden protocol on my open PRs"
"Use Warden to review and fix my pull requests"
```

**GitHub Copilot** (with this repo in workspace):
```
@github "Run the Warden skill from the instructions"
@github "Execute the Warden protocol on my PRs"
```

**Cursor** (with this repo in workspace):
```
"Run the Warden skill"
"Execute Warden on my pull requests"
```

**How it works**:
1. Navigate to or open the Warden repository in your editor
2. AI reads `CLAUDE.md` / `.cursorrules` / `.github/copilot-instructions.md`
3. Say "Run Warden" or "Execute the Warden skill"
4. AI follows the workflow documented in this repo

### Example Requests

**Basic review**:
```
"Run Warden on my open PRs"
"Execute the Warden skill to fix my pull requests"
```

**With specific parameters** (the AI will understand these):
```
"Run Warden with security and testing focus, use full test suite"
  → Uses: --reviewers security,testing --test-strategy full

"Execute Warden with conservative fixes and require review before pushing"
  → Uses: --fix-strategy conservative --require-review-before-push

"Run Warden for a comprehensive security audit with all safety features"
  → Uses: --reviewers security,performance,architecture
          --test-strategy full --fix-strategy conservative
```

**Preview mode**:
```
"Run Warden in dry-run mode to preview issues without making changes"
  → Uses: --dry-run
```

**Target specific PRs**:
```
"Run Warden on PR #123"
"Execute Warden on PRs #123, #125, and #127"
```

See [PARAMETERS.md](docs/PARAMETERS.md) for all 50+ configuration options.

## Documentation

### Essential Reading

- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[VALIDATION-ORDER.md](docs/VALIDATION-ORDER.md)** - **CRITICAL**: Correct validation sequence (read this!)
- **[SAFETY.md](docs/SAFETY.md)** - Safety features and best practices

### Detailed Guides

- **[COMMANDS.md](docs/COMMANDS.md)** - **Exact commands to execute** (not conceptual review!)
- **[PARAMETERS.md](docs/PARAMETERS.md)** - Complete reference for all 50+ parameters
- **[WORKFLOW.md](docs/WORKFLOW.md)** - How Warden works, phase by phase
- **[EXAMPLES.md](docs/EXAMPLES.md)** - Real-world usage examples for every scenario
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### Platform Configuration

- **[CLAUDE.md](CLAUDE.md)** - Claude Code specific configuration
- **[AGENTS.md](AGENTS.md)** - Unified instructions for all AI platforms
- **[.cursorrules](.cursorrules)** - Cursor configuration
- **[copilot-instructions.md](.github/copilot-instructions.md)** - GitHub Copilot configuration

## Key Parameters

Full details in [PARAMETERS.md](docs/PARAMETERS.md).

### Review Control
- `--review-depth standard|thorough|comprehensive` - Preset review depths (1-3 reviewers)
- `--reviewers <list>` - Custom reviewer selection (generalist, security, performance, architecture, maintainability, testing)
- `--review-focus <area>` - Target specific concern area

### Test Strategy
- `--test-strategy none|affected|full|smart` - Testing approach
- `--test-on-severity <levels>` - Only test when fixing certain severities
- `--test-timeout <seconds>` - Maximum test duration

### Fix Strategy
- `--fix-strategy conservative|balanced|aggressive` - Fix approach and confidence threshold
- `--max-fixes-per-tier <n>` - Limit fixes per severity tier
- `--auto-commit-on-success` - Auto-commit if tests pass (default: true)
- `--dry-run` - Preview only, make no changes

### Safety Features
- `--require-review-before-push` - Show diff and confirm before pushing
- `--protect-branches <list>` - Never push to these branches (default: main,master,production)
- `--max-files-changed <n>` - Abort if changes exceed limit
- `--create-rollback-branch` - Create backup before making fixes
- `--check-conflicts-before-fix` - Detect merge conflicts before starting

### Output & Reporting
- `--output-format text|json|markdown|html` - Report format
- `--save-report <path>` - Save summary to file
- `--save-metrics <path>` - Track metrics over time
- `--verbose` - Detailed logging
- `--quiet` - Minimal output

## Platform Configuration

Warden automatically works with your AI assistant through platform-specific configuration files:
- Claude Code reads `CLAUDE.md` and `AGENTS.md`
- Cursor reads `.cursorrules` and `AGENTS.md`
- GitHub Copilot reads `.github/copilot-instructions.md`

## Critical: Validation Order

**Always validate BEFORE pushing!** See [VALIDATION-ORDER.md](docs/VALIDATION-ORDER.md) for details.

The correct order is:
1. Apply fixes
2. **RUN BUILD** (BLOCKING - ensure compilation)
3. **RUN LINT** (BLOCKING - catch code quality issues)
4. Run formatting (auto-fix style)
5. **RUN TESTS** (BLOCKING - ensure functionality)
6. Commit (only if ALL validations passed)
7. Push (only after commit)
8. Clean up workspace

**Never push code without full validation.** This prevents CI failures and multiple push/fix cycles.

## Contributing

Contributions welcome! This is an open-source skill designed to work across all AI coding assistants.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Version

**1.2.0** - Feature-rich release with comprehensive configurability, contextual review, platform optimizations, and enhanced safety features.

See [CHANGELOG.md](CHANGELOG.md) for version history.

### What's New in 1.2

- **Contextual Review**: Reads PR description, repo AI instructions, and codebase overview
- **Configurable Review Depth**: Standard/Thorough/Comprehensive presets (1-3+ reviewers)
- **Specialized Reviewers**: Security, performance, architecture, maintainability, testing experts
- **Flexible Test Strategies**: none/affected/full/smart with granular control
- **Enhanced Safety**: Branch protection, pre-push review, rollback branches, validation enforcement
- **50+ Configuration Parameters**: Complete control over every aspect of review and fixes
- **Validation Order Enforcement**: Mandatory test-before-push workflow (see VALIDATION-ORDER.md)
- **Modular Documentation**: Reduced context size with focused, reference-style docs

---

**Get started**: [QUICKSTART.md](QUICKSTART.md)

**Questions?** Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) or open an [issue](https://github.com/abishop1990/warden/issues).
