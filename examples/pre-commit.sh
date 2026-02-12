#!/bin/bash
# Warden pre-commit hook
# Install: cp examples/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

echo "Running Warden pre-commit check..."

# Run Warden on staged changes (dry-run only)
warden \
  --incremental-review \
  --dry-run \
  --quiet \
  --severity high \
  --output-format text

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "❌ Warden found issues. Review and fix before committing."
  echo "   Or run: git commit --no-verify  (to skip this hook)"
  exit 1
fi

echo "✓ Warden check passed"
exit 0
