# Ticket Integration

Warden can analyze PRs against their associated tickets (JIRA, Aha, Linear, etc.) to detect scope divergence and ensure PRs match their requirements.

## Overview

**What it does**:
1. Extracts ticket IDs from PR title/body (e.g., `PROJ-123`, `AHA-456`)
2. Fetches ticket details via MCP server or API
3. Compares PR changes to ticket requirements
4. Reports divergence in Phase 4 (Planning) recommendations

**When to use**:
- Ensure PRs match their ticket requirements
- Detect scope creep or unrelated changes
- Flag PRs that implement different functionality than described
- Verify acceptance criteria coverage

## Configuration

### Global Config (`~/.warden/config.yml`)

```yaml
# Ticket Integration
ticket_integration:
  enabled: true

  # Ticket system type
  system: jira  # jira, aha, linear, github-issues

  # Connection details
  jira:
    domain: your-company.atlassian.net
    email: your-email@company.com
    api_token: ${JIRA_API_TOKEN}  # Or set via environment variable

  aha:
    domain: your-company.aha.io
    api_key: ${AHA_API_KEY}

  linear:
    api_key: ${LINEAR_API_KEY}

  github_issues:
    token: ${GITHUB_TOKEN}  # Uses gh CLI token if not specified

  # Ticket ID patterns (regex)
  patterns:
    - '[A-Z]+-[0-9]+'        # JIRA: PROJ-123
    - 'AHA-[A-Z]+-[0-9]+'    # Aha: AHA-PROJ-123
    - '[A-Z]{3,}-[0-9]+'     # Linear: TEAM-123
    - '#[0-9]+'              # GitHub Issues: #123

  # Analysis configuration
  analysis:
    check_acceptance_criteria: true
    check_description_match: true
    flag_scope_divergence: true
    severity_threshold: medium  # Report divergence at this severity or higher
```

### Project Config (`.warden/config.yml`)

Override for specific project needs:

```yaml
ticket_integration:
  enabled: true
  system: jira

  jira:
    domain: project-specific.atlassian.net
    # Project-specific patterns
  patterns:
    - 'MYPROJ-[0-9]+'
```

### Environment Variables

```bash
# Preferred: Set via environment variables
export JIRA_API_TOKEN="your-token-here"
export AHA_API_KEY="your-key-here"
export LINEAR_API_KEY="your-key-here"
export GITHUB_TOKEN="ghp_..."  # Usually set by gh CLI
```

## Ticket ID Extraction

Warden extracts ticket IDs from:

1. **PR title**: `[PROJ-123] Add user authentication`
2. **PR body**:
   ```
   Fixes PROJ-123

   Implements requirements from AHA-CORE-456
   Related to #789
   ```
3. **Branch name**: `feature/PROJ-123-user-auth`

**Extraction patterns**:
- JIRA: `PROJ-123`, `TEAM-456`
- Aha: `AHA-PROJ-123`
- Linear: `TEAM-123`, `ENG-456`
- GitHub Issues: `#123`, `owner/repo#456`

**Multiple tickets**: If PR references multiple tickets, analyzes all and reports combined alignment.

## MCP Server Support

Warden prefers MCP servers when available (faster, built-in auth):

### JIRA MCP Server

```yaml
ticket_integration:
  system: jira
  use_mcp: true  # Use MCP if available
  mcp_server: jira  # MCP server name
```

If MCP server available, Warden uses it automatically. Falls back to REST API if not.

### Custom MCP Servers

```yaml
ticket_integration:
  system: custom
  use_mcp: true
  mcp_server: my-ticket-system
  mcp_tool: fetch_ticket  # Tool name in MCP server
```

## Analysis Phase (Phase 2)

When ticket integration enabled, Phase 2 launches additional subagent:

**Subagent D - Ticket Alignment**:
1. Extract ticket IDs from PR
2. Fetch ticket details (title, description, acceptance criteria, status)
3. Analyze PR changes (files modified, functions added/changed)
4. Compare against ticket requirements
5. Report alignment or divergence

**What it checks**:
- **Scope match**: Are PR changes related to ticket description?
- **Acceptance criteria**: Are acceptance criteria being addressed?
- **Extra changes**: Are there unrelated changes not in ticket?
- **Missing requirements**: Are ticket requirements not implemented in PR?

