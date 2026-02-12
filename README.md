# Warden

An open-source collection of cross-platform AI coding assistant skills.

## Overview

Warden provides reusable, well-documented workflows (skills) that work across multiple AI coding assistants:

- **Claude Code** - Anthropic's AI pair programmer
- **GitHub Copilot** - GitHub's AI assistant
- **Cursor** - AI-first code editor
- **Codex** - And other AI coding tools

Each skill is platform-agnostic with specific invocation examples for each tool.

## Repository Structure

```
warden/
├── skills/              # Individual skill definitions
│   └── [skill-name]/
│       └── SKILL.md    # Skill documentation with YAML frontmatter
├── AGENTS.md           # Unified instructions for all AI assistants
├── CLAUDE.md           # Claude Code specific instructions
├── .cursorrules        # Cursor specific rules
└── .github/
    └── copilot-instructions.md  # GitHub Copilot instructions
```

## Available Skills

### pr-review-and-fix

Comprehensive automated PR review that analyzes CI failures, review comments, and code quality, then helps fix identified issues.

**Features:**
- Parallel analysis using multiple specialized agents
- CI/CD failure detection and diagnosis
- Review comment analysis
- Staff engineer-level code review
- Automated fix suggestions with testing
- Multi-language support (Go, Python, JavaScript/TypeScript, Rust)

**Usage:**
- **Claude Code**: Request PR review using natural language
- **GitHub Copilot**: `@copilot /pr-review-and-fix`
- **Cursor**: Request PR review in chat/composer

[View full documentation →](skills/pr-review-and-fix/SKILL.md)

## Usage

### For AI Assistants

The AI assistant you're using will automatically read the appropriate configuration file:
- Claude Code reads `CLAUDE.md` and `AGENTS.md`
- Cursor reads `.cursorrules` and `AGENTS.md`
- GitHub Copilot reads `.github/copilot-instructions.md`

### For Developers

1. **Browse available skills** in the `skills/` directory
2. **Read skill documentation** to understand the workflow
3. **Invoke skills** using your AI assistant's preferred method
4. **Contribute new skills** following the format in `AGENTS.md`

## Skill Format

Each skill includes:

```yaml
---
name: skill-name
description: Clear description for AI matching
version: 1.0.0
platforms: [claude-code, github-copilot, cursor, codex]
tags: [relevant, tags]
---
```

Followed by:
- **Overview**: What the skill does
- **Usage**: Platform-specific invocation
- **Workflow**: Step-by-step phases
- **Implementation Notes**: Technical details
- **Language-Specific Adaptations**: Commands for different languages
- **Future Enhancements**: Planned improvements

## Contributing

We welcome contributions! To add a new skill:

1. Create `skills/[your-skill-name]/SKILL.md`
2. Follow the YAML frontmatter format
3. Document the workflow clearly
4. Include platform-specific usage
5. Add language adaptations where relevant
6. Update `AGENTS.md` with the new skill
7. Submit a pull request

See [AGENTS.md](AGENTS.md) for detailed contribution guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Inspired by the growing ecosystem of AI coding assistants and the need for reusable, cross-platform workflows.
