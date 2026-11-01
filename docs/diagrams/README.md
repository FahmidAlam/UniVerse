# UniVerse — System Defense Diagrams (Master Guide)

> **Status:** Fully updated & reconciled with production codebase & live database (October 2026).  
> **Target Audience:** Project defense committee, examiners, and software engineering team.  
> **Source of Truth:** Verified against Supabase PostgreSQL schema (Migrations 001–016), live Supabase Edge Functions (`send-push`, `invite-admin`), live Render FastAPI solver engine (v2.0.0), and Flutter production client.

---

## 1. Directory Overview

This directory contains the complete set of five architectural and design diagrams for the **UniVerse — A Campus Companion** system. Each document provides ready-to-render code (Mermaid, PlantUML, DBML), structured layout blueprints, and corresponding high-resolution rendered diagrams.

| # | File | Diagram Type | Best Rendering Tool | Primary Purpose |
|---|---|---|---|---|
| 1 | [01-er-diagram.md](01-er-diagram.md) | **Entity-Relationship Diagram (ERD)** | dbdiagram.io / Mermaid / draw.io | Database design, 14 active entities, primary/foreign keys, and cardinalities |
| 2 | [02-use-case-diagram.md](02-use-case-diagram.md) | **Use Case Diagram** | PlantUML / Mermaid | System actors (Student, Teacher, Admin, External Systems) and capabilities |
| 3 | [03-dfd-level-0.md](03-dfd-level-0.md) | **Data Flow Diagram — Level 0 (Context)** | draw.io (Gane-Sarson) / Mermaid | Boundary context: inputs, outputs, and external entities |
| 4 | [04-dfd-level-1.md](04-dfd-level-1.md) | **Data Flow Diagram — Level 1** | draw.io (Gane-Sarson) / Mermaid | Sub-processes (1.1–1.10), data stores (D1–D12), and internal data pipelines |
| 5 | [05-activity-diagram.md](05-activity-diagram.md) | **Activity Diagram** | draw.io (UML Activity) / Mermaid | End-to-end user journeys across 3 vertical swimlanes (Student, Teacher, Admin) |

---

## 2. Core Architectural Facts & Production Rules

Every diagram in this suite is strictly grounded in the following verified system facts:

### A. Database Inventory: 14 Active Tables vs. 4 Future/Legacy Tables
The database contains **18 total tables** in PostgreSQL. To ensure precision and avoid defense confusion:
* **Include the 14 Active Tables:**
  1. `profiles` — Central user identity linked 1:1 with `auth.users`
  2. `whitelists` — Authorization gate for **both Teachers and Admins** (stores department, designation, teacher code)
  3. `routines` — Active weekly schedule entries (stores room, slot, course, teacher code, and version link)
  4. `routine_versions` — Atomic version manager (`is_active` partial unique index, swap metadata)
  5. `cancellations` — Class cancellation occurrences (`routine_id` with `ON DELETE SET NULL`)
  6. `notifications` — Broadcast and class alert records
  7. `notification_reads` — Composite PK (`user_id`, `notification_id`) read tracking
  8. `resources` — Academic files and Google Drive links categorized by semester
  9. `device_tokens` — FCM push registration tokens per user device
  10. `timetable_rooms` — Room inventory with lab/gallery flags and capacities
  11. `timetable_faculty` — Teacher directory, departmental affiliations, and weekly off-days
  12. `timetable_settings` — Solver configuration (14 columns including working days, term weeks, blocked periods, online slots, fixed sessions)
  13. `timetable_runs` — Audit history of timetable generation attempts and results
  14. `timetable_course_eligibility` — Faculty course qualification matrix (`acronym`, `course_code`, `is_eligible`)
* **Exclude the 4 Inactive Tables:**
  * `assignments` & `submissions`: Reserved for future student coursework submission.
  * `documents`: Reserved for future AI Assistant RAG vector store.
  * `timetable_courses`: Legacy prototype table superseded by `timetable_course_eligibility`.

### B. Security & Whitelist Gating (Migration 016)
* **Students:** May self-register freely via Google OAuth or Email/Password.
* **Teachers & Admins:** **Must be pre-whitelisted by an admin** in the `whitelists` table. Database trigger `profiles_guard_role` prevents self-assignment of teacher or admin roles; unauthorized users are redirected to `NotWhitelistedScreen`.

### C. Automated Push Notification Pipeline
* In-app alerts and push notifications originate from a unified backend event:
  $$\text{Table INSERT into } \texttt{notifications} \longrightarrow \text{Database Webhook} \longrightarrow \text{Edge Function } \texttt{send-push} \longrightarrow \text{Firebase FCM (HTTP v1)} \longrightarrow \text{User Phones}$$

### D. Multi-Modal Timetable Ingest & Publication
The system provides two distinct publication pipelines managed by the atomic `publish_routine` RPC:
1. **AI / Solver Route:** Admin uploads `.xlsx` distribution $\rightarrow$ Python FastAPI solver (CP-SAT) generates optimal schedule $\rightarrow$ Admin reviews grid $\rightarrow$ Atomic publish.
2. **Direct Workbook Route:** Admin uploads pre-rendered department `.xlsx` workbook $\rightarrow$ Client-side parser extracts day sheets $\rightarrow$ Atomic publish.

### E. Campus Exploration Suite
Every user role has access to the **Campus Exploration** drawer tools:
* **Find Teacher:** Search instructors to view their weekly schedule and identify their real-time classroom location.
* **Room Availability:** Live room occupancy status and full day schedule per room.

---

## 3. Recommended Reading & Presentation Order for Defense

1. **Start with Use Case Diagram (`02-use-case-diagram.md`)** to establish actors, roles, and feature boundaries.
2. **Present Context DFD (`03-dfd-level-0.md`)** to show external system boundaries (Supabase, FastAPI Engine, Firebase FCM).
3. **Present ER Diagram (`01-er-diagram.md`)** to explain data structures, atomic versioning, and relational integrity.
4. **Present Level-1 DFD (`04-dfd-level-1.md`)** to trace data movement between the processes and data stores.
5. **Conclude with Activity Diagram (`05-activity-diagram.md`)** to demonstrate the complete user operational workflows.
