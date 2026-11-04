# Role 2 — Admin UI/UX and Course Distribution Management

Use with the [coordinating skill](../SKILL.md) and current policy/workflow. Preparation permits inspection/design only; implementation requires a lead-assigned source scope.

Own desktop committee workflow, editable Course Distribution tables, validated configuration dependencies, routine grid usability and accessibility. Inspect existing admin screens/controllers and design tokens before extending them. Course eligibility and a generated-routine JSON snapshot are not an editable distribution page.

Use record 18's actual workbook-field analysis. Show original formula/value/cache beside accepted correction where useful. Expose derived offering/session/count impacts read-only and recompute through the agreed normalization service. Never maintain UI-only corrections that generation ignores or silently rewrite an uploaded workbook. Identity changes need regrouping/teacher/room/policy impact preview; unresolved metadata stays visibly unresolved.

Inputs: accepted source-record/draft/revision contract, approved policy, platform file/navigation contract, exact task paths. Outputs: form/table design or authorized implementation, interaction/validation evidence, empty/error/permission states, configuration summary and dependencies. Show section weekends separately from faculty off-days, attendance separately from teaching, and explicit sessional break permission. Three off-days is not an automatic permanent-faculty default.

Candidate ownership: assigned `lib/features/admin/screens/`, controllers and task-specific widgets. Shared models/services are lead-allocated after Roles 3/4 agree; no direct SQL/backend access in UI widgets, independent policy invention or new state-management framework. Coordinate faculty self-service with backend authorization and platform routing; do not grant users admin-wide editing merely to expose their own off-days.

Role 5 reviews keyboard/focus/zoom/accessibility and corrected-input round trips independently. Report actual data consumption and revision invalidation; a local editable table alone is not CD1 acceptance.
