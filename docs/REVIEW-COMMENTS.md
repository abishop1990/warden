# CRITICAL: Review Comment Fetching

**Gap #15**: Warden was only fetching review summaries, missing actual review comment threads with detailed feedback.

## The Problem

**What was happening**:
```bash
# ❌ WRONG - Only fetches review summaries
gh pr view 3875 --json reviews

# Returns: { "state": "APPROVED" } or { "state": "CHANGES_REQUESTED" }
# Missing: Actual comment threads with detailed feedback
```

**What was missed**:
```
Review comment thread (NOT in gh pr view --json reviews):
  File: core/storage/tenant.go:123
  Comment: "Tenant cleanup loop uses for err != nil, which will skip
           iteration when the first iter.Next() succeeds (err == nil).
           This prevents deleting created tenants and can leak test
           data across runs."

  This is a CRITICAL bug that causes test data leaks!
```

## The Solution

**MUST fetch BOTH endpoints**:

### 1. Review Summaries (Overall State)
```bash
gh pr view ${PR_NUMBER} --json reviews
```

**Returns**:
- Review state: APPROVED, CHANGES_REQUESTED, COMMENTED
- Reviewer name
- Submission timestamp
- Overall review body (optional top-level comment)

**What it DOESN'T include**: Individual comment threads on specific lines/files

### 2. Review Comment Threads (Detailed Feedback)
```bash
gh api "/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments"
```

**Returns**:
- File path and line number
- Actual comment text with detailed feedback
- Thread replies
- Whether comment is resolved
- In-reply-to relationships

**This is where the critical feedback lives!**

## Phase 2: Review Comment Analysis (MANDATORY)

**Subagent B MUST fetch BOTH**:

```bash
#!/bin/bash
PR_NUMBER=$1
OWNER=$(gh repo view --json owner -q .owner.login)
REPO=$(gh repo view --json name -q .name)

echo "=== Fetching Review Data for PR #${PR_NUMBER} ==="

# 1. MANDATORY: Fetch review summaries
echo "[1/2] Fetching review summaries..."
gh pr view ${PR_NUMBER} --json reviews > reviews-summary.json

# 2. MANDATORY: Fetch review comment threads
echo "[2/2] Fetching review comment threads..."
gh api "/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments" > review-comments.json

# 3. Parse BOTH sources
echo ""
echo "Review Summaries:"
jq -r '.reviews[] | "[\(.state)] \(.author.login): \(.body)"' reviews-summary.json

echo ""
echo "Review Comment Threads:"
jq -r '.[] | "File: \(.path):\(.line)\nComment: \(.body)\n"' review-comments.json

# 4. BLOCKING CHECK: Verify data fetched
SUMMARY_COUNT=$(jq '.reviews | length' reviews-summary.json)
THREAD_COUNT=$(jq 'length' review-comments.json)

echo ""
echo "✅ Fetched ${SUMMARY_COUNT} review summaries"
echo "✅ Fetched ${THREAD_COUNT} review comment threads"

if [ ${SUMMARY_COUNT} -eq 0 ] && [ ${THREAD_COUNT} -eq 0 ]; then
  echo "ℹ️  No reviews or comments found (PR may not be reviewed yet)"
else
  echo "✅ Review data fetch complete"
fi
```

## Data Structure Comparison

### Review Summary (`gh pr view --json reviews`)
```json
{
  "reviews": [
    {
      "author": { "login": "reviewer-name" },
      "state": "CHANGES_REQUESTED",
      "body": "Overall feedback here (optional)",
      "submittedAt": "2024-02-12T10:00:00Z"
    }
  ]
}
```

**Contains**: High-level review state
**Missing**: Specific file/line comments

### Review Comments (`gh api /repos/.../pulls/{pr}/comments`)
```json
[
  {
    "path": "core/storage/tenant.go",
    "line": 123,
    "body": "Tenant cleanup loop uses for err != nil...",
    "user": { "login": "reviewer-name" },
    "created_at": "2024-02-12T10:05:00Z",
    "in_reply_to_id": null
  },
  {
    "path": "core/storage/tenant.go",
    "line": 123,
    "body": "Good catch, will fix!",
    "user": { "login": "pr-author" },
    "in_reply_to_id": 123456
  }
]
```

