---
name: update-conventions
description: Refreshes .memory/CONVENTIONS.md by cross-checking current best practices for the project's tech stack. Files gaps and deviations as NEEDS_REVIEW. Updates the architecture standard if it is missing or outdated.
---

# Update Conventions Workflow

**Purpose:** Verify that `.memory/CONVENTIONS.md` reflects current industry best practices for this repo's tech stack. File gaps and deviations as NEEDS_REVIEW items for the lead engineer to classify.

**Scope:** Read, research, and update documentation only. Do NOT modify any application code.

**When to run:**
- After a major library upgrade that changes recommended patterns
- When adopting a new architecture pattern or adding a significant new feature area
- When `Last Conventions Check` in `.memory/CONFIG.md` is more than 90 days old
- When explicitly requested by a lead engineer or tech lead

---

## Step 1 — Pre-flight

1. Read `.memory/CONFIG.md` — note the Default Branch and platform.
2. Read `.memory/VERSIONS.md` — note the tech stack and dependency versions.
3. Read `.memory/CONVENTIONS.md` — understand every section before researching.
4. Read `.memory/NEEDS_REVIEW.md` — note any open items to avoid filing duplicates.
5. Read the project's architecture standard (`.agents/standards/ARCHITECTURE.md`).
   If no architecture standard exists: proceed; you will create one in Step 5.

---

## Step 2 — Official source research

**Only official documentation from the framework/library provider is permitted.**
Do not use blog posts, tutorials, opinion articles, or general web search results.

### 2a — Build the source list

From the tech stack recorded in `.memory/VERSIONS.md`, list every framework and library
that has conventions (architecture, patterns, testing, async). Exclude build tools
and version numbers — focus on runtime/design-time libraries.

For each item, look it up in the reference table below. If it is listed, use that URL.
If it is **not** listed, ask the user:

> "What is the official documentation URL for **[library name]**?"

Ask one at a time and wait for the answer before asking the next.
Do not proceed to 2b until every item has an official URL.

### Official source reference table

This table is a starter set. During `setup-skeleton`, the installer should populate it
with entries relevant to the project's stack and remove irrelevant ones. If a library
is not listed here, ask the user for its official documentation URL before proceeding.

#### Android / Kotlin

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| Android (Jetpack, architecture) | https://developer.android.com/topic/architecture |
| Android (Compose) | https://developer.android.com/develop/ui/compose/documentation |
| Android (Hilt) | https://dagger.dev/hilt/ |
| Android (Kotlin Coroutines) | https://kotlinlang.org/docs/coroutines-overview.html |
| Android (Navigation) | https://developer.android.com/guide/navigation |
| Android (Testing) | https://developer.android.com/training/testing |
| Kotlin (language idioms) | https://kotlinlang.org/docs/idioms.html |
| Kotlin Multiplatform (KMM) | https://kotlinlang.org/docs/multiplatform.html |

#### iOS / Swift

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| iOS (Swift Concurrency) | https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/ |
| iOS (SwiftUI) | https://developer.apple.com/documentation/swiftui |
| iOS (UIKit) | https://developer.apple.com/documentation/uikit |
| iOS (Combine) | https://developer.apple.com/documentation/combine |
| iOS (Testing / XCTest) | https://developer.apple.com/documentation/xctest |
| Swift (language) | https://docs.swift.org/swift-book/ |

#### Cross-Platform Mobile

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| Flutter (architecture) | https://docs.flutter.dev/app-architecture |
| Flutter (state management) | https://docs.flutter.dev/data-and-backend/state-mgmt |
| Flutter (testing) | https://docs.flutter.dev/testing/overview |
| Dart (language) | https://dart.dev/effective-dart |
| React Native (architecture) | https://reactnative.dev/docs/getting-started |
| React Native (testing) | https://reactnative.dev/docs/testing-overview |

#### Backend — Node.js / TypeScript

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| Node.js (best practices) | https://nodejs.org/en/learn |
| TypeScript (handbook) | https://www.typescriptlang.org/docs/handbook/ |
| Express | https://expressjs.com/en/guide/routing.html |
| NestJS | https://docs.nestjs.com/ |
| Jest (testing) | https://jestjs.io/docs/getting-started |
| Vitest (testing) | https://vitest.dev/guide/ |

