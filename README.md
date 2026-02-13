# Warden - Automated PR Pre-Review Validation

Automated PR validation that catches and fixes issues before human review, ensuring every PR is review-ready.

[![Version](https://img.shields.io/badge/version-1.2.0-blue)](https://github.com/abishop1990/warden)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Parameters](https://img.shields.io/badge/parameters-28_core-orange)](docs/PARAMETERS.md)

## Overview

Warden is an AI coding assistant that validates **Pull Requests before human review**, identifying and auto-fixing issues (CI failures, review comments, code quality problems) to reduce review churn and ensure every PR is review-ready.

**How it works**:
1. Developer creates PR (may have CI failures, review feedback, code issues)
2. **Warden discovers validation commands** (Phase 0 - MANDATORY) from repo's AI instructions, CI configs, and saves to artifact
3. Warden analyzes **three issue sources**: CI failures + review comments + code quality
4. **Warden re-verifies CI status** (Gap #16 fix) before presenting report - prevents stale data
5. Warden identifies and prioritizes issues by severity using FRESH CI data
6. Warden makes fixes addressing **all three sources**
7. **Warden validates before push** using discovered commands (build → lint → format → test)
8. Warden pushes fixes back to the same PR only if ALL validations pass
9. PR is updated with fixes, CI runs again

Works across multiple AI platforms:
- **Claude Code** - Anthropic's AI pair programmer
- **GitHub Copilot** - GitHub's AI assistant
- **Cursor** - AI-first code editor
- **Codex** - OpenAI's code model
- And other AI coding assistants

## Features

- **Isolated Workspaces**: Each PR in its own temp directory - never modifies your working directory
- **Massively Parallel Analysis**: Analyzes multiple PRs simultaneously with specialized agents
- **Contextual Review**: Understands PR intent, repo conventions, and codebase architecture
- **Mandatory Validation**: Phase 0 discovers commands, Phase 6 validates before push (prevents CI failures) - mechanically enforced
- **Ticket Integration**: Compares PRs against JIRA/Aha/Linear tickets, detects scope divergence and missing requirements
- **Fully Configurable**: 28 core parameters with config file support (`~/.warden/config.yml`) - 47 total including advanced
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

**Full installation guide**: See [docs/INSTALL.md](docs/INSTALL.md) for:
- Platform-specific setup (Claude Code, Copilot, Cursor, Codex)
- Adding Warden to your workspace
- Custom installation paths
- Skill verification and troubleshooting
- Uninstallation

## Quick Start

**5-minute introduction**: See [docs/QUICKSTART.md](docs/QUICKSTART.md)

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

**Cleanup workspaces**:
```
"Clean up Warden workspaces"
"Clear Warden data"
"Delete Warden temp directories"
```

See [CONFIGURATION.md](docs/CONFIGURATION.md) for workspace setup and [PARAMETERS.md](docs/PARAMETERS.md) for all options (25 core + 19 advanced).

## Documentation

### For Users

- **[docs/INSTALL.md](docs/INSTALL.md)** - Installation guide for all platforms
- **[docs/QUICKSTART.md](docs/QUICKSTART.md)** - Get started in 5 minutes
- **[CONFIGURATION.md](docs/CONFIGURATION.md)** - Configuration system (config files, workspace modes, setup)
- **[TICKET-INTEGRATION.md](docs/TICKET-INTEGRATION.md)** - JIRA/Aha/Linear integration for ticket alignment analysis
- **[EXAMPLES.md](docs/EXAMPLES.md)** - Real-world usage examples for every scenario
- **[PARAMETERS.md](docs/PARAMETERS.md)** - Complete reference for all configuration options
- **[SAFETY.md](docs/SAFETY.md)** - Safety features and best practices
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### For AI Platform Developers

- **[CLAUDE.md](CLAUDE.md)** - Claude Code integration guide
- **[AGENTS.md](AGENTS.md)** - Universal AI platform instructions
- **[.cursorrules](.cursorrules)** - Cursor integration guide
- **[copilot-instructions.md](.github/copilot-instructions.md)** - GitHub Copilot integration guide
- **[WORKFLOW.md](docs/WORKFLOW.md)** - Internal workflow phases (8 phases)
- **[PHASE-0-DISCOVERY.md](docs/PHASE-0-DISCOVERY.md)** - Mandatory command discovery with artifact enforcement
- **[COMMANDS.md](docs/COMMANDS.md)** - Command discovery and execution
- **[VALIDATION-ORDER.md](docs/VALIDATION-ORDER.md)** - Validation sequence requirements

## Configuration

Warden is highly configurable through natural language or parameters:

**Key configuration areas**:
- **Review depth**: Standard (1 reviewer), Thorough (2), Comprehensive (3+), or custom reviewers
- **Test strategy**: None, Affected (default), Full, or Smart
- **Fix approach**: Conservative, Balanced (default), or Aggressive
- **Workspace**: Isolated temp dirs (default), custom location, or in-place

**Example requests**:
```
"Run Warden with security and performance reviewers"
"Use full test suite and conservative fixes"
"Create a rollback branch for safety"
```

**Detailed documentation**:
- [CONFIGURATION.md](docs/CONFIGURATION.md) - Config files, workspace modes, setup
- [PARAMETERS.md](docs/PARAMETERS.md) - Complete parameter reference (28 core + 19 advanced)
- [EXAMPLES.md](docs/EXAMPLES.md) - Real-world usage examples
- [PHASE-0-DISCOVERY.md](docs/PHASE-0-DISCOVERY.md) - Validation command discovery (Gap #13 fix)
- [REVIEW-COMMENTS.md](docs/REVIEW-COMMENTS.md) - Review comment thread fetching (Gap #15 fix)
- [DIAGNOSTIC-PUSH-PREVENTION.md](docs/DIAGNOSTIC-PUSH-PREVENTION.md) - Blocking test failures before push (Gap #16 fix)
- [CI-REVERIFICATION.md](docs/CI-REVERIFICATION.md) - CI status re-checking (prevents stale data)

## How Warden Ensures Quality

**Phase 0 (MANDATORY)**: Discovers validation commands from your repo
- AI instruction files (CLAUDE.md, .cursorrules, etc.)
- CI configuration (.github/workflows/*.yml)
- Language-specific configs (Makefile, package.json)
- Saves to artifact: `.warden-validation-commands.sh`

**Phase 4 (MANDATORY)**: Re-verifies CI status before presenting report
- Prevents stale CI data from causing wrong recommendations
- Re-fetches CI status for all PRs
- Compares with Phase 1 initial state
- Flags PRs where CI changed (new failures or resolutions)
- Cannot present report without fresh CI check

**Phase 6 (MANDATORY)**: Validates all fixes before pushing
- **BLOCKING CHECK**: Verifies Phase 0 artifact exists
- Sources discovered commands from artifact
- Runs build to ensure compilation
- Runs linting to catch code quality issues (including formatters like gofmt, black, prettier)
- **ABSOLUTE BLOCKING**: Runs tests to ensure functionality (Gap #16 fix)
  - Tests MUST pass 100% before ANY push
  - No "diagnostic pushes" (pushing partial fixes while debugging)
  - No "push to save progress" with failing tests
  - Uses `set -euo pipefail` to prevent bypassing
- Only commits and pushes if ALL validations pass

**Enforcement**:
- Phase 6 cannot execute without Phase 0 artifact (Gap #13 fix)
- Phase 6 cannot push with failing tests (Gap #16 fix - Diagnostic Push Prevention)
- Phase 5 (User Interaction) uses fresh CI data from Phase 4 (prevents stale recommendations)
- ABSOLUTE BLOCKING using `set -euo pipefail` - no bypassing allowed

This prevents broken CI, ensures fixes don't introduce new issues, guarantees accurate reporting, and blocks "diagnostic push" anti-pattern. See [PHASE-0-DISCOVERY.md](docs/PHASE-0-DISCOVERY.md), [CI-REVERIFICATION.md](docs/CI-REVERIFICATION.md), and [DIAGNOSTIC-PUSH-PREVENTION.md](docs/DIAGNOSTIC-PUSH-PREVENTION.md) for technical details.

## Contributing

Contributions welcome! This is an open-source skill designed to work across all AI coding assistants.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Get started**: [docs/QUICKSTART.md](docs/QUICKSTART.md)

**Questions?** Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) or open an [issue](https://github.com/abishop1990/warden/issues).
