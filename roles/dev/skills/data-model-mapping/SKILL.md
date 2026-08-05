---
name: data-model-mapping
license: MIT
description: When adding, renaming, or removing a field on a data model that has a mapped counterpart elsewhere — an API/DTO, a database/ORM entity, a serializer, or a cross-platform equivalent model (Android/iOS/Backend). Use whenever a model's fields change, before considering the change complete.
---

# Data Model Mapping Standards

## Step 1 — Locate Every Side of the Mapping First
- [ ] Before editing a model, grep for its name across mapper/serializer files (`*Mapper`, `*Serializer`, `toDto`/`fromDto`, `toEntity`/`fromEntity`, proto/JSON codecs).
- [ ] If a Blueprint is configured (`Blueprint Path` in `.memory/CONFIG.md`), check its parity matrix and domain specs for a cross-platform counterpart of this model.
- [ ] List every mapped side found — the field change must land on all of them, not just the origin model.

## Step 2 — Propagate the Change
- [ ] Add/rename/remove the field on every mapped side identified in Step 1 in the same change, not as a follow-up.
- [ ] Never consider a field change done because "only this model" needed it — a model with a mapping is never edited in isolation.

## Step 3 — Cross-Platform Parity
- [ ] If this model maps to a documented domain entity in the Blueprint, update the parity matrix / domain spec to match.
- [ ] If another platform repo has its own copy of this model and you can't update it directly, write a Knowledge Bus entry flagging the change.

## Step 4 — Trace the Field End-to-End
- [ ] Follow the changed field through the full mapping chain (model → mapper → serialized/DB form) and confirm it isn't silently dropped anywhere along the way.
- [ ] Pay special attention to mappers that build output field-by-field (e.g. manual `Dto(name = x.name, ...)` constructors) — these drop new fields silently unless every constructor call site is updated.

## Step 5 — Defaults and Nullability
- [ ] For a new field, explicitly decide its default/null behavior on every side — don't rely on an implicit language-level fallback that may differ between sides.

## Step 6 — Test the Round Trip
- [ ] Add or update a mapping test that asserts the changed field survives a full round trip (model → mapped form → model) with a non-default value.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I only changed the domain model, the mapper doesn't need touching" | Mappers are usually explicit field-by-field — an unmapped field disappears silently, with no compile error. | Grep for the model name in mapper/serializer files and update every match. |
| "The field has a sensible default, I'll skip the mapper" | A default on one side can diverge from the actual default on another side. | Explicitly wire the default/null behavior into the mapper. |
| "Cross-platform parity isn't my job, I'm only touching this platform" | Silent parity drift breaks other platforms without anyone noticing until a bug report. | Update the parity matrix or flag a Knowledge Bus entry. |
| "Tests already pass, mapping must be fine" | Passing feature tests without a mapping-specific test don't catch a dropped field. | Add a round-trip mapping test for the changed field. |

**Gate:** Do not consider a data model field change complete until every mapped representation found in Step 1 has been updated and verified via Step 4.
