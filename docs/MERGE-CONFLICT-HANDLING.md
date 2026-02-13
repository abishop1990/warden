# Merge Conflict Handling

Warden detects merge conflicts in PRs and presents resolution options to the user, rather than simply aborting.

## Overview

**What happens when conflicts are detected**:
1. **Phase 3: Validation** - Detect conflicts when checking out PR branch
2. **Phase 4: Planning** - Include conflicts in issue report
3. **Phase 5: User Interaction** - Present resolution options
4. **Phase 6: Execution** - Execute chosen strategy

**Resolution options**:
- **Auto-resolve** - AI attempts to resolve conflicts automatically
- **Interactive** - Agent guides user through each conflict
- **Skip** - Leave conflicts for manual resolution later

## Phase 3: Conflict Detection

When checking out a PR branch, Warden detects merge conflicts:

```bash
# Checkout PR branch
gh pr checkout ${PR_NUMBER}

# Check for conflicts
CONFLICTS=$(git diff --name-only --diff-filter=U)

if [ -n "$CONFLICTS" ]; then
  echo "⚠️  Merge conflicts detected in PR #${PR_NUMBER}"

  # Save conflict details
  echo "$CONFLICTS" > /tmp/warden-pr-${PR_NUMBER}-conflicts.txt

  # Extract conflict markers for analysis
  for file in $CONFLICTS; do
    echo "=== $file ===" >> /tmp/warden-pr-${PR_NUMBER}-conflict-details.txt
    git diff $file >> /tmp/warden-pr-${PR_NUMBER}-conflict-details.txt
  done

  # Flag for Phase 4 reporting
  HAS_CONFLICTS=true
fi
```

**What gets detected**:
- Files with unmerged paths (conflict markers)
- Number of conflicting files
- Conflict locations (<<<<<<< HEAD markers)
- Conflicting changes (ours vs theirs)

## Phase 4: Planning - Conflict Reporting

Conflicts are included in the issue report alongside other findings:

```
=== Warden Analysis Report ===

PR #123: Add user authentication

⚠️  MERGE CONFLICTS DETECTED (3 files):

1. src/auth/login.ts
   - Lines 45-52: Authentication method conflict
   - Ours: OAuth2 implementation
   - Theirs: JWT token implementation

2. src/api/routes.ts
   - Lines 23-28: Route definition conflict
   - Ours: /api/v2/login
   - Theirs: /auth/login

3. package.json
   - Lines 15-18: Dependency version conflict
   - Ours: express@4.18.2
   - Theirs: express@4.19.0

Resolution options:
1. Auto-resolve: AI analyzes conflicts and proposes resolution
2. Interactive: Agent guides you through each conflict
3. Skip: Continue with other fixes, handle conflicts manually later

Issues Found:
[CI failures, review comments, etc.]
```

## Phase 5: User Interaction - Resolution Options

User chooses how to handle conflicts:

### Option 1: Auto-Resolve

**When to use**:
- Simple conflicts (version bumps, formatting differences)
- Non-critical files
- Trust AI to make reasonable decisions

**How it works**:
```bash
User: "Auto-resolve conflicts"

Agent:
1. Analyzes each conflict
2. Determines resolution strategy:
   - Dependency versions: Take newer version
   - Formatting: Apply project style
   - Code logic: Analyze intent, merge both if compatible
3. Applies resolution
4. Validates (build, lint, test)
5. Shows proposed resolution for user approval
```

**Example**:
```
Auto-resolution proposed:

✅ package.json (line 15-18):
   Conflict: express@4.18.2 vs express@4.19.0
   Resolution: Take newer version (4.19.0)
   Reason: Semantic versioning - patch upgrade safe

⚠️  src/auth/login.ts (line 45-52):
   Conflict: OAuth2 vs JWT implementation
   Resolution: Keep both, add config flag
   Reason: Both auth methods valid, make configurable

❌ src/api/routes.ts (line 23-28):
   Conflict: /api/v2/login vs /auth/login
   Resolution: CANNOT AUTO-RESOLVE
   Reason: Breaking API change, needs user decision

Apply auto-resolution? (Will resolve 2/3 conflicts)
1. Yes, apply and continue
2. No, switch to interactive mode
3. Skip all conflicts
```

### Option 2: Interactive Resolution

**When to use**:
- Complex conflicts requiring human judgment
- Critical code paths
- Want to review each decision

**How it works**:
```bash
User: "Interactive resolution"

Agent walks through each conflict:

Conflict 1/3: package.json (lines 15-18)
<<<<<<< HEAD (your changes)
"express": "4.18.2"
=======
"express": "4.19.0"
>>>>>>> main (incoming changes)

Options:
1. Take HEAD (keep 4.18.2)
2. Take main (use 4.19.0) [RECOMMENDED: newer version]
3. Custom (enter your resolution)
4. Skip this file

Your choice: _
```

