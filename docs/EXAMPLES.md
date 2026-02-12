# Warden - Usage Examples

Real-world examples for every scenario.

## TL;DR Quick Start

```bash
# Review all your open PRs with default settings
warden

# Preview what would be fixed (no changes)
warden --dry-run

# Security-focused review with full test suite
warden --reviewers security,testing --test-strategy full

# Fast review with affected tests only
warden --review-depth standard --test-strategy affected
```

---

## Basic Usage

### Review Your PRs
```bash
# Review your open PRs with defaults (standard depth, affected tests)
warden

# Review specific author's PRs
warden --author octocat

# Review closed PRs
warden --state closed --limit 5

# Review all PRs (open + closed)
warden --state all
```

### Preview Mode
```bash
# Dry run - preview what would be fixed without making changes
warden --dry-run

# Dry run with verbose output
warden --dry-run --verbose

# Dry run and save report
warden --dry-run --save-report preview-report.md
```

---

## Review Depth Control

### Standard (Default)
```bash
# Quick review with 1 generalist reviewer
warden --review-depth standard

# Same as:
warden --reviewers generalist
```

### Thorough
```bash
# Security + Performance specialists
warden --review-depth thorough

# Same as:
warden --reviewers security,performance
```

### Comprehensive
```bash
# Full coverage: Security + Performance + Architecture
warden --review-depth comprehensive

# Same as:
warden --reviewers security,performance,architecture
```

### Custom Reviewer Combinations
```bash
# Security-focused review only
warden --reviewers security,testing --review-focus security

# Performance-critical code review
warden --reviewers performance,architecture

# Maintainability and testing focus
warden --reviewers maintainability,testing

# Maximum coverage (5 reviewers)
warden --reviewers security,performance,architecture,maintainability,testing
```

---

## Test Strategy Control

### Skip Tests Entirely
```bash
# Documentation PR - no tests needed
warden --test-strategy none

# Config changes - auto-skip tests for certain file types
warden --skip-tests-for .yml,.yaml,.json,.md,.txt
```

### Affected Tests Only (Default)
```bash
# Test only changed packages (fastest)
warden --test-strategy affected

# Test affected packages with custom timeout
warden --test-strategy affected --test-timeout 600
```

### Full Test Suite
```bash
# Run entire test suite (thorough)
warden --test-strategy full

# Full tests with longer timeout
warden --test-strategy full --test-timeout 900
```

### Smart Testing
```bash
# Affected packages + dependencies
warden --test-strategy smart

# Smart testing with pre-validation
warden --test-strategy smart --test-before-fix
```

### Conditional Testing
```bash
# Only test when fixing Critical issues
warden --test-on-severity critical --test-strategy affected

# Only test for Critical + High
warden --test-on-severity critical,high --test-strategy smart

# Custom test command
warden --test-command "npm run test:ci"
```

---

## Fix Strategy Control

### Conservative (Safest)
```bash
# High-confidence fixes only (90%+)
warden --fix-strategy conservative

# Conservative with full test suite
warden --fix-strategy conservative --test-strategy full

# Conservative for production code
warden \
  --fix-strategy conservative \
  --test-strategy full \
  --reviewers security,testing
```

### Balanced (Default)
```bash
# Fix most issues (70%+ confidence)
warden --fix-strategy balanced

# Balanced with affected tests
warden --fix-strategy balanced --test-strategy affected
```

### Aggressive
```bash
# Attempt all fixes including complex refactors
warden --fix-strategy aggressive

# Aggressive with limits
warden --fix-strategy aggressive --max-fixes-per-tier 20

# Aggressive for draft PR (preview first)
warden --fix-strategy aggressive --dry-run
```

### Manual Review Control
```bash
# Preview before committing
warden --auto-commit-on-success false

# Limit fixes per tier
warden --max-fixes-per-tier 10

# Require review before push (see SAFETY.md)
warden --require-review-before-push
```

---

## PR Integration

### Comment on PRs
```bash
# Post findings as PR comment
warden --comment-on-pr

# Update existing comment instead of adding new
warden --comment-on-pr --update-comment

# Use custom comment template
warden --comment-on-pr --comment-template .github/warden-comment.md
```

### Auto-Labeling
```bash
# Add labels based on findings
warden --auto-label

# Custom label prefix
warden --auto-label --label-prefix bot-

# Labels: security, performance, architecture, needs-tests, etc.
```

