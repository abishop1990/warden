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

## Installation

**One-line installer** (Recommended):
```bash
curl -fsSL https://raw.githubusercontent.com/abishop1990/warden/main/install.sh | bash
```

**Manual install**:
```bash
git clone https://github.com/abishop1990/warden.git ~/warden
cd ~/warden
```

Then say `"Run the Warden skill"` to your AI assistant.

**Full installation guide**: See [INSTALL.md](INSTALL.md) for:
- Platform-specific setup (Claude Code, Copilot, Cursor, Codex)
- Adding Warden to your workspace
- Custom installation paths
- Skill verification and troubleshooting
- Uninstallation

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

**GitHub Copilot** (in VSCode/IDE with this repo in workspace):
```
"Run the Warden skill"
"Execute Warden on my PRs"
```
Copilot reads `.github/copilot-instructions.md` automatically when in this repo.

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

### For Users

- **[INSTALL.md](INSTALL.md)** - Installation guide for all platforms
- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[EXAMPLES.md](docs/EXAMPLES.md)** - Real-world usage examples for every scenario
- **[PARAMETERS.md](docs/PARAMETERS.md)** - Complete reference for all configuration options
- **[SAFETY.md](docs/SAFETY.md)** - Safety features and best practices
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### For AI Platform Developers

- **[CLAUDE.md](CLAUDE.md)** - Claude Code integration guide
- **[AGENTS.md](AGENTS.md)** - Universal AI platform instructions
- **[.cursorrules](.cursorrules)** - Cursor integration guide
- **[copilot-instructions.md](.github/copilot-instructions.md)** - GitHub Copilot integration guide
- **[WORKFLOW.md](docs/WORKFLOW.md)** - Internal workflow phases
- **[COMMANDS.md](docs/COMMANDS.md)** - Command discovery and execution
- **[VALIDATION-ORDER.md](docs/VALIDATION-ORDER.md)** - Validation sequence requirements

## Configuration Options

Warden is highly configurable. You can request options using natural language:

### Review Depth
- **Standard**: Single generalist reviewer (fastest)
- **Thorough**: Security + performance reviewers
- **Comprehensive**: Security + performance + architecture reviewers
- **Custom**: Pick specific reviewers (security, performance, architecture, maintainability, testing)

**Examples:**
```
"Run Warden with security and performance reviewers"
"Use comprehensive review with all specialists"
```

### Testing Approach
- **None**: Skip tests (for documentation-only changes)
- **Affected**: Test only changed packages (default, fastest)
- **Full**: Run complete test suite
- **Smart**: Analyze dependencies and test affected areas

**Examples:**
```
"Run Warden and skip tests"
"Use full test suite for this review"
```

### Fix Behavior
- **Conservative**: Only high-confidence fixes (safest)
- **Balanced**: Mix of high and medium confidence (default)
- **Aggressive**: Include lower-confidence fixes (most thorough)

**Examples:**
```
"Use conservative fixes only"
"Be aggressive with fixes for this security issue"
```

### Safety Options
- Preview changes before pushing
- Protect specific branches from modifications
- Limit maximum files changed
- Create rollback branches
- Check for merge conflicts before starting

**Examples:**
```
"Require review before pushing changes"
"Create a rollback branch for safety"
"Protect the main branch"
```

**Full parameter reference**: See [PARAMETERS.md](docs/PARAMETERS.md) for technical details on all 50+ options.

## How Warden Ensures Quality

Warden validates all fixes before pushing to your PR:
- Runs build to ensure compilation
- Runs linting to catch code quality issues
- Runs tests to ensure functionality
- Only commits and pushes if ALL validations pass

This prevents broken CI and ensures fixes don't introduce new issues.

## Contributing

Contributions welcome! This is an open-source skill designed to work across all AI coding assistants.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Get started**: [QUICKSTART.md](QUICKSTART.md)

**Questions?** Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) or open an [issue](https://github.com/abishop1990/warden/issues).
