# Team coordination: memory, Jira, Confluence

agentskel gives your team three knowledge layers. Each has a purpose. Put things
in the right layer and your agent becomes part of how the team works.

---

## The three layers

```
  ┌──────────────────────────────────────────────────────────────┐
  │  Confluence                                                  │
  │  Team-canonical, human-authored, durable                     │
  │  Specs, ADRs, runbooks, post-mortems, release notes          │
  └──────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │  Jira                                                        │
  │  Tracked work with lifecycle                                 │
  │  Features, bugs, tech debt, action items                     │
  └──────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │  .memory/  (shared via git on ai-memory branch)              │
  │  Agent operational state                                     │
  │  MAP, SYMBOLS, RESUME, LESSONS, SACRED, CONVENTIONS, TEAM    │
  └──────────────────────────────────────────────────────────────┘
```

## The rule

- **Operational state the agent uses on every task** → `.memory/`
- **Team-canonical knowledge humans read and maintain** → Confluence
- **Work the team plans, tracks, and ships** → Jira

---

## Knowledge routing decision table

| Knowledge | Destination | Why |
|---|---|---|
| Codebase structure (modules, symbols) | `.memory/MAP.md`, `SYMBOLS.md` | Agent needs every session |
| Coding conventions | `.memory/CONVENTIONS.md` | Agent-enforced style |
| Agent lessons (mistakes to not repeat) | `.memory/LESSONS.md` | Small, agent-facing |
| Sacred behaviors (code that looks wrong) | `.memory/SACRED.md` | Agent guardrails |
| Team roster, roles, ownership | `.memory/TEAM.md` | Agent reads during handoffs |
| Jira workflow conventions | `.memory/JIRA_WORKFLOW.md` | Agent reads before Jira writes |
| Tech debt findings | `.memory/TECH_DEBT.md` + optional Jira ticket | Local + tracked when actionable |
| Architectural decisions (ADRs) | Confluence | Human-authoritative, durable |
| Post-mortems | Confluence | Team-visible, searchable |
| Runbooks | Confluence | Referenced during incidents |
| Feature specifications | Confluence | Human-authored and reviewed |
| Tracked work (features, bugs) | Jira | Lifecycle-tracked |

---

## Cross-layer linking

When knowledge spans layers, link — don't duplicate.

- **ADR published to Confluence** → agentskel's `publish-adr` workflow adds a
  one-line entry to `.memory/LESSONS.md` with the Confluence URL. The agent knows
  the decision exists without loading the full ADR.
- **Tech debt gets a Jira ticket** → TECH_DEBT.md row gets a `Ticket: PROJ-1234`
  column. Local tracking + team tracking stay in sync.
- **PR references a ticket and spec** → PR description cites the Jira ticket and
  the Confluence spec URL. Reviewers get full context.

---

## Common scenarios

### "Implement PROJ-1234"

1. Agent runs `implement-from-ticket` workflow
2. Reads Jira ticket (via Atlassian MCP)
3. Reads linked Confluence specs (via Atlassian MCP)
4. Checks `.memory/SACRED.md` for invariants to respect
5. Plans, branches `PROJ-1234-add-login-retry`, transitions ticket to "In Progress"
6. Implements following `develop-feature` flow
7. Opens PR, comments on ticket with PR URL, transitions to "In Review"
8. On merge: transitions to "Ready for QA", reassigns to QA owner per `.memory/TEAM.md`

### Agent finds tech debt during cartography

1. Cartographer finds duplicated logic across 3 modules
2. Records in `.memory/TECH_DEBT.md`
3. (If `setup-jira` has run) asks: "Create Jira ticket for this? Assignee: tech lead per TEAM.md, label `tech-debt`?"
4. On approval: creates ticket, records ticket key in TECH_DEBT.md row
5. Team sees the debt in their Jira backlog; agent remembers it locally

### Architectural decision during a feature

1. User is implementing a feature and makes a significant architectural choice (e.g. "use X pattern for state")
2. Before continuing, agent suggests: "Document this as an ADR?"
3. On approval, runs `publish-adr` workflow
4. Agent writes MADR-format page to Confluence under ADRs parent
5. Adds one-line entry to `.memory/LESSONS.md` with the URL
6. Continues with feature implementation

### Post-mortem after a production incident

1. Hotfix workflow resolves the issue
2. Agent suggests: "Write a postmortem?"
3. On approval, runs `publish-postmortem` workflow
4. Agent gathers timeline, root cause, action items from user
5. Publishes to Confluence
6. Creates Jira tickets for each action item (if user approves)
7. Adds entry to `.memory/LESSONS.md`

---

## What goes WHERE: quick reference

**Don't put in `.memory/`:**
- Long-form documentation humans read (→ Confluence)
- Work items the team schedules (→ Jira)

**Don't put in Confluence:**
- Agent operational state that changes per task (→ `.memory/`)
- Individual commits, PRs, session history (→ git / ai-memory branch)

**Don't put in Jira:**
- Documentation (→ Confluence)
- Agent lessons about its own past mistakes (→ `.memory/LESSONS.md`)
- Things the team doesn't plan to action (e.g. minor local tech debt — keep in
  TECH_DEBT.md only)

---

## Setup order

1. `setup-skeleton` — creates `.memory/` layer (always)
2. `setup-team` — populates `.memory/TEAM.md` (enables handoffs)
3. `setup-jira` — enables ticket lifecycle workflows
4. `setup-confluence` — enables publishing workflows

Each step is independent. A team can stop at step 2 if they don't use Atlassian.
A team on Linear instead of Jira just doesn't run setup-jira — the other workflows
still work.

---

## Per-developer vs per-team

- `.memory/` is **per-team** (shared via ai-memory branch)
- Atlassian MCP connection is **per-developer** (each dev connects their own, authenticated with their credentials)
- `.memory/TEAM.md`, `.memory/JIRA_WORKFLOW.md` are shared team knowledge, committed to ai-memory, everyone's agent sees the same config

New developer joining a team already using agentskel:
1. Clones the repo
2. Runs `./scripts/install-agent.sh` → gets shared `.memory/`
3. Connects their own Atlassian MCP (per `docs/ATLASSIAN-SETUP.md`)
4. Agent immediately knows the team roster, Jira workflow, Confluence structure
