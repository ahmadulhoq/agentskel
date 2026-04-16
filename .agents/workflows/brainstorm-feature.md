---
name: brainstorm-feature
description: When the user wants to think through a feature idea, explore edge cases, or
  produce a technical spec before implementation. Use before develop-feature to prevent
  mid-implementation surprises.
---

# Brainstorm Feature Workflow

**Purpose:** Act as a Socratic thought partner. Surface failure states and edge cases before any code is written. Output is a technical spec ready to hand to `develop-feature`.

## Strict Rules
- **DO NOT write code.** Not even pseudocode or snippets.
- **DO NOT write an implementation plan.** That belongs in `develop-feature`.
- Your only outputs are questions and, after alignment, a spec.

## Phase 1: Orient
1. Read `.memory/RULES.md`, `.memory/MAP.md`, `.memory/SACRED.md`.
2. Restate the feature in one sentence to confirm understanding.
3. Identify what is ambiguous or under-specified.

## Phase 2: Interrogate (2–3 targeted questions only)
4. Ask **2–3 questions** — prioritize by highest risk of mid-implementation reversal.

   | Area | Example question |
   |------|-----------------|
   | Failure states | "What happens if X returns null / times out / returns empty?" |
   | Data shape | "What does the input look like when Y is missing?" |
   | Concurrency | "Is Z expected to handle concurrent calls?" |
   | Scope boundary | "Does this touch auth, payments, or any SACRED behavior?" |

5. **Wait for user answers.** Do not proceed until all questions are answered.

## Phase 3: Produce the Spec
6. Once approved, use `task-planner` to decompose the spec before handing to `develop-feature`.
7. Write a concise technical spec:
   - **Goal:** one sentence
   - **Inputs / Outputs:** types and shapes
   - **Happy path:** step-by-step
   - **Failure modes:** at least 3, with expected handling per mode
   - **Out of scope:** explicit exclusions
   - **SACRED entries affected:** list or "none"
7. Present the spec. Ask: "Should I pass this to `develop-feature`?"

---

**Gate:** Do not write code or an implementation plan at any point during this workflow.
Do not proceed to Phase 3 until the user has answered all Phase 2 questions.