**Interactive prompts**:
```
For each conflict:
1. Show file and line numbers
2. Show both versions (ours vs theirs)
3. Provide context (what changed, why)
4. Recommend strategy if applicable
5. Accept user input
6. Validate after resolution
7. Move to next conflict
```

### Option 3: Skip

**When to use**:
- Want to handle conflicts manually in your editor
- Conflicts are complex, need more time
- Want to fix other issues first

**How it works**:
```bash
User: "Skip conflicts"

Agent:
1. Marks conflicts as "user will handle"
2. Continues with other fixes (CI, reviews, code quality)
3. Leaves conflict markers in place
4. Reports at end: "3 merge conflicts remain unresolved"
```

**Result**:
```
=== Summary ===

Fixed:
- 2 CI failures
- 4 review comments
- 3 code quality issues

Remaining:
⚠️  3 merge conflicts in:
   - src/auth/login.ts
   - src/api/routes.ts
   - package.json

Next steps:
1. Resolve conflicts manually
2. Run: git add <files>
3. Run: git commit
4. Or: git merge --abort and try Warden interactive mode
```

## Phase 6: Execution - Resolution Strategies

### Auto-Resolve Strategy

**Dependency conflicts**:
```python
def resolve_dependency_conflict(file, ours, theirs):
    if is_version_conflict(ours, theirs):
        # Take newer semantic version
        return max(ours, theirs, key=parse_version)
    elif is_compatible(ours, theirs):
        # Both can coexist
        return merge_both(ours, theirs)
    else:
        # Cannot auto-resolve
        return NEEDS_USER_INPUT
```

**Formatting conflicts**:
```python
def resolve_formatting_conflict(file, ours, theirs):
    # Apply project formatter to both
    ours_formatted = format_code(ours, project_style)
    theirs_formatted = format_code(theirs, project_style)

    if ours_formatted == theirs_formatted:
        # Conflict was just formatting
        return ours_formatted
    else:
        # Real logic difference
        return NEEDS_USER_INPUT
```

**Code logic conflicts**:
```python
def resolve_logic_conflict(file, ours, theirs):
    # Analyze intent
    ours_intent = analyze_intent(ours)
    theirs_intent = analyze_intent(theirs)

    if are_compatible(ours_intent, theirs_intent):
        # Can merge both
        return merge_logic(ours, theirs)
    elif is_superseded(ours, theirs):
        # Theirs replaces ours
        return theirs
    elif is_superseded(theirs, ours):
        # Ours replaces theirs
        return ours
    else:
        # Conflicting intents
        return NEEDS_USER_INPUT
```

### Interactive Strategy

**Conflict resolution loop**:
```bash
#!/bin/bash

CONFLICTS=($(git diff --name-only --diff-filter=U))
TOTAL=${#CONFLICTS[@]}
RESOLVED=0

for i in "${!CONFLICTS[@]}"; do
  FILE="${CONFLICTS[$i]}"
  NUM=$((i + 1))

  echo "Conflict $NUM/$TOTAL: $FILE"
  echo ""

  # Show conflict
  git diff "$FILE"

  echo ""
  echo "Options:"
  echo "1. Take HEAD (your changes)"
  echo "2. Take main (incoming changes)"
  echo "3. Open in editor"
  echo "4. Show more context"
  echo "5. Skip this file"
  echo "6. Abort conflict resolution"
  echo ""

  read -p "Your choice (1-6): " choice

  case $choice in
    1)
      git checkout --ours "$FILE"
      git add "$FILE"
      RESOLVED=$((RESOLVED + 1))
      ;;
    2)
      git checkout --theirs "$FILE"
      git add "$FILE"
      RESOLVED=$((RESOLVED + 1))
      ;;
    3)
      ${EDITOR:-vim} "$FILE"
      git add "$FILE"
      RESOLVED=$((RESOLVED + 1))
      ;;
    4)
      git log --oneline --graph --all -- "$FILE" | head -20
      # Repeat current conflict
      i=$((i - 1))
      ;;
    5)
      echo "Skipped $FILE"
      ;;
    6)
      echo "Aborting conflict resolution"
      exit 1
      ;;
  esac

  echo ""
done

echo "Resolved $RESOLVED/$TOTAL conflicts"
```

## Validation After Resolution

**MANDATORY**: After resolving conflicts, validate changes:

```bash
# 1. Verify no conflict markers remain
if grep -r "<<<<<<< HEAD\|=======\|>>>>>>>" .; then
  echo "❌ ERROR: Conflict markers still present"
  exit 1
fi

# 2. Run full validation
source .warden-validation-commands.sh
$BUILD_CMD  || { echo "❌ Build failed after conflict resolution"; exit 1; }
$LINT_CMD   || { echo "❌ Lint failed after conflict resolution"; exit 1; }
$TEST_CMD   || { echo "❌ Tests failed after conflict resolution"; exit 1; }

echo "✅ Conflict resolution validated successfully"
```

