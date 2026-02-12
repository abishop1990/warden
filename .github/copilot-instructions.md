# GitHub Copilot Instructions for Warden

## About This Repository

Warden is an open-source collection of cross-platform AI coding assistant skills. These skills are designed to work across multiple AI assistants including GitHub Copilot, Claude Code, Cursor, and Codex.

## Repository Structure

```
warden/
├── skills/              # Skill definitions
│   └── [skill-name]/
│       └── SKILL.md    # Skill with YAML frontmatter
├── AGENTS.md           # Unified AI instructions
├── CLAUDE.md           # Claude Code instructions
├── .cursorrules        # Cursor rules
└── .github/
    └── copilot-instructions.md  # This file
```

## Working with Skills

### Understanding Skills

Each skill in the `skills/` directory contains:
- **YAML Frontmatter**: Metadata (name, description, version, platforms, tags)
- **Documentation**: Overview, usage, workflow, implementation notes
- **Platform-specific examples**: Including GitHub Copilot invocation patterns

### Using Skills with Copilot

Skills can be invoked using GitHub Copilot's slash command pattern:
```
@copilot /[skill-name]
```

For example:
```
@copilot /pr-review-and-fix
```

### Creating New Skills

When helping create new skills:

1. **Create the skill directory**: `skills/[skill-name]/`

2. **Add SKILL.md with frontmatter**:
   ```yaml
   ---
   name: skill-name
   description: Clear, concise description
   version: 1.0.0
   platforms: [github-copilot, claude-code, cursor, codex]
   tags: [relevant, tags, here]
   ---
   ```

3. **Document the workflow**:
   - Break down into clear phases
   - Number steps explicitly
   - Include error handling
   - Add language-specific adaptations

4. **Include Copilot usage examples**:
   - Show slash command invocation
   - Document optional parameters
   - Provide example workflows

### Available Skills

Current skills in the repository:

#### pr-review-and-fix
Comprehensive automated PR review that analyzes CI failures, review comments, and performs code quality review, then helps fix identified issues.

**Invocation**: `@copilot /pr-review-and-fix`

See `skills/pr-review-and-fix/SKILL.md` for full documentation.

## Contributing Guidelines

When contributing to Warden:

- ✅ Maintain cross-platform compatibility
- ✅ Follow the established skill format
- ✅ Include comprehensive documentation
- ✅ Test workflows before submitting
- ✅ Update AGENTS.md with new skills
- ✅ Support multiple programming languages where applicable
- ✅ Include error handling and rollback options
- ✅ Document destructive operations clearly

## GitHub Copilot Specific Features

When implementing skills with GitHub Copilot:
- Use `gh` CLI for GitHub operations
- Leverage GitHub Actions for CI/CD integration
- Use Copilot Chat for complex multi-step workflows
- Test skills in different repository contexts

## Best Practices

- Keep skills focused and modular
- Provide clear, actionable documentation
- Include examples for common use cases
- Handle errors gracefully
- Confirm destructive actions with users
- Support dry-run modes where applicable
