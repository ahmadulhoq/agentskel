# Install modes

agentskel supports three ways to set up, depending on how your projects are organized.

---

## 1. Single project

**Use this when:** You have one codebase in one git repo. This is the default for most people.

```
                ┌──────────────────────┐
                │                      │
                │     Your project     │
                │                      │
                │  (agentskel and      │
                │   memory live here)  │
                │                      │
                └──────────────────────┘
```

**Setup:** In your project, say *"Set up agentskel on this project."*

---

## 2. Workspace with multiple projects inside

**Use this when:** You have a parent folder that contains several separate projects — each with its own git repo. For example, a folder holding a backend and a mobile app. You want to work from the top-level folder without switching between them.

```
        ┌────────────────────────────────────────────┐
        │             Your workspace                 │
        │                                            │
        │         (agentskel lives here)             │
        │                                            │
        │        directs tasks to the right          │
        │             project below                  │
        └────────┬─────────────────────┬─────────────┘
                 │                     │
                 ▼                     ▼
        ┌────────────────┐    ┌────────────────┐
        │    Backend     │    │   Mobile app   │
        │   (own repo,   │    │   (own repo,   │
        │   own memory)  │    │   own memory)  │
        └────────────────┘    └────────────────┘

   Ask "fix the backend bug" → the agent works in the backend project.
   Ask "update the mobile app" → the agent switches to the mobile project.
   Each project stays independent — its own code, its own git repo.
```

**Setup:**
1. At the top-level folder: *"Set up agentskel as a workspace."*
2. Inside each project folder: *"Set up agentskel here as a workspace platform."*

---

## 3. Multiple projects sharing the same business logic

**Use this when:** Your team has two or more projects (for example, a backend, an iOS app, and an Android app) that all implement the same business rules. You want the agents working on each project to stay in sync automatically.

You create a **blueprint** — a separate repo holding the shared business rules. Each project points to it.

```
     ┌─────────────────┐                         ┌─────────────────┐
     │                 │                         │                 │
     │    Backend      │─────┐             ┌─────│   Mobile app    │
     │                 │     │             │     │                 │
     └─────────────────┘     │             │     └─────────────────┘
                             │             │
                             ▼             ▼
                       ┌────────────────────────┐
                       │                        │
                       │   Shared blueprint     │
                       │                        │
                       │  (business rules,      │
                       │   API contracts,       │
                       │   change notifications)│
                       └────────────────────────┘

   When the backend agent changes an API contract, it writes a note
   in the shared blueprint. The mobile app agent sees that note
   next session and adjusts accordingly.
```

**Setup:**
1. Create the blueprint: *"Create a blueprint here."*
2. In each project: *"Set up agentskel with blueprint at ../my-blueprint"*

---

## Mix and match

You can combine a workspace with a blueprint — the blueprint sits alongside the other projects inside the workspace folder, and each project references it.

```
                ┌────────────────────────────────────┐
                │          Your workspace            │
                └──┬──────────┬──────────┬───────────┘
                   │          │          │
                   ▼          ▼          ▼
              ┌────────┐ ┌────────┐ ┌──────────┐
              │Backend │ │ Mobile │ │Blueprint │
              └───┬────┘ └───┬────┘ └────▲─────┘
                  │          │           │
                  └──────────┴───────────┘
                    All projects reference
                    the shared blueprint
```

---

## Not supported: single git repo with multiple projects

If all your projects live in one git repo (sometimes called a monorepo), that setup isn't supported. agentskel gives each project its own memory — which needs each project to have its own git history.

**What to do instead:** Split your projects into separate git repos under one parent folder, then use option 2 (workspace). Same convenience, cleaner separation.

---

## Changing setup later

| What you want to do | How to do it |
|---|---|
| Add a new project to a workspace | Say: *"Add [folder] as a new project."* |
| Remove a project from a workspace | Say: *"Remove [name] from the workspace."* |
| Start sharing business logic with another project | Create a blueprint, then point both projects at it |
| Convert a single project into a workspace | Move your project into a subfolder, then set up a workspace at the parent |

---

## Joining an existing setup

Once your team's tech lead has set up agentskel, anyone else on the team can start using it by cloning the project and running:

```bash
./scripts/install-agent.sh
```

This works the same whether the project uses a single-project install, a workspace, or a blueprint.