**Contains**: Specific file/line feedback with thread context
**This is the critical data!**

## Why Both Are Needed

**Review summaries**:
- Tell you if PR has "Changes Requested"
- Give overall review state
- Show who reviewed

**Review comment threads**:
- Tell you WHAT needs to change
- Give specific file/line feedback
- Show unresolved discussions
- **Contain the actual bugs and issues to fix**

**Example**:
```
Summary: "CHANGES_REQUESTED"
  ↓
  What changes? Summary doesn't say!
  ↓
Comment thread: "Line 123: This loop condition is wrong, causes data leaks"
  ↓
  NOW we know what to fix!
```

## Phase 2 Implementation

### Step 1: Fetch Both Sources

```bash
# Get repo info
OWNER=$(gh repo view --json owner -q .owner.login)
REPO=$(gh repo view --json name -q .name)

# Fetch BOTH
gh pr view ${PR_NUMBER} --json reviews > /tmp/reviews-summary.json
gh api "/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments" > /tmp/review-comments.json
```

### Step 2: Parse Both Sources

```bash
# Parse summaries
jq -r '.reviews[] |
  "Review by \(.author.login): \(.state)\n" +
  "Body: \(.body // "No top-level comment")\n"' \
  /tmp/reviews-summary.json

# Parse comment threads
jq -r '.[] |
  "File: \(.path):\(.line)\n" +
  "By: \(.user.login)\n" +
  "Comment: \(.body)\n" +
  "---"' \
  /tmp/review-comments.json
```

### Step 3: Identify Actionable Items

