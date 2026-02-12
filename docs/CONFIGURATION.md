# Warden Configuration System

Warden supports multiple configuration methods to customize its behavior across sessions and projects.

## Configuration Hierarchy

Settings are resolved in this order (highest priority first):

1. **CLI Parameters** - `--workspace-root /custom/path`
2. **Project Config** - `.warden/config.yml` in project root
3. **Global Config** - `~/.warden/config.yml` in user home directory
4. **Defaults** - Built-in defaults

## Configuration File Format

Both global and project configs use YAML format:

```yaml
# Workspace Configuration
workspace:
  root: /tmp/warden-repos          # Root directory for temp workspaces
  in_place: false                   # Run in current repo without temp workspace
  keep_on_error: false              # Keep workspace when errors occur
  reuse: false                      # Reuse workspace across PRs from same repo

# Default Parameters
defaults:
  # PR Selection
  author: "@me"
  state: open
  limit: 10

  # Review Configuration
  reviewers: generalist

  # Test Strategy
  test_strategy: affected
  test_timeout: 300
  parallel_tests: true

  # Fix Strategy
  fix_strategy: balanced

  # Safety
  max_files_changed: null           # null = unlimited
  protect_branches:
    - main
    - master
    - production

  # Performance
  max_parallel_prs: 5

  # Output
  output_format: text
  verbose: false

# Platform-Specific Settings
platform:
  claude_code:
    model: sonnet                   # sonnet, opus, haiku

  github_copilot:
    # Platform-specific settings

  cursor:
    # Platform-specific settings
```

## Workspace Modes

Warden supports three workspace modes:

### 1. Isolated Workspaces (Default)
**Best for**: Most use cases, multiple PRs, safety

```yaml
workspace:
  root: /tmp/warden-repos
  in_place: false
```

- Creates temp directories in `/tmp/warden-repos/pr-{number}-{timestamp}/`
- Each PR gets its own isolated directory
- Automatic cleanup after completion
- Never touches your working directory
- **Recommended for production use**

**CLI equivalent**: `--workspace-root /tmp/warden-repos` (default)

### 2. Custom Workspace Root
**Best for**: Custom temp location, specific disk requirements

```yaml
workspace:
  root: /custom/workspace/path
```

- Use custom location for temp workspaces
- Useful for: Large disk space requirements, SSD vs HDD placement, network mounts

**CLI equivalent**: `--workspace-root /custom/path`

### 3. In-Place Mode
**Best for**: Complex repo setup, custom dependencies, local-only testing

```yaml
workspace:
  in_place: true
```

- Runs directly in your current repository
- No temp workspace created
- Slower (sequential only, no parallel PR processing)
- Required for: Complex build setup, local databases, custom tooling not in git
- **⚠️ WARNING**: Modifies your working directory! Ensure clean git state first.

**CLI equivalent**: `--in-place`

## Setup Instructions

### Initial Setup (All Platforms)

1. **Create global config** (optional - for cross-project defaults):
```bash
mkdir -p ~/.warden
cat > ~/.warden/config.yml <<'EOF'
workspace:
  root: /tmp/warden-repos
  keep_on_error: true              # Keep workspace for debugging

defaults:
  test_strategy: affected
  fix_strategy: balanced
  verbose: false
EOF
```

2. **Verify configuration**:
```bash
# Check if config is valid (TODO: Add warden config validate command)
cat ~/.warden/config.yml
```

### Project-Specific Setup

For repos with special requirements:

```bash
cd /path/to/your/project
mkdir -p .warden
cat > .warden/config.yml <<'EOF'
# Project-specific config for MyProject
workspace:
  root: /Volumes/ExternalSSD/warden  # Use fast SSD for this project

defaults:
  test_strategy: full                 # Always run full test suite
  fix_strategy: conservative          # Be careful with fixes
  protect_branches:
    - main
    - develop
    - release/*
EOF
```

### Platform-Specific Setup

#### Claude Code
Config is automatically loaded from `~/.warden/config.yml` and `.warden/config.yml`.

No additional setup needed.

#### GitHub Copilot
Config is automatically loaded from `~/.warden/config.yml` and `.warden/config.yml`.

Ensure Copilot has access to read these files.

#### Cursor
Config is automatically loaded from `~/.warden/config.yml` and `.warden/config.yml`.

Add `.warden/` to workspace folders if not automatically detected.

## Common Configurations

### Configuration 1: Default (Recommended)
**Use case**: Standard development, multiple PRs, good isolation

```yaml
workspace:
  root: /tmp/warden-repos
  in_place: false

defaults:
  test_strategy: affected
  fix_strategy: balanced
```

### Configuration 2: Conservative
**Use case**: Production repos, strict review requirements

```yaml
workspace:
  root: /tmp/warden-repos
  keep_on_error: true

defaults:
  test_strategy: full
  fix_strategy: conservative
  max_files_changed: 10
  protect_branches:
    - main
    - master
    - production
    - release/*
```

### Configuration 3: In-Place for Complex Setup
**Use case**: Repos with local databases, custom tooling, monorepos with complex setup

```yaml
workspace:
  in_place: true                     # Run in current repo

defaults:
  test_strategy: affected            # Still test only affected
  fix_strategy: balanced
```

⚠️ **Before using in-place mode**:
1. Ensure clean git state: `git status`
2. Consider creating backup branch: `git branch warden-backup-$(date +%s)`
3. Be prepared to rollback if needed

### Configuration 4: Fast SSD for Large Repos
**Use case**: Large monorepos, slow default temp drive

