# Installing the Warden Skill

This guide shows you how to install and use the Warden skill across different AI coding platforms.

## Quick Install (All Platforms)

**Option 1: One-line installer (Recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/abishop1990/warden/main/scripts/install.sh | bash
```

Or install to a custom location:
```bash
curl -fsSL https://raw.githubusercontent.com/abishop1990/warden/main/scripts/install.sh | bash -s /path/to/install
```

**Option 2: Manual clone**

```bash
git clone https://github.com/abishop1990/warden.git ~/warden
cd ~/warden
```

Then invoke Warden from your AI assistant (see platform-specific instructions below).

## Platform-Specific Installation

### Claude Code

**Method 1: Reference the Warden repository (Recommended)**

1. Clone Warden somewhere accessible:
   ```bash
   git clone https://github.com/abishop1990/warden.git ~/warden
   ```

2. When you want to use Warden, navigate to the directory:
   ```bash
   cd ~/warden
   ```

3. Run Claude Code and say:
   ```
   "Run the Warden skill"
   ```

**Method 2: Copy instructions to your project**

1. Copy `CLAUDE.md` and `AGENTS.md` from Warden to your project root
2. Reference Warden in your project's CLAUDE.md:
   ```markdown
   # Warden Skill

   See AGENTS.md for the Warden PR review and fix skill.
   ```

### GitHub Copilot (VSCode/CLI)

**Method 1: Add Warden to workspace**

1. Clone Warden:
   ```bash
   git clone https://github.com/abishop1990/warden.git
   ```

2. Add the Warden folder to your VSCode workspace:
   - File → Add Folder to Workspace → Select `warden` folder

3. Copilot will automatically read `.github/copilot-instructions.md`

4. In Copilot Chat, say:
   ```
   "Run the Warden skill"
   ```

**Method 2: Reference Warden instructions**

1. Clone Warden somewhere accessible
2. In your project's `.github/copilot-instructions.md`, add:
   ```markdown
   # Warden PR Review Skill

   For PR review and fixes, use the Warden skill.
   Instructions: /path/to/warden/.github/copilot-instructions.md
   ```

### Cursor

**Method 1: Add Warden to workspace**

1. Clone Warden:
   ```bash
   git clone https://github.com/abishop1990/warden.git
   ```

2. Open your project in Cursor and add Warden folder to workspace

3. Cursor will read `.cursorrules` from the Warden directory

4. In Cursor chat, say:
   ```
   "Run the Warden skill"
   ```

**Method 2: Import rules into your project**

1. Copy `.cursorrules` and `AGENTS.md` from Warden to your project root
2. Modify your `.cursorrules` to reference Warden:
   ```
   # Warden PR Review Skill

   See AGENTS.md for PR review workflow.
   ```

### Codex / Other AI Platforms

1. Clone Warden:
   ```bash
   git clone https://github.com/abishop1990/warden.git
   ```

2. Navigate to Warden directory when you want to use it

3. Ensure your AI platform can read `AGENTS.md` (unified instructions)

4. Say:
   ```
   "Run the Warden skill"
   ```

## Verification

After installation, verify Warden is accessible:

**Test command:**
```
"Run Warden in dry-run mode to preview my open PRs"
```

**Expected behavior:**
- AI reads Warden instructions
- Discovers your open PRs
- Analyzes CI failures, review comments, and code quality
- Presents findings WITHOUT making changes
- Asks for approval before any fixes

If the AI doesn't recognize "Warden" or doesn't follow the 6-phase workflow, check:
1. Warden directory is in your workspace/accessible
2. AI can read the platform-specific instruction files
3. You're using the exact trigger phrase: "Run the Warden skill"

## Updating Warden

To update to the latest version:

```bash
cd ~/warden  # or wherever you cloned it
git pull origin main
```

## Skill Manifest

Warden includes a `skill.json` manifest for future skill registry integration. This file declares:
- Skill metadata (name, version, description)
- Platform compatibility
- Trigger phrases
- Capabilities and configuration

## Uninstalling

**Option 1: Uninstall script**

```bash
bash ~/warden/scripts/uninstall.sh
```

Or if installed to custom location:
```bash
bash /path/to/warden/scripts/uninstall.sh /path/to/warden
```

**Option 2: Manual removal**

1. Remove Warden folder from your workspace (Claude Code / Copilot / Cursor)
2. Delete any references to Warden in your project's AI instruction files
3. Remove the installation directory:
   ```bash
   rm -rf ~/warden  # or wherever you installed it
   ```

## Troubleshooting

### "AI doesn't recognize Warden"
- Ensure Warden repo is in your workspace/accessible
- Use exact trigger: "Run the Warden skill"
- Check that AI instruction files are readable

### "AI skips Phase 4 approval"
- Update to latest Warden version (includes Phase 4 fix)
- Explicitly say "preview findings first"

### "Commands not discovered from my repo"
- Ensure your project has `CLAUDE.md` or similar AI instructions
- Check that build/test commands are documented with code blocks

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more help.

## Next Steps

After installation:
1. Read [QUICKSTART.md](QUICKSTART.md) for basic usage
2. Review [PARAMETERS.md](PARAMETERS.md) for configuration options
3. Try a dry-run: `"Run Warden in dry-run mode"`

## Contributing

Found a better way to install Warden on your platform? Please contribute to this guide!

- Open an issue: https://github.com/abishop1990/warden/issues
- Submit a PR with improved installation instructions