**Example analysis**:
```
Ticket: PROJ-123 - Add user login
Description: Implement login page with email/password authentication
Acceptance Criteria:
  ✓ Login form with email and password fields
  ✓ "Remember me" checkbox
  ✗ Password reset link (NOT in PR)
  ✓ Error messages for invalid credentials

PR Changes:
  ✓ src/components/LoginForm.tsx (matches requirement)
  ✓ src/api/auth.ts (matches requirement)
  ⚠️ src/components/UserProfile.tsx (NOT in ticket - scope divergence)
  ⚠️ src/utils/analytics.ts (NOT in ticket - scope divergence)
```

## Phase 4 Reporting (Planning)

Ticket alignment findings included in Phase 4 report:

```
=== Warden Analysis Report ===

PR #123: Add user authentication

Ticket Alignment (PROJ-123):
├─ ✅ Core requirements implemented (login form, auth API)
├─ ⚠️ Missing: Password reset link (acceptance criteria)
├─ 🚨 Scope divergence: UserProfile changes (not in ticket)
└─ 🚨 Scope divergence: Analytics integration (not in ticket)

Recommendation:
- Consider splitting PR: Core auth (matches ticket) + Profile/Analytics (new tickets)
- OR: Update PROJ-123 to include profile and analytics requirements

Issues Found:
[... rest of report ...]
```

**Severity levels**:
- **✅ Aligned**: PR matches ticket requirements
- **⚠️ Minor divergence**: Missing acceptance criteria, minor scope differences
- **🚨 Major divergence**: Significant unrelated changes, ticket requirements ignored

## CLI Parameters

```bash
# Enable ticket integration (if disabled in config)
--ticket-integration

# Override ticket system
--ticket-system jira

# Specify ticket ID explicitly
--ticket-id PROJ-123

# Disable ticket integration (if enabled in config)
--no-ticket-integration

# Set divergence threshold
--ticket-divergence-threshold high  # Only report major divergence
```

**Natural language**:
```
"Run Warden and check ticket alignment"
"Execute Warden with JIRA integration for PROJ-123"
"Review PR against ticket requirements"
```

## Setup Instructions

### JIRA Setup

1. **Create API token**:
   - Go to: https://id.atlassian.com/manage-profile/security/api-tokens
   - Create API token
   - Save to environment: `export JIRA_API_TOKEN="your-token"`

2. **Configure Warden**:
   ```yaml
   ticket_integration:
     enabled: true
     system: jira
     jira:
       domain: your-company.atlassian.net
       email: your-email@company.com
       api_token: ${JIRA_API_TOKEN}
   ```

3. **Test**:
   ```bash
   # Verify connection
   curl -u your-email@company.com:$JIRA_API_TOKEN \
     https://your-company.atlassian.net/rest/api/3/myself
   ```

### Aha Setup

1. **Get API key**:
   - Aha Settings → Personal → API
   - Copy API key
   - Save: `export AHA_API_KEY="your-key"`

2. **Configure Warden**:
   ```yaml
   ticket_integration:
     enabled: true
     system: aha
     aha:
       domain: your-company.aha.io
       api_key: ${AHA_API_KEY}
   ```

### Linear Setup

1. **Get API key**:
   - Linear Settings → API → Personal API keys
   - Create key with read access
   - Save: `export LINEAR_API_KEY="your-key"`

2. **Configure Warden**:
   ```yaml
   ticket_integration:
     enabled: true
     system: linear
     linear:
       api_key: ${LINEAR_API_KEY}
   ```

### GitHub Issues Setup

Uses existing `gh` CLI authentication (no additional setup needed).

```yaml
ticket_integration:
  enabled: true
  system: github-issues
```

## Implementation Details

### REST API Calls

**JIRA**:
```bash
# Fetch issue
curl -u email:token \
  "https://${DOMAIN}/rest/api/3/issue/${ISSUE_KEY}"
```

**Aha**:
```bash
# Fetch feature
curl -H "Authorization: Bearer ${API_KEY}" \
  "https://${DOMAIN}/api/v1/features/${FEATURE_ID}"
```

