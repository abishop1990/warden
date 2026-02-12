# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Warden is an open-source collection of cross-platform AI coding assistant skills. Skills are reusable, well-documented workflows that work across Claude Code, GitHub Copilot, Cursor, and other AI assistants.

## Repository Structure

- `skills/` - Individual skill definitions, each in its own directory with a `SKILL.md` file
- `AGENTS.md` - Unified instructions for all AI coding assistants (read this for general guidelines)
- Platform-specific config files: `CLAUDE.md` (this file), `.cursorrules`, `.github/copilot-instructions.md`

## Working with Skills

### Creating New Skills

1. Create directory: `skills/[skill-name]/`
2. Add `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: Clear description for AI matching
   version: 1.0.0
   platforms: [claude-code, github-copilot, cursor, codex]
   tags: [relevant, tags]
   ---
   ```
3. Document the workflow with clear phases
4. Include Claude Code specific subagent usage where applicable
5. Add language-specific adaptations

### Claude Code Specific Features

When documenting skills for Claude Code:
- Use the Task tool to launch specialized subagents (explore, task, general-purpose)
- Reference the full conversation context for complex workflows
- Leverage parallel tool execution for independent operations
- Use proper git workflow (avoid destructive operations without confirmation)

### Testing Skills

To test a skill implementation:
1. Read the SKILL.md file to understand the workflow
2. Follow the documented phases step-by-step
3. Use appropriate subagents for complex tasks
4. Verify error handling and edge cases
5. Test across different programming languages if applicable

## Available Skills

See `AGENTS.md` for the current list of available skills and their descriptions.

## Contributing

This is an open-source project. When adding or modifying skills:
- Maintain cross-platform compatibility
- Update AGENTS.md with new skill entries
- Test the skill workflow before committing
- Follow the documented skill format
- Keep documentation clear and actionable
