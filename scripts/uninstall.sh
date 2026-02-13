#!/bin/bash
# Warden Skill Uninstaller

set -e

INSTALL_DIR="${1:-$HOME/warden}"

echo "=== Warden Skill Uninstaller ==="
echo ""

if [ ! -d "$INSTALL_DIR" ]; then
  echo "✓ Warden not found at: $INSTALL_DIR"
  echo "  Nothing to uninstall."
  exit 0
fi

echo "WARNING: This will remove Warden from: $INSTALL_DIR"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Removing Warden..."
  rm -rf "$INSTALL_DIR"
  echo ""
  echo "=== Uninstall Complete ==="
  echo ""
  echo "Warden has been removed from: $INSTALL_DIR"
  echo ""
  echo "To reinstall: curl -fsSL https://raw.githubusercontent.com/abishop1990/warden/main/install.sh | bash"
else
  echo "Uninstall cancelled."
fi