## Safety Features

### Rollback After Failed Resolution

If auto-resolution breaks things:

```bash
# Before resolution
git stash push -m "warden-pre-conflict-resolution"

# Attempt resolution
resolve_conflicts()

# Validate
if ! validate_changes; then
  echo "❌ Resolution broke something, rolling back"
  git stash pop
  exit 1
fi
```

### User Review Before Commit

Even after auto-resolution, show user what was changed:

```bash
echo "Auto-resolution complete. Review changes:"
git diff --cached

echo ""
echo "Changes look good?"
echo "1. Yes, commit and continue"
echo "2. No, let me fix manually"
echo "3. Show me more details"

read -p "Your choice: " choice
```

## Configuration

Add to `~/.warden/config.yml`:

```yaml
merge_conflicts:
  # Default resolution strategy
  default_strategy: interactive  # auto, interactive, skip

  # Auto-resolve settings
  auto_resolve:
    dependencies: true      # Auto-resolve version conflicts
    formatting: true        # Auto-resolve formatting-only conflicts
    simple_logic: false     # Auto-resolve simple logic conflicts (risky)

  # Interactive settings
  interactive:
    show_context: 10        # Lines of context to show
    recommend: true         # Show AI recommendations

  # Skip settings
  skip:
    continue_other_fixes: true  # Fix other issues even with conflicts
```

## Parameters

```bash
# Set default strategy
--conflict-strategy auto|interactive|skip

# Auto-resolve specific types
--auto-resolve-dependencies
--auto-resolve-formatting

# Interactive options
--conflict-context-lines 10

# Skip options
--skip-conflicts  # Same as --conflict-strategy skip
```

## Examples

### Example 1: Auto-resolve simple conflicts

```bash
User: "Run Warden and auto-resolve conflicts"

Warden:
✅ Detected 3 merge conflicts
✅ Auto-resolved 2/3:
   - package.json: Updated express to 4.19.0
   - src/styles.css: Applied project formatting
⚠️  Cannot auto-resolve:
   - src/api/routes.ts: Breaking API change

Continue with interactive resolution for remaining conflict? (y/n)
```

### Example 2: Interactive resolution

```bash
User: "Run Warden with interactive conflict resolution"

Warden:
Conflict 1/3: package.json

<<<<<<< HEAD
"express": "4.18.2"
=======
"express": "4.19.0"
>>>>>>> main

AI Recommendation: Take main (4.19.0)
Reason: Newer version, patch upgrade, likely safe

Your choice:
1. Take HEAD (4.18.2)
2. Take main (4.19.0) [RECOMMENDED]
3. Custom version

Choice: 2

✅ Resolved package.json

Conflict 2/3: src/api/routes.ts
[continues...]
```

### Example 3: Skip and handle manually

```bash
User: "Run Warden but skip conflicts"

Warden:
⚠️  3 merge conflicts detected, skipping as requested
✅ Fixed 2 CI failures
✅ Fixed 4 review comments
✅ Fixed 3 code quality issues

Summary:
- 9 issues fixed
- 3 merge conflicts remain (in src/auth/, src/api/, package.json)

Next: Resolve conflicts manually, then push
```

## Best Practices

**When to auto-resolve**:
- ✅ Dependency version bumps
- ✅ Formatting/whitespace conflicts
- ✅ Simple non-overlapping changes

**When to use interactive**:
- ✅ Complex code logic conflicts
- ✅ API or interface changes
- ✅ Database schema conflicts
- ✅ Want to review each decision

**When to skip**:
- ✅ Many conflicts (>5 files)
- ✅ Complex conflicts needing research
- ✅ Want to use your preferred merge tool
- ✅ Conflicts in critical paths (auth, payments, etc.)

## Error Handling

**If auto-resolution fails validation**:
```
❌ Auto-resolution failed validation

Conflict resolution in src/auth/login.ts broke tests:
- TestLogin: Expected OAuth2, got undefined

Rolling back auto-resolution...
✅ Rolled back

Options:
1. Try interactive resolution
2. Skip conflicts and fix manually
3. Abort Warden execution
```

**If interactive resolution is interrupted**:
```
⚠️  Interactive resolution interrupted

Progress:
- Resolved: 2/5 conflicts
- Remaining: 3 conflicts

Your working tree has uncommitted changes from partial resolution.

Options:
1. Continue resolution (resume where you left off)
2. Commit partial resolution and handle rest manually
3. Abort and reset (lose partial resolution)
```

## See Also

- [WORKFLOW.md](WORKFLOW.md) - Phase 3/4/5 integration
- [SAFETY.md](SAFETY.md) - Rollback mechanisms
- [AGENTS.md](AGENTS.md) - User interaction patterns