#### Backend — Python

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| Python (style / PEP 8) | https://peps.python.org/pep-0008/ |
| Django | https://docs.djangoproject.com/en/stable/ |
| FastAPI | https://fastapi.tiangolo.com/ |
| Flask | https://flask.palletsprojects.com/ |
| pytest (testing) | https://docs.pytest.org/en/stable/ |
| SQLAlchemy | https://docs.sqlalchemy.org/ |

#### Backend — Go

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| Go (effective Go) | https://go.dev/doc/effective_go |
| Go (code review comments) | https://go.dev/wiki/CodeReviewComments |
| Go (testing) | https://pkg.go.dev/testing |

#### Backend — Java / Spring

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| Spring Boot | https://docs.spring.io/spring-boot/reference/ |
| Spring Security | https://docs.spring.io/spring-security/reference/ |
| JUnit 5 (testing) | https://junit.org/junit5/docs/current/user-guide/ |

#### Frontend — Web

| Framework / Library | Official documentation URL |
|---------------------|---------------------------|
| React | https://react.dev/learn |
| Next.js | https://nextjs.org/docs |
| Vue.js | https://vuejs.org/guide/introduction.html |
| Angular | https://angular.dev/overview |
| Tailwind CSS | https://tailwindcss.com/docs |

### 2b — Fetch and extract

For each URL collected in 2a, use WebFetch to read the official documentation.
Extract findings relevant to:
- Layered architecture and module structure
- Dependency injection
- Async / concurrency patterns
- State management
- Navigation
- Testing (unit, integration, UI)

Record key findings before proceeding to Step 3. Do not rely on memory across steps.

---

## Step 3 — Cross-check CONVENTIONS.md

Compare research findings against `.memory/CONVENTIONS.md` section by section.

**Gap** (best practice not documented in CONVENTIONS.md):
- Clearly applies, no counter-evidence: add it to CONVENTIONS.md directly.
- Uncertain whether intentional or applicable: file as NEEDS_REVIEW.

**Deviation** (CONVENTIONS.md conflicts with current best practice):
- Always file as NEEDS_REVIEW. Do NOT change existing entries without approval —
  the deviation may be intentional (SACRED) or accidental (TECH_DEBT).

**Accurate section:** no action needed.

---

## Step 4 — Update NEEDS_REVIEW.md

For each item from Step 3, write an entry in `.memory/NEEDS_REVIEW.md`:

```
## NR-NNN — [Short Description]
- **Location:** CONVENTIONS.md section [section name]
- **What it looks like:** [current documented state, or "not documented"]
- **Best practice says:** [what research found, with source]
- **Agent's best guess:** SACRED (intentional) or TECH_DEBT (accidental drift)?
- **Counter-evidence:** [any reason this deviation might be intentional]
- **Awaiting classification:** SACRED or TECH_DEBT?
```

---

## Step 5 — Update architecture standard (if needed)

Review the architecture standard used in Step 1 against the research findings.

- **Missing guidance** (important topic not covered): add it.
- **Outdated advice** (recommends a deprecated pattern): update it.
- **No matching standard**: create a platform architecture standard
  using the research as the foundation.

If any skeleton file is modified, apply contribution rules:
VERSION bump + CHANGELOG entry.

---

## Step 6 — Update Last Conventions Check

In `.memory/CONFIG.md`, update `Last Conventions Check` to the current UTC timestamp (YYYY-MM-DDTHH:MMZ).

Commit the CONFIG.md change (and any CONVENTIONS.md changes) to the ai-memory branch:
```bash
cd .memory
git add CONFIG.md CONVENTIONS.md
git commit -m "update-conventions: refresh conventions check [YYYY-MM-DD]"
git push origin ai-memory
cd ..
```

---

## Step 7 — Report

Present to the user:

- CONVENTIONS.md sections verified: [list sections reviewed]
- Additions made to CONVENTIONS.md: [count and brief summary, or "none"]
- NEEDS_REVIEW items filed: [count — list each with one-line description]
- Architecture standard updated: [yes/no — if yes, state new version]
- Last Conventions Check updated: [UTC timestamp]

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
