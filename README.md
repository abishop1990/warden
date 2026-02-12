# Warden - PR Review and Fix

Cross-platform AI skill for comprehensive automated PR review and fixes.

[![Version](https://img.shields.io/badge/version-1.2.0-blue)](https://github.com/abishop1990/warden)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Overview

Warden is an AI coding assistant skill that reviews **existing Pull Requests**, identifies issues (CI failures, review comments, code quality problems), and automatically fixes them by pushing validated changes back to the PR.

**How it works**:
1. Developer creates PR (may have CI failures, review feedback, code issues)
2. Warden analyzes the existing PR
3. Warden identifies specific issues to fix
4. Warden makes fixes and validates them locally (build + lint + test)
5. Warden pushes fixes back to the same PR
6. PR is updated with fixes, CI runs again

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

### Basic Usage

#### Claude Code
```
Review and fix PRs using the pr-review-and-fix workflow
```

#### GitHub Copilot
```
@copilot /pr-review-and-fix
```

#### Cursor
```
Review and fix PRs using the pr-review-and-fix workflow
```

### Common Commands

```bash
# Review all your open PRs with standard settings
warden

# Preview what would be fixed (no changes)
warden --dry-run

# Security-focused review with full test suite
warden --reviewers security,testing --test-strategy full

# Conservative fixes for production code
warden --fix-strategy conservative --require-review-before-push

# Comprehensive audit with all safety features
warden \
  --reviewers security,performance,architecture \
  --test-strategy full \
  --fix-strategy conservative \
  --protect-branches main,master \
  --create-rollback-branch
```

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
