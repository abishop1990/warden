#!/bin/bash
# Warden Skill Installer
# Cross-platform installation helper for AI coding assistants

set -e

WARDEN_VERSION="1.2.0"
INSTALL_DIR="${1:-$HOME/warden}"

echo "=== Warden Skill Installer v${WARDEN_VERSION} ==="
echo ""

# Clone or update Warden
if [ -d "$INSTALL_DIR" ]; then
  echo "✓ Warden already exists at: $INSTALL_DIR"
  echo "  Updating to latest version..."
  cd "$INSTALL_DIR"
  git pull origin main
else
  echo "Installing Warden to: $INSTALL_DIR"
  git clone https://github.com/abishop1990/warden.git "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Warden is now available at: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo ""
echo "1. Add Warden to your AI workspace:"
echo "   - Claude Code: cd $INSTALL_DIR"
echo "   - GitHub Copilot: Add folder to VSCode workspace"
echo "   - Cursor: Add folder to workspace"
echo ""
echo "2. Invoke Warden from your AI assistant:"
echo "   \"Run the Warden skill\""
echo ""
echo "3. Try a dry-run to verify installation:"
echo "   \"Run Warden in dry-run mode\""
echo ""
echo "Documentation:"
echo "  - Quick Start: $INSTALL_DIR/QUICKSTART.md"
echo "  - Full Install Guide: $INSTALL_DIR/INSTALL.md"
echo "  - Parameters: $INSTALL_DIR/docs/PARAMETERS.md"
echo ""
echo "For help: https://github.com/abishop1990/warden/issues"
echo ""