```yaml
workspace:
  root: /Volumes/FastSSD/warden-repos

defaults:
  test_strategy: smart               # Affected + dependencies
  max_parallel_prs: 3                # Reduce for large repos
```

## Configuration Validation

Warden validates configuration on load:

- **Invalid paths**: Falls back to default `/tmp/warden-repos`
- **Unknown parameters**: Warns but continues
- **Invalid values**: Uses defaults with warning

Example warnings:
```
⚠️  Config warning: workspace.root '/nonexistent/path' not accessible, using default '/tmp/warden-repos'
⚠️  Config warning: defaults.test_strategy 'invalid' not recognized, using 'affected'
```

## Debugging Configuration

To see active configuration:

```bash
# Show resolved config (TODO: Add warden config show command)
# For now, Warden will log active config when run with --verbose:

"Run Warden with verbose output"  # AI will use --verbose flag
```

Verbose output shows:
```
[Config] Loaded global config: ~/.warden/config.yml
[Config] Loaded project config: .warden/config.yml
[Config] Active workspace root: /tmp/warden-repos
[Config] Active defaults: test_strategy=affected, fix_strategy=balanced
```

## Environment Variables

Some settings can be overridden via environment variables:

```bash
# Workspace configuration
export WARDEN_WORKSPACE_ROOT=/tmp/warden-repos
export WARDEN_IN_PLACE=false

# Common defaults
export WARDEN_TEST_STRATEGY=affected
export WARDEN_FIX_STRATEGY=balanced
export WARDEN_VERBOSE=true
```

Precedence: **CLI > Env Vars > Config Files > Defaults**

## Migration from CLI-Only

If you previously used CLI parameters, migrate to config:

| Old CLI | New Config |
|---------|------------|
| `--workspace-dir /tmp/pr-*` | `workspace.root: /tmp/warden-repos` |
| `--keep-workspace` | `workspace.keep_on_error: true` |
| `--reuse-workspace` | `workspace.reuse: true` |
| `--test-strategy full` | `defaults.test_strategy: full` |

You can still use CLI parameters - they override config settings.

## Security Considerations

**Config file permissions**:
```bash
# Ensure only you can write to config
chmod 600 ~/.warden/config.yml
chmod 600 .warden/config.yml
```

**Workspace isolation**:
- Default `/tmp/warden-repos/` is cleared on system restart
- Custom workspace roots are NOT auto-cleaned
- In-place mode modifies your working directory

**Protect sensitive branches**:
```yaml
defaults:
  protect_branches:
    - main
    - master
    - production
    - release/*
    - hotfix/*
```

## Cleanup Commands

Warden supports cleanup operations through natural language or explicit commands.

### Clean Temporary Workspaces

**Natural language** (works across all AI platforms):
```
"Clean up Warden workspaces"
"Clear Warden data"
"Delete Warden temp directories"
"Remove Warden workspace files"
```

**What gets deleted**:
- All temporary workspaces in `/tmp/warden-repos/` (or custom `workspace.root`)
- Leftover workspaces from interrupted/failed runs
- Total disk space freed will be reported

**What is preserved**:
- Configuration files (`~/.warden/config.yml`, `.warden/config.yml`)
- Project files and your working directory
- Git repositories outside Warden workspaces

### Manual Cleanup

If you prefer direct commands:

```bash
# Clean default workspace root
rm -rf /tmp/warden-repos/

# Clean custom workspace root (check config first)
WORKSPACE_ROOT=$(grep "root:" ~/.warden/config.yml | awk '{print $2}')
rm -rf "$WORKSPACE_ROOT"

# Find and show workspace disk usage before cleaning
du -sh /tmp/warden-repos/
```

### Automatic Cleanup

Warden automatically cleans workspaces:
- After each PR completes successfully
- On system restart (for `/tmp/` location)
- Unless `--keep-workspace` is specified

**Stale workspaces** can accumulate if:
- Warden crashes or is interrupted
- Errors occur and `workspace.keep_on_error: true`
- Manual cleanup needed: Use natural language command above

### Cleanup by Age

Clean only old workspaces (example for >7 days):

```bash
# Find workspaces older than 7 days
find /tmp/warden-repos/ -type d -name "pr-*" -mtime +7 -exec rm -rf {} \;

# Or interactively review first
find /tmp/warden-repos/ -type d -name "pr-*" -mtime +7 -ls
```

### Reset Configuration

To remove all Warden configuration (⚠️ destructive):

```bash
# Remove global config
rm -f ~/.warden/config.yml

# Remove project config
rm -f .warden/config.yml

# Remove workspaces
rm -rf /tmp/warden-repos/
```

**Note**: Only do this if you want to start fresh. Configuration is not regenerated automatically.

## Troubleshooting

### Workspace Not Cleaned Up
If temp workspaces persist after errors:

```bash
# Manual cleanup
rm -rf /tmp/warden-repos/pr-*

# Or enable auto-cleanup on error in config:
workspace:
  keep_on_error: false  # Clean up even on error
```

### Permission Denied on Workspace Root
```bash
# Ensure directory exists and is writable
mkdir -p /tmp/warden-repos
chmod 755 /tmp/warden-repos
```

### In-Place Mode Issues
```bash
# Check git state before running
git status

# If Warden made unwanted changes:
git reset --hard origin/your-branch

# Create backup before in-place runs:
git branch warden-backup-$(date +%s)
```

## See Also

- **Parameter reference**: [PARAMETERS.md](PARAMETERS.md)
- **Workspace management**: [WORKFLOW.md](WORKFLOW.md)
- **Safety features**: [SAFETY.md](SAFETY.md)
