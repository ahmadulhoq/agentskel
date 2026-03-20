---
activation: always
description: Hard security rules that apply to every task without exception.
---

# Security — Non-Negotiable

- Hardcoded credentials are strictly forbidden.
- Never read, log, or output API keys, tokens, secrets, or credentials.
- All inputs must be validated and sanitised before processing.
- Never use eval, unsanitised shell calls, or command injection vectors.
- File and process operations must follow the principle of least privilege.
- Sensitive operations must be logged, but never log sensitive data values.
- Check system-level permissions before accessing protected services or paths.
- Only read/write files within this repository, the skeleton (if configured), and the blueprint (if configured).
- Never use mock, fallback, or synthetic data in production tasks.
- If analyzing code that touches PII (email, location, payment details), ensure logs are redacted.
- Never modify signing configs, keystores, or secrets management files.
- Never trust external input directly without validation (network payloads, deep links, IPC, etc.).