**From comment threads**, extract:
- **First**: Filter out resolved threads (`resolved: true` in API response)
- Keywords: "should", "must", "need to", "please", "concern", "issue", "bug", "leak"
- Unresolved threads (no resolution comment)
- Blocking issues (author hasn't responded)

**Resolved thread handling**:
```bash
# Skip resolved threads - they're already addressed
ACTIONABLE=$(jq -r 'map(select(.resolved != true))' /tmp/review-comments.json)
```

### Step 4: Report Findings

```
Review Analysis for PR #3875:

Review Summaries:
  - reviewer1: CHANGES_REQUESTED
  - reviewer2: APPROVED

Review Comment Threads (2 critical):
  1. [CRITICAL] core/storage/tenant.go:123
     "Tenant cleanup loop uses for err != nil, which will skip iteration
      when the first iter.Next() succeeds (err == nil). This prevents
      deleting created tenants and can leak test data across runs."
     Status: UNRESOLVED
     Severity: CRITICAL (data leak)

  2. [HIGH] api/auth.go:45
     "Missing rate limiting on login endpoint"
     Status: UNRESOLVED
     Severity: HIGH (security)

Recommendation: Fix both critical issues before merge
```

## Enforcement Rules

### Rule 1: MUST fetch BOTH endpoints
```bash
# BLOCKING CHECK
if [ ! -f /tmp/reviews-summary.json ]; then
  echo "❌ FATAL: Review summaries not fetched"
  exit 1
fi

if [ ! -f /tmp/review-comments.json ]; then
  echo "❌ FATAL: Review comment threads not fetched"
  exit 1
fi
```

### Rule 2: MUST parse comment threads for specific feedback
```bash
# Don't just check if reviews exist - extract actual comments
ACTIONABLE=$(jq -r '.[] | select(.body | test("should|must|need|concern|issue|bug|leak"; "i")) | .body' /tmp/review-comments.json)

if [ -n "$ACTIONABLE" ]; then
  echo "✅ Found actionable review comments"
else
  echo "ℹ️  No actionable review comments found"
fi
```

### Rule 3: MUST report unresolved threads
```bash
# Thread is unresolved if it has no replies from PR author
AUTHOR=$(gh pr view ${PR_NUMBER} --json author -q .author.login)
UNRESOLVED=$(jq --arg author "$AUTHOR" -r '
  group_by(.path, .line) |
  map(select(
    (.[0].user.login != $author) and
    (map(.user.login) | index($author) == null)
  )) |
  .[]' /tmp/review-comments.json)
```

### Rule 4: MUST ignore resolved threads
```bash
# If a review comment thread is marked as resolved, safely ignore all replies in that thread
# GitHub API returns "resolved" field for review comments (v3 API)

# Filter out resolved threads
ACTIONABLE=$(jq -r '
  group_by(.path, .line) |
  map(select(
    # Skip if thread is marked resolved
    (.[0].resolved // false) == false
  )) |
  .[]' /tmp/review-comments.json)
```

**Why this matters**:
- Resolved threads indicate the issue was addressed and verified
- Processing resolved threads wastes analysis time
- May surface already-fixed issues in the report

**Example**:
```
Thread on file.go:123 (RESOLVED):
  - Reviewer: "This loop causes data leaks"
  - Author: "Fixed in commit abc123"
  - Reviewer: "✅ Verified, looks good"

→ SKIP this thread (already resolved)
```

## Common Mistakes

### Mistake 1: Only checking review summaries
```bash
# ❌ WRONG
gh pr view ${PR_NUMBER} --json reviews

# This only tells you "CHANGES_REQUESTED"
# Doesn't tell you WHAT to change!
```

### Mistake 2: Only checking PR body comments
```bash
# ❌ INCOMPLETE
gh pr view ${PR_NUMBER} --json comments

# This gets general PR discussion
# NOT file-specific review comments!
```

### Mistake 3: Assuming "APPROVED" means no feedback
```bash
# ❌ DANGEROUS
if [ "$REVIEW_STATE" = "APPROVED" ]; then
  echo "No issues found"
fi

# Reviewer may have APPROVED but left comments like:
# "Approving but please fix the data leak before merge"
```

### Correct Approach
```bash
# ✅ CORRECT
# 1. Fetch both summaries and threads
gh pr view ${PR_NUMBER} --json reviews > summaries.json
gh api "/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments" > threads.json

# 2. Parse both for actionable items
# 3. Report ALL findings regardless of approval state
```

## Real Example: PR #3875

**What was fetched** (before fix):
```json
{
  "reviews": [
    {
      "state": "CHANGES_REQUESTED",
      "author": { "login": "reviewer" }
    }
  ]
}
```

**What was MISSED** (the actual bug):
```json
[
  {
    "path": "core/storage/tenant.go",
    "line": 123,
    "body": "Tenant cleanup loop uses for err != nil, which will skip iteration when the first iter.Next() succeeds (err == nil). This prevents deleting created tenants and can leak test data across runs."
  }
]
```

**Impact**: Critical data leak bug was not reported to Phase 4!

## Platform-Specific Notes

### Claude Code
- Use Bash tool to fetch both endpoints
- Save to temp files for parsing
- Pass both to Subagent B

### GitHub Copilot
- Main agent must fetch both (subagents can't use gh CLI)
- Save to `/tmp/warden-pr-${PR}-reviews.json` and `/tmp/warden-pr-${PR}-comments.json`
- Pass file paths to subagent

### Cursor
- Fetch both via Composer
- Parse inline or save to workspace

## Testing the Fix

```bash
# Test script to verify both endpoints are fetched
PR_NUMBER=3875
OWNER=your-org
REPO=your-repo

echo "Testing review comment fetching..."

# Fetch both
gh pr view ${PR_NUMBER} --json reviews > /tmp/test-summaries.json
gh api "/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments" > /tmp/test-comments.json

# Verify
echo "Summaries: $(jq '.reviews | length' /tmp/test-summaries.json)"
echo "Comment threads: $(jq 'length' /tmp/test-comments.json)"

# Show sample comment
echo ""
echo "Sample comment thread:"
jq -r '.[0] | "File: \(.path):\(.line)\nComment: \(.body)"' /tmp/test-comments.json
```

## See Also

- [WORKFLOW.md](WORKFLOW.md) - Phase 2 analysis details
- [AGENTS.md](AGENTS.md) - Subagent B requirements
- GitHub API docs: https://docs.github.com/en/rest/pulls/comments
