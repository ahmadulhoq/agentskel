# Atlassian MCP setup

agentskel's Jira and Confluence integration uses **MCP (Model Context Protocol)**.
You connect an Atlassian MCP server to your AI tool once, then agentskel's workflows
use it. agentskel doesn't include a Jira client — you pick which MCP server fits
your Atlassian deployment.

---

## Which MCP server?

| Server | Good for | Tool name style |
|---|---|---|
| **Atlassian Rovo (official)** | Cloud Jira + Confluence. OAuth. Zero self-hosting. | `getJiraIssue`, `createConfluencePage` |
| **sooperset/mcp-atlassian** (community) | Data Center / Server. Or Cloud with self-hosted control. API tokens. | `jira_get_issue`, `confluence_create_page` |

agentskel workflows reference actions abstractly. The agent uses whichever tool
names are available.

---

## Connecting per tool

### Claude Code

**Rovo Cloud (recommended):**
```bash
claude mcp add -s user atlassian https://mcp.atlassian.com/v1/mcp
```
OAuth flow opens in your browser. One-time.

**sooperset self-hosted:**
Create `.mcp.json` in your repo or `~/.claude/mcp.json`:
```json
{
  "mcpServers": {
    "atlassian": {
      "command": "uvx",
      "args": ["mcp-atlassian"],
      "env": {
        "JIRA_URL": "https://your-jira.example.com",
        "JIRA_PERSONAL_TOKEN": "...",
        "CONFLUENCE_URL": "https://your-confluence.example.com",
        "CONFLUENCE_PERSONAL_TOKEN": "..."
      }
    }
  }
}
```

### Cursor

Settings → MCP → Add new global MCP server. Point to either Rovo endpoint or sooperset.

### Windsurf

Cascade supports MCP via config. See [Windsurf MCP docs](https://docs.windsurf.com/windsurf/cascade/mcp).

### GitHub Copilot (VS Code, agent mode)

Agent mode supports MCP. Add Rovo or sooperset via Copilot settings.

### Codex CLI

Edit `~/.codex/config.toml`:
```toml
[mcp_servers.atlassian]
command = "npx"
args = ["mcp-remote", "https://mcp.atlassian.com/v1/mcp"]
```
Or for sooperset:
```toml
[mcp_servers.atlassian]
command = "uvx"
args = ["mcp-atlassian"]
env = { JIRA_URL = "...", JIRA_PERSONAL_TOKEN = "..." }
```

### Gemini CLI

Atlassian ships an official Rovo extension:
```bash
gemini extensions install @atlassian/rovo
```

---

## Verify the connection

In your AI tool, ask: *"What Atlassian tools do you have access to?"*

You should see a list including issue read/write, Confluence page operations, etc.
If not, the MCP server isn't connected.

---

## Auth notes

- **Rovo Cloud:** OAuth 2.1. Tokens stored by your MCP client. No secrets to manage
  manually.
- **sooperset Cloud:** API token. Generate at
  https://id.atlassian.com/manage-profile/security/api-tokens.
- **sooperset Data Center:** Personal Access Token. Generate in your DC instance
  user profile.
- Never commit tokens to the repo. Use env vars or secret stores.

---

## Rate limits

Atlassian enforces hourly, burst, and per-issue-write limits (stricter since March 2026).
agentskel's `atlassian-integration` skill handles backoff and retry. You shouldn't
hit limits during normal agent use.

If you're doing bulk operations (e.g. migrating many tickets), batch them
deliberately and honor `Retry-After` headers.

---

## What to do after MCP is connected

1. Run `setup-team` to populate the team roster (optional — uses GitHub if available).
2. Run `setup-jira` to introspect your Jira project.
3. Run `setup-confluence` to register your Confluence space.

Each setup workflow is independent. You can configure just Jira, just Confluence,
or both. See `docs/TEAM-COORDINATION.md` for how the layers work together.

---

## Troubleshooting

- **"MCP not connected" error:** Check `/mcp` in Claude Code (or equivalent) to
  confirm the server is listed. If not, re-run the `mcp add` command.
- **OAuth fails in Codex / Gemini:** Rovo's OAuth allowlists some clients. If your
  tool isn't on the allowlist, fall back to sooperset self-hosted.
- **`updateConfluencePage` truncates content:** Known MCP limitation — >5KB gets
  silently cut. The `atlassian-integration` skill works around this by using
  comments or child pages for large content.
- **"Field customfield_XXXX required":** Ticket creation failed because a custom
  field is required. Run `setup-jira` to introspect required fields for your
  project, then retry.
