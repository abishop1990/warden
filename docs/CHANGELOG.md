# Changelog

All notable changes to Warden will be documented in this file.

## [1.2.0] - 2025-02-12

### Added
- **Phase 4 User Approval**: Mandatory user approval step before executing fixes, prevents AI from jumping directly from planning to execution
- **Installation System**: Complete skill installation infrastructure with one-line installer, skill manifest, and platform-specific guides
- **Command Discovery**: Automatically discovers build/lint/test commands from repo's AI instruction files (CLAUDE.md, .github/workflows/, etc.) instead of hard-coded defaults
- **Three Issue Sources**: Explicitly analyzes CI failures + review comments + code quality issues
- **Complete Validation**: Build → Lint → Format → Test sequence before every push (prevents CI failures)
- **Execution Mode**: Clear guidance that this is hands-on command execution, not conceptual review
- **50+ Configuration Parameters**: Complete control over review depth, test strategies, fix strategies, safety features
- **Specialized Reviewers**: Security, performance, architecture, maintainability, testing experts
- **Contextual Review**: Reads PR description, repo AI instructions, and codebase overview for context-aware analysis
- **Isolated Workspaces**: Each PR in its own temp directory - never modifies working directory
- **Modular Documentation**: Reduced from 4,446 to 2,853 lines (36% reduction) for better context management
- **Safety Features**: Branch protection, pre-push review, rollback branches, validation enforcement
- **Platform Optimizations**: Specific guidance for Claude Code, GitHub Copilot, Cursor

#### Installation Files
- `skill.json` - Skill manifest with metadata and platform compatibility
- `package.json` - npm-style package for future skill registries
- `INSTALL.md` - Comprehensive installation guide for all platforms
- `install.sh` - One-line installer: `curl -fsSL https://raw.githubusercontent.com/abishop1990/warden/main/install.sh | bash`
- `uninstall.sh` - Clean removal script with confirmation

### Fixed
- **Phase 4 Gap**: AI platforms now must consolidate findings, present report, and wait for user approval before execution
- **Validation Order**: Enforces test BEFORE push (not after) to prevent broken code reaching CI
- **Branch Verification**: Uses `gh pr checkout` to ensure correct PR branch
- **Workspace Cleanup**: Verified synchronous cleanup prevents disk space issues
- **Multi-push Cycles**: Local validation (build+lint+test) prevents multiple push/fix iterations
- **README Clarity**: Removed AI-focused content, reorganized into user vs developer sections, replaced CLI flags with natural language examples

### Changed
- **Documentation Structure**: Moved from monolithic README to modular docs/ directory
- **Invocation**: Natural language examples instead of fake slash commands
- **Parameter Count**: Updated from "40+" to "50+" (actual count: 59 parameters)

### Documentation
- `README.md` - User-focused overview with natural language examples
- `INSTALL.md` - Platform-specific installation guide
- `QUICKSTART.md` - 5-minute introduction (146 lines)
- `docs/WORKFLOW.md` - 6-phase workflow (105 lines)
- `docs/VALIDATION-ORDER.md` - Critical validation sequence (91 lines)
- `docs/COMMANDS.md` - Command discovery (72 lines)
- `docs/PARAMETERS.md` - Complete parameter reference (415 lines)
- `docs/EXAMPLES.md` - Usage examples (628 lines)
- `docs/TROUBLESHOOTING.md` - Common issues (731 lines)
- `docs/SAFETY.md` - Safety features (293 lines)

## [1.0.0] - Initial Release

### Added
- Basic PR review and fix workflow
- CI failure analysis
- Review comment analysis
- Code quality review
- Incremental fix validation by severity tier
- Multi-language support (Go, Python, JavaScript/TypeScript, Rust)
- Cross-platform support (Claude Code, GitHub Copilot, Cursor)

---

**Versioning**: Warden follows [Semantic Versioning](https://semver.org/)
- MAJOR: Breaking changes
- MINOR: New features (backwards compatible)
- PATCH: Bug fixes (backwards compatible)