---

## Performance Tuning

### Parallel Processing
```bash
# Analyze many PRs efficiently
warden --limit 50 --max-parallel-prs 20

# Limit total subagents for resource constraints
warden --max-parallel-agents 15

# Balance speed and resources
warden --limit 10 --max-parallel-prs 5 --max-parallel-agents 10
```

### Workspace Optimization
```bash
# Reuse workspace for speed (same repo)
warden --reuse-workspace

# Keep workspace for debugging
warden --keep-workspace

# Custom workspace location
warden --workspace-dir /custom/workspace
```

### Caching
```bash
# Cache PR data for 1 hour
warden --cache-pr-data 3600

# Cache analysis results
warden --cache-analysis

# Custom cache location
warden --cache-location /tmp/warden-cache
```

---

## Output & Reporting

### Format Control
```bash
# JSON output
warden --output-format json --save-report warden-report.json

# Markdown report
warden --output-format markdown --save-report warden-report.md

# HTML report
warden --output-format html --save-report warden-report.html

# Text to console (default)
warden --output-format text
```

### Verbosity
```bash
# Verbose logging
warden --verbose

# Quiet mode (minimal output)
warden --quiet

# Quiet with report file
warden --quiet --save-report report.md

# Only show high severity and above
warden --severity high
```

### Metrics Tracking
```bash
# Save metrics over time
warden --save-metrics .warden/metrics.json

# Combine with reporting
warden \
  --save-report warden-$(date +%Y%m%d).md \
  --save-metrics .warden/metrics.json
```

---

## File Filtering

### Ignore Patterns
```bash
# Ignore generated code
warden --ignore-paths "vendor/,*.pb.go,*_generated.go"

# Ignore third-party code
warden --ignore-paths "third_party/,external/,deps/"

# Multiple patterns
warden --ignore-paths "vendor/,node_modules/,dist/,build/,*.min.js"
```

### Focus on Specific Paths
```bash
# Only review source code
warden --focus-paths "src/,cmd/"

# Only review specific component
warden --focus-paths "auth/,security/"

# Combine focus and ignore
warden --focus-paths "src/" --ignore-paths "src/generated/"
```

### File Size Limits
```bash
# Skip large files (> 5000 lines)
warden --max-file-size 5000

# Skip generated files automatically
warden --skip-generated

# Disable generated file skipping
warden --skip-generated false
```

---

## Integration Hooks

### Slack Notifications
```bash
# Send summary to Slack
warden --notify-slack https://hooks.slack.com/services/YOUR/WEBHOOK

# Combine with commenting
warden \
  --comment-on-pr \
  --notify-slack $SLACK_WEBHOOK
```

### Jira Integration
```bash
# Update Jira ticket
warden --update-jira PROJ-123

# Update multiple tickets
warden --update-jira PROJ-123,PROJ-124
```

### Webhooks
```bash
# POST summary JSON to webhook
warden --webhook https://api.example.com/pr-review

# Custom integration
warden \
  --webhook https://internal.example.com/warden \
  --output-format json
```

---

## Language-Specific Examples

### Go Projects
```bash
# Go project with gofmt and golangci-lint
warden \
  --language go \
  --formatter "gofmt -s -w" \
  --linter "golangci-lint run" \
  --test-command "go test -v ./..."

# Focus on Go source only
warden --language go --ignore-paths "*.pb.go,*_generated.go,vendor/"
```

### Python Projects
```bash
# Python with black and pytest
warden \
  --language python \
  --formatter "black --line-length 100" \
  --linter "ruff check" \
  --test-command "pytest -v"

# Python with type checking
warden \
  --language python \
  --test-command "pytest && mypy ."
```

### JavaScript/TypeScript Projects
```bash
# Node.js with prettier and eslint
warden \
  --language javascript \
  --formatter "prettier --write" \
  --linter "eslint --fix" \
  --test-command "npm test"

# TypeScript with type checking
warden \
  --language typescript \
  --test-command "npm test && tsc --noEmit"
```

### Rust Projects
```bash
# Rust with cargo fmt and clippy
warden \
  --language rust \
  --formatter "cargo fmt" \
  --linter "cargo clippy -- -D warnings" \
  --test-command "cargo test"
```

---

## Advanced Combinations