**Linear**:
```bash
# GraphQL query
curl -H "Authorization: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { issue(id: \"${ISSUE_ID}\") { title description } }"}' \
  https://api.linear.app/graphql
```

**GitHub Issues**:
```bash
# Via gh CLI
gh issue view ${ISSUE_NUMBER} --json title,body,labels
```

### MCP Server Integration

If MCP server available:

```python
# Pseudo-code for MCP integration
mcp_server = get_mcp_server("jira")
ticket_data = mcp_server.call_tool("fetch_issue", {
    "issue_key": "PROJ-123"
})
```

## Error Handling

**Ticket not found**:
```
⚠️ Ticket PROJ-123 not found in JIRA
   Skipping ticket alignment analysis
```

**API authentication failed**:
```
❌ JIRA authentication failed
   Check JIRA_API_TOKEN and credentials in config
   Skipping ticket alignment analysis
```

**No ticket ID in PR**:
```
ℹ️ No ticket ID found in PR title/body/branch
  Skipping ticket alignment analysis
  Hint: Add ticket ID to PR title: [PROJ-123] Your PR title
```

**Multiple tickets**:
```
✅ Found 2 tickets: PROJ-123, PROJ-456
   Analyzing alignment for both tickets
```

## Divergence Examples

### Example 1: Scope Creep

**Ticket**: PROJ-123 - Add login button to homepage

**PR Changes**:
- ✅ `HomePage.tsx` - Added login button (matches)
- ⚠️ `Navigation.tsx` - Refactored entire navigation (NOT in ticket)
- ⚠️ `Footer.tsx` - Updated footer links (NOT in ticket)

**Report**:
```
🚨 Major scope divergence detected

Ticket: Add login button (simple change)
PR: Login button + navigation refactor + footer updates

Recommendation: Split into 3 PRs:
1. PROJ-123: Login button only
2. New ticket: Navigation refactor
3. New ticket: Footer updates
```

### Example 2: Missing Requirements

**Ticket**: PROJ-456 - User profile page with avatar upload

**PR Changes**:
- ✅ `ProfilePage.tsx` - Created profile page
- ✅ `UserInfo.tsx` - Display user info
- ❌ Avatar upload not implemented

**Report**:
```
⚠️ Incomplete implementation

Ticket acceptance criteria:
✓ Profile page with user info
✓ Edit profile button
✗ Avatar upload functionality (MISSING)

Recommendation: Complete avatar upload or update ticket to defer it
```

### Example 3: Perfect Alignment

**Ticket**: PROJ-789 - Add dark mode toggle

**PR Changes**:
- ✅ `ThemeToggle.tsx` - Toggle component
- ✅ `theme.css` - Dark mode styles
- ✅ `localStorage` integration for persistence

**Report**:
```
✅ Excellent alignment

PR fully implements ticket requirements with no scope divergence.
All acceptance criteria met.
```

## Best Practices

1. **Always include ticket ID in PR**: Title, body, or branch name
2. **Keep PRs focused**: One ticket per PR when possible
3. **Update ticket if scope changes**: Don't let PR diverge silently
4. **Use ticket integration early**: Run Warden before requesting review
5. **Configure per-project**: Different projects may use different ticket systems

## Troubleshooting

### "No ticket ID found"
- Add ticket ID to PR title: `[PROJ-123] Your title`
- Or PR body: `Fixes PROJ-123`
- Or branch name: `feature/PROJ-123-description`

### "API authentication failed"
- Verify token: `echo $JIRA_API_TOKEN`
- Check email matches JIRA account
- Test API manually with curl

### "Ticket system not configured"
- Add to `~/.warden/config.yml`
- Set environment variables
- Run `"Run Warden with JIRA integration"` to enable

### "MCP server not found"
- Warden falls back to REST API automatically
- MCP is optional, not required

## Future Enhancements

**Planned**:
- Azure DevOps integration
- Asana integration
- Custom field mapping (map custom fields to analysis)
- Ticket status validation (warn if working on closed ticket)
- Comment on ticket when PR created/merged

## See Also

- [CONFIGURATION.md](CONFIGURATION.md) - Configuration system
- [PARAMETERS.md](PARAMETERS.md) - All parameters
- [WORKFLOW.md](WORKFLOW.md) - Analysis phases
