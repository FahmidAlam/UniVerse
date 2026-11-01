# Diagram 4 — Data Flow Diagram, Level 1

> **What this shows:** The internal decomposition of Process **0 (UniVerse)** into 10 cohesive sub-processes, 12 production data stores, and all internal and external data flows.  
> **Source of Truth:** Reconciled against live database schema (14 active tables), Flutter feature services, Supabase Edge Functions, and FastAPI solver engine.  
> **Tool to render:** [draw.io / diagrams.net](https://app.diagrams.net) (Software $\rightarrow$ Data Flow shapes).

---

## 1. Sub-Processes (10 Functional Processes)

| Process ID | Name | Description & Responsibilities |
|---|---|---|
| **1.1** | **Authentication & Security Gating** | User login (Google / Email), **Teacher and Admin whitelist authorization** (Migration 016), profile initialization, and device push token registration. |
| **1.2** | **Routine Viewing** | Queries active schedules for students (by batch/section) and teachers (by teacher code), overlaying cancellation flags. |
| **1.3** | **Campus Exploration & Status** | Live status engines for **Find Teacher** (locating teacher's active room) and **Room Availability** (calculating occupied/vacant rooms from active routines). |
| **1.4** | **Resource Management** | Admin uploads learning materials (files/Drive links); students browse and stream by semester; dispatches upload notifications. |
| **1.5** | **Profile Management** | Reads and updates user metadata, avatar preferences, and academic identity attributes. |
| **1.6** | **Class Management (Faculty)** | Teachers cancel class occurrences, post room changes/notices, or undo cancellations; records events and dispatches alerts. |
| **1.7** | **Notification & Push Pipeline** | Real-time in-app feed, read/dismiss tracking (`notification_reads`), and automated push dispatch to FCM via Supabase Edge Function `send-push`. |
| **1.8** | **Timetable Ingest & Atomic Publishing** | Dual-path ingest: manages CP-SAT solver generation OR direct workbook upload; executes atomic replacement via `publish_routine` RPC. |
| **1.9** | **Timetable & Academic Configuration** | Admin CRUD for rooms, faculty directories, course eligibility matrices (Migration 013), and term scheduling settings (Migrations 011/015). |
| **1.10** | **Campus Governance & Administration** | Admin broadcasts, user role management, and whitelist provisioning (**Add Teacher** and **Invite Admin**). |

---

## 2. Production Data Stores (D1 – D12)

| Store ID | Table Name | Description | Touched By (Process & R/W) |
|---|---|---|---|
| **D1** | `whitelists` | Pre-authorized email directory for Teachers and Admins. | 1.1 (R), 1.10 (R/W) |
| **D2** | `profiles` | Central user profiles (linked 1:1 to `auth.users`). | 1.1 (R/W), 1.5 (R/W), 1.7 (R), 1.10 (R/W) |
| **D3** | `routines` | Active class schedule slots (single active routine). | 1.2 (R), 1.3 (R), 1.6 (R), 1.8 (R/W) |
| **D4** | `routine_versions` | Version records tracking active status and provenance. | 1.2 (R), 1.8 (R/W) |
| **D5** | `cancellations` | Cancelled class dates and reasons (`routine_id` SET NULL). | 1.2 (R), 1.3 (R), 1.6 (R/W) |
| **D6** | `notifications` | Central notification hub (cancellations, broadcasts, uploads). | 1.4 (W), 1.6 (W), 1.8 (W), 1.10 (W), 1.7 (R) |
| **D7** | `notification_reads`| Junction table storing read/dismiss markers per user. | 1.7 (R/W) |
| **D8** | `device_tokens` | FCM mobile push tokens registered per user. | 1.1 (W), 1.7 (R) |
| **D9** | `resources` | Academic documents, past papers, and Drive links. | 1.4 (R/W) |
| **D10** | `timetable_config` | Physical rooms, faculty directory, and solver settings. | 1.8 (R), 1.9 (R/W) |
| **D11** | `timetable_course_eligibility` | Course-to-faculty eligibility matrix. | 1.8 (R), 1.9 (R/W) |
| **D12** | `timetable_runs` | Audit history of solver runs and publication metadata. | 1.8 (W), 1.10 (R) |

---

## 3. Data Flow List (Balanced with Level-0 Flows)

### Authentication & Profiles (1.1, 1.5)
- `Student / Teacher / Admin` $\longrightarrow$ **1.1**: Credentials & signup metadata.
- **1.1** $\longleftrightarrow$ `D1 Whitelists`: Verify authorization for Teacher and Admin roles (R).
- **1.1** $\longleftrightarrow$ `D2 Profiles`: Insert or retrieve user profile (R/W).
- **1.1** $\longrightarrow$ `D8 Device Tokens`: Save device FCM push token (W).
- `Student / Teacher` $\longleftrightarrow$ **1.5**: Profile updates $\longleftrightarrow$ `D2 Profiles` (R/W).

### Routine & Campus Availability (1.2, 1.3)
- `Student / Teacher` $\longrightarrow$ **1.2**: Routine request (batch/section or teacher code).
- **1.2** $\longleftarrow$ `D3 Routines`: Active class slots (R).
- **1.2** $\longleftarrow$ `D5 Cancellations`: Cancelled occurrences (R).
- **1.2** $\longrightarrow$ `Student / Teacher`: Filtered weekly schedule with cancellations flagged.
- `Student / Teacher / Admin` $\longrightarrow$ **1.3**: Find Teacher query or Room Availability query.
- **1.3** $\longleftarrow$ `D3 Routines`: Active class slots for current day and time (R).
- **1.3** $\longleftarrow$ `D5 Cancellations`: Cancelled occurrences for current date (R).
- **1.3** $\longrightarrow$ `Student / Teacher / Admin`: Real-time teacher classroom location & room occupancy status.

### Class Management (1.6)
- `Teacher` $\longrightarrow$ **1.6**: Cancellation submission (date + reason) or notice/room change.
- **1.6** $\longleftarrow$ `D3 Routines`: Target class slot details (R).
- **1.6** $\longrightarrow$ `D5 Cancellations`: Insert or delete cancellation record (W).
- **1.6** $\longrightarrow$ `D6 Notifications`: Insert class cancellation or room change notice (W).

### Notification & Push Pipeline (1.7)
- **1.7** $\longleftarrow$ `D6 Notifications`: New alert row inserted (R).
- **1.7** $\longleftarrow$ `D2 Profiles`: Resolve target audience roles/cohorts (R).
- **1.7** $\longleftarrow$ `D8 Device Tokens`: Retrieve FCM tokens for audience (R).
- **1.7** $\longrightarrow$ `Firebase FCM`: Push notification payload + device tokens.
- `Firebase FCM` $\longrightarrow$ `Student / Teacher`: Heads-up push alert delivered to mobile devices.
- `Student / Teacher / Admin` $\longleftrightarrow$ **1.7**: In-app feed and mark/dismiss read receipts $\longleftrightarrow$ `D7 Notification Reads` (R/W).

### Timetable Ingest, Solving & Publishing (1.8, 1.9)
- `Admin` $\longrightarrow$ **1.8**: Upload distribution `.xlsx` OR pre-rendered `.xlsx` workbook.
- **1.8** $\longleftarrow$ `D10 Timetable Config`: Rooms, faculty off-days, and term calendar settings (R).
- **1.8** $\longleftarrow$ `D11 Course Eligibility`: Qualification rules for validation (R).
- **1.8** $\longrightarrow$ `Timetable Solver Engine`: Multipart `.xlsx` + config parameters (Solver Route).
- `Timetable Solver Engine` $\longrightarrow$ **1.8**: Solved routine rows + solver statistics + validation report.
- **1.8** $\longrightarrow$ `D4 Routine Versions`: Insert version record and activate (W).
- **1.8** $\longrightarrow$ `D3 Routines`: Replace active class rows (`publish_routine` atomic RPC) (W).
- **1.8** $\longrightarrow$ `D12 Timetable Runs`: Record solver run history and metrics (W).
- **1.8** $\longrightarrow$ `D6 Notifications`: Dispatch "Routine Published" campus alert (W).
- `Admin` $\longleftrightarrow$ **1.9**: Manage rooms, faculty, eligibility, and scheduling settings $\longleftrightarrow$ `D10 Config` & `D11 Eligibility` (R/W).

### Campus Administration (1.10)
- `Admin` $\longrightarrow$ **1.10**: Campus broadcast text $\longrightarrow$ `D6 Notifications` (W).
- `Admin` $\longleftrightarrow$ **1.10**: Add teacher / Invite admin $\longleftrightarrow$ `D1 Whitelists` (R/W).
- `Admin` $\longleftrightarrow$ **1.10**: View and update user roles $\longleftrightarrow$ `D2 Profiles` (R/W).
- `Admin` $\longleftarrow$ **1.10**: System analytics & audit logs $\longleftarrow$ `D2`, `D3`, `D12` (R).

---

## 4. Key Architectural Patterns to Highlight

1. **The Notification Hub (`D6 Notifications`):**
   Four distinct processes write to `D6`: **1.4 (Resources)**, **1.6 (Class Management)**, **1.8 (Timetable Publish)**, and **1.10 (Campus Broadcast)**. Only Process **1.7 (Notification Pipeline)** reads from `D6`. This unified hub guarantees that any in-app notification immediately translates into an automated Firebase mobile push.
2. **Atomic Versioned Publishing:**
   Process **1.8** interacts with both **`D4 Routine Versions`** and **`D3 Routines`** through the PostgreSQL function `publish_routine()`. This replaces the entire active schedule inside a single database transaction, preventing partial updates or conflicting routine versions.
3. **Double-Layered Security Gating:**
   Process **1.1** inspects **`D1 Whitelists`** before creating or updating a profile with `teacher` or `admin` roles, enforcing strict administrative control over elevated privileges.