### Security Audit for Production
```bash
warden \
  --reviewers security,testing \
  --review-focus security \
  --test-strategy full \
  --fix-strategy conservative \
  --comment-on-pr \
  --auto-label \
  --notify-slack $SLACK_WEBHOOK \
  --save-report security-audit-$(date +%Y%m%d).md
```

### Fast Iteration on Draft PR
```bash
warden \
  --state all \
  --test-strategy affected \
  --test-on-severity critical \
  --max-fixes-per-tier 5 \
  --quiet \
  --save-report draft-fixes.md
```

### Comprehensive Infrastructure Review
```bash
warden \
  --reviewers security,performance,architecture \
  --test-strategy smart \
  --fix-strategy conservative \
  --comment-on-pr \
  --update-comment \
  --auto-label \
  --save-report infrastructure-audit.md \
  --save-metrics .warden/metrics.json \
  --verbose
```

### High-Volume PR Processing
```bash
warden \
  --limit 100 \
  --max-parallel-prs 25 \
  --max-parallel-agents 50 \
  --test-strategy affected \
  --test-on-severity critical,high \
  --fix-strategy balanced \
  --reuse-workspace \
  --cache-pr-data 3600 \
  --quiet \
  --save-report batch-$(date +%Y%m%d-%H%M%S).json \
  --output-format json
```

### Documentation-Only Changes
```bash
warden \
  --test-strategy none \
  --reviewers maintainability \
  --fix-strategy aggressive \
  --ignore-paths "src/,cmd/,lib/" \
  --focus-paths "docs/,README.md,*.md"
```

### Pre-Production Release Audit
```bash
warden \
  --reviewers security,performance,architecture,testing \
  --test-strategy full \
  --fix-strategy conservative \
  --test-timeout 1200 \
  --comment-on-pr \
  --auto-label \
  --notify-slack $SLACK_WEBHOOK \
  --webhook https://api.internal.com/release-gate \
  --save-report release-$(date +%Y%m%d).md \
  --save-metrics .warden/release-metrics.json \
  --verbose
```

### CI/CD Integration
```bash
# GitHub Actions / GitLab CI
warden \
  --dry-run \
  --reviewers security,performance \
  --test-strategy affected \
  --comment-on-pr \
  --update-comment \
  --auto-label \
  --output-format markdown \
  --save-report ci-report.md
```

### Incremental Review (Only New Changes)
```bash
# Review only files changed since last Warden run
warden \
  --incremental-review \
  --test-strategy affected \
  --fix-strategy balanced
```

### Custom Review Rules
```bash
# Use custom review rules file
warden --review-rules .warden-rules.yml

# See docs/PARAMETERS.md for .warden-rules.yml format
```

---

## Scenario-Based Examples

### New Developer Onboarding
```bash
# Safe, educational review with explanations
warden \
  --dry-run \
  --reviewers generalist \
  --verbose \
  --save-report onboarding-feedback.md
```

### Emergency Security Patch
```bash
# Critical security fixes only
warden \
  --reviewers security \
  --review-focus security \
  --test-strategy full \
  --fix-strategy conservative \
  --test-on-severity critical \
  --comment-on-pr \
  --notify-slack $SECURITY_CHANNEL
```

### Performance Optimization Sprint
```bash
# Focus on performance issues
warden \
  --reviewers performance,architecture \
  --review-focus performance \
  --test-strategy smart \
  --fix-strategy balanced \
  --save-metrics .warden/perf-sprint-metrics.json
```

### Code Quality Cleanup
```bash
# Address tech debt and maintainability
warden \
  --reviewers maintainability,architecture \
  --fix-strategy aggressive \
  --test-strategy affected \
  --max-fixes-per-tier 30
```

### Release Candidate Testing
```bash
# Comprehensive pre-release validation
warden \
  --state all \
  --reviewers security,performance,architecture,testing \
  --test-strategy full \
  --fix-strategy conservative \
  --baseline-commit v1.2.0 \
  --save-report release-candidate-$(date +%Y%m%d).md
```

---

## See Also

- [QUICKSTART.md](../QUICKSTART.md) - 5-minute quick start
- [PARAMETERS.md](PARAMETERS.md) - Complete parameter reference
- [WORKFLOW.md](WORKFLOW.md) - Detailed workflow explanation
- [SAFETY.md](SAFETY.md) - Safety features and best practices
