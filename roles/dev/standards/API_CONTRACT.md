# API Contract Standards

> Last updated: 2026-03-24
> Applies to: all projects that consume or expose HTTP APIs

This document defines the contract between API producers and consumers. All endpoints — internal and external — must follow these conventions. The goal is predictability: every endpoint behaves the same way so clients never have to guess.

---

## 1. Versioning

Use **URL-prefix versioning**: `/api/v1/`, `/api/v2/`.

- The version in the URL is the **major version only**. Minor and patch changes are non-breaking and do not require a new version.
- Prefer URL prefix over header-based versioning — it is simpler to debug, cache, and route.
- A new major version is required only when breaking changes cannot be avoided (see §7).
- Old versions must remain functional until the sunset date (see §7).

---

## 2. Request / Response Format

JSON is the standard wire format.

- All requests and responses must set `Content-Type: application/json`.
- Field names: use **camelCase** consistently. Never mix naming conventions within a project.
- Timestamps: ISO 8601 UTC — `2024-01-15T10:30:00Z`. No Unix timestamps, no local time zones.
- Booleans: use `true` / `false`, not `0` / `1` or string equivalents.
- Null fields: **omit them** from the response rather than sending `"field": null`, unless the client needs to distinguish "absent" from "explicitly null".
- IDs: always strings, even if numeric internally. This avoids integer overflow issues on some platforms.

### Success response envelope

```json
{
  "data": { ... },
  "meta": { ... }
}
```

- `data` — the primary payload. Object for single resources, array for collections.
- `meta` — optional. Pagination cursors, total counts, or other metadata.

---

## 3. Error Response Format

All errors must use this envelope:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email address is not valid.",
    "details": [
      { "field": "email", "reason": "Must be a valid email address." }
    ]
  }
}
```

- `code` — machine-readable string constant (e.g. `NOT_FOUND`, `RATE_LIMITED`). Not an HTTP status code.
- `message` — human-readable, safe to display to end users.
- `details` — optional array for field-level validation errors or additional context.

### HTTP status code usage

| Status | When to use |
|--------|-------------|
| 200 | Successful read or update |
| 201 | Resource created |
| 204 | Successful delete (no body) |
| 400 | Malformed request (bad JSON, missing required field) |
| 401 | Unauthenticated — no token or token expired |
| 403 | Authenticated but not authorized for this resource |
| 404 | Resource does not exist |
| 409 | Conflict — resource state prevents the operation |
| 422 | Valid JSON but semantically invalid (business rule violation) |
| 429 | Rate limit exceeded |
| 500 | Server error — never intentionally returned |

Do not invent custom status codes. Use `error.code` for application-specific error types.

---

## 4. Authentication

- Use `Authorization: Bearer <token>` for all authenticated requests.
- **Never** send credentials in query parameters — they appear in logs, browser history, and referrer headers.
- Token refresh: when the server returns `401`, the client should attempt a token refresh and retry the original request **once**. If the refresh also fails, redirect to login.
- Sensitive operations (password change, payment) may require step-up authentication — document these per endpoint.

---

## 5. Rate Limiting

Servers must return rate limit headers on every response:

| Header | Purpose |
|--------|---------|
| `X-RateLimit-Limit` | Maximum requests allowed in the window |
| `X-RateLimit-Remaining` | Requests remaining in the current window |
| `X-RateLimit-Reset` | Unix timestamp when the window resets |

Client behavior on `429`:
- Read the `Retry-After` header (seconds until retry is safe).
- Use exponential backoff if `Retry-After` is absent.
- **Never** retry immediately on `429`.

---

## 6. Pagination

Use **cursor-based pagination** as the default. Offset-based is acceptable for simple, small datasets.

### Cursor-based (preferred)

Request: `?cursor=<opaque_string>&limit=20`

Response:
```json
{
  "data": [ ... ],
  "meta": {
    "next_cursor": "eyJpZCI6MTAwfQ==",
    "has_more": true
  }
}
```

- `cursor` is opaque to the client — never parse or construct it.
- `limit` defaults to 20, maximum 100 (configurable per endpoint).

### Offset-based (simple cases)

Request: `?page=2&per_page=20`

Response:
```json
{
  "data": [ ... ],
  "meta": {
    "page": 2,
    "per_page": 20,
    "total": 150
  }
}
```

---

## 7. Breaking Change Policy

### What is breaking

- Removing or renaming a field from a response
- Changing a field's type (string → number, object → array)
- Removing or renaming an endpoint
- Changing the meaning of an error code
- Making a previously optional request field required

### What is NOT breaking

- Adding a new optional field to a response
- Adding a new endpoint
- Adding a new error code
- Adding a new enum value (with caveat: clients using exhaustive switches must handle unknown values gracefully)

### Deprecation process

1. Add response headers: `Deprecation: true` and `Sunset: 2025-06-01` (ISO 8601 date).
2. Document the deprecation in the API changelog with the sunset date.
3. Minimum notice: **90 days** before removal.
4. After sunset: return `410 Gone` with an error body pointing to the replacement.

---

## Agent Rules

- When implementing API calls, follow the request/response format and error handling defined here.
- When reviewing code that adds or changes API endpoints, verify compliance with this standard.
- When encountering undocumented API behavior, flag it as tech debt for documentation.
- When a breaking change is unavoidable, ensure the deprecation process (§7) is followed before removal.
