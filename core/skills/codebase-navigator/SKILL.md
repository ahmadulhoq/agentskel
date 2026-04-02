---
name: codebase-navigator
description: When searching for code, tracing a bug, or understanding how modules
  connect. Use before grepping blindly — consult the index first.
---

# Codebase Navigator

**Purpose:** Use the project's indexed knowledge (MAP.md, SYMBOLS.md) to find
code efficiently. The cartographer has already mapped the codebase — use the map.

---

## What the index contains

| File | What it tells you | When to use it |
|---|---|---|
| `MAP.md` | Module registry — every module, its responsibility, key entry points, critical flows | Which module owns this? How do modules connect? What's the end-to-end flow? |
| `SYMBOLS.md` | Every class and named function (public, internal, private) with file paths | Where is this class/function defined? What functions does this class have? |

## How to use them

### Finding where something lives
1. Check `SYMBOLS.md` for the class or function name
2. The file path is right there — go directly to it

### Understanding module ownership
1. Check `MAP.md` for the module that owns the responsibility
2. Read the module's key entry points to orient yourself

### Tracing a flow
1. Check `MAP.md` Critical Business Logic Flows for documented flows
2. Follow the entry points listed there

### Finding callers and implementation details
Grep is the right tool for this — the index tells you *where* things are defined,
not *who calls them*. Once you've located the file via SYMBOLS.md, grep for callers.

## When to skip the index

- You already have the exact file path (e.g. from a TECH_DEBT entry or error stack trace)
- You're searching for a string literal, log message, or error code (not a symbol)
- The index is stale (check the timestamp at the top of each file)

---

**No gate.** This is an advisory skill, not a mandatory procedure.
