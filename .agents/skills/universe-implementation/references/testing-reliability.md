# Role 5 — Testing & Independent Reliability

## Scope

- Targeted verification of active phase deliverables without repeating unrelated historical test runs.
- Phase 2a contract tests: `engine/tests/test_distribution_contract.py`, `supabase/tests/course_distribution_contract.test.sql`, and `supabase/tests/course_distribution_authorization.test.sql`.
- Phase 4 mandatory scheduling fixture classes (Master Plan §12.2: feasible baseline, infeasible collision, time-limit incumbent, `B+C` joint/split teachers, external faculty collision, ECL/Physics windows, low-credit theory blocks, break-crossing, batch weekend spread, permanent attendance days, adjunct course bands, 6/7-slot grids, merged-row anomalies).

## Guardrails

- Distinguish clearly between static analysis, unit/widget tests, synthetic local harness checks, and real database/browser execution.
- Do not use or recommend Supabase CLI; when SQL test verification requires database execution not available through the connected Supabase plugin, provide the exact SQL script for **Supabase Dashboard → SQL Editor**.
- Reviewers must not author the code under independent gate review.
