# Technical Debt Registry

## Anti-Patterns
| ID | Module | Description | Severity | Found |
|----|--------|-------------|----------|-------|

## Bugs
| ID | Module | Description | Severity | Found |
|----|--------|-------------|----------|-------|

## Missing Tests
| ID | Module | Description | Found |
|----|--------|-------------|-------|

## Structural Issues
| ID | Module | Description | Severity | Found |
|----|--------|-------------|----------|-------|
| SI-001 | roles/dev/skills | setup-skeleton copies generic skill templates but projects need platform-specific customizations (e.g. Android Compose/UDF in senior-developer, MockK/Espresso in test-engineer, Detekt in code-reviewer). No mechanism for platform-aware skill content during setup. Skills should have platform markers like standards do, or setup should prompt for platform-specific additions. | medium | 2026-03-24 |
| SI-002 | roles/dev/standards | No setup-time mechanism for platform-specific standards (e.g. ANDROID_ARCHITECTURE.md). Projects needing standards beyond the generic 5 must create them manually. Consider platform-standards templates or a setup step that generates them. | low | 2026-03-24 |

## Dead Code
| ID | Module | Description | Found |
|----|--------|-------------|-------|

## Spec Drift
| ID | Description | Found |
|----|-------------|-------|
