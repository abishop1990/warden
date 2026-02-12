# AI Coding Agent Instructions

This file provides unified instructions for all AI coding assistants working with the Warden skills repository.

## Repository Purpose

Warden is an open-source collection of cross-platform AI coding assistant skills. These skills work across:
- Claude Code
- GitHub Copilot
- Cursor
- Codex
- Other AI coding assistants

## Repository Structure

```
warden/
├── skills/              # Individual skill definitions
│   └── [skill-name]/
│       └── SKILL.md    # Skill definition with YAML frontmatter
├── AGENTS.md           # This file - unified AI instructions
├── CLAUDE.md           # Claude Code specific instructions
├── .cursorrules        # Cursor specific rules
└── .github/
    └── copilot-instructions.md  # GitHub Copilot instructions
```

## Skill Format

Each skill follows this structure:

1. **YAML Frontmatter** - Metadata for AI agents to understand when to use the skill
   - `name`: Unique skill identifier
   - `description`: Clear description for skill matching
   - `version`: Semantic version
   - `platforms`: List of compatible AI assistants
   - `tags`: Searchable tags

2. **Documentation Sections**
   - Overview
   - Usage (with platform-specific invocation)
   - Workflow (detailed step-by-step process)
   - Implementation Notes
   - Language-Specific Adaptations (where applicable)
   - Future Enhancements

## Contributing New Skills

When creating a new skill:

1. Create a new directory under `skills/[skill-name]/`
2. Add a `SKILL.md` file with proper YAML frontmatter
3. Document the workflow clearly with numbered phases
4. Include platform-specific usage examples
5. Add language-specific adaptations where relevant
6. Consider error handling and edge cases

## Available Skills

### pr-review-and-fix
Comprehensive automated PR review that analyzes CI failures, review comments, and code quality, then helps fix identified issues.

**Triggers:** When user mentions PR review, PR fixes, CI failures, or code review automation.

See [skills/pr-review-and-fix/SKILL.md](skills/pr-review-and-fix/SKILL.md) for full documentation.

## General Guidelines

- Skills should be modular and self-contained
- Documentation should be clear enough for any AI agent to execute
- Include error handling and graceful degradation
- Support multiple programming languages where applicable
- Provide dry-run or preview options when making changes
- Always confirm destructive actions with the user
