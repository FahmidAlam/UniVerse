# Diagram 3 — Data Flow Diagram, Level 0 (Context Diagram)

> **What this shows:** The system boundary of **UniVerse — A Campus Companion** represented as a single central process (**0**), surrounded by external human entities and external backend systems, detailing every named data flow passing across the boundary.  
> **Source of Truth:** Live application inputs/outputs, Flutter services, Supabase database interfaces, Render solver API, and Firebase FCM.  
> **Tool to render:** [draw.io / diagrams.net](https://app.diagrams.net) (using Gane-Sarson or Yourdon/DeMarco shapes).

---

## 1. Central Process

```
         ┌───────────────────────────────────┐
         │                 0                 │
         │              UniVerse             │
         │        A Campus Companion         │
         └───────────────────────────────────┘
```
Process **0** encapsulates the entire client-server software application (Flutter mobile app, Supabase PostgreSQL, Authentication, and Storage).

---

## 2. External Entities (5 Boundary Entities)

| Entity ID | Entity Name | Type | Description & Boundary Responsibility |
|---|---|---|---|
| **E1** | **Student** | Human User | Interacts with personalized schedules, class countdowns, learning materials, and campus exploration tools. |
| **E2** | **Teacher** | Human User | Accesses teaching rosters, manages class cancellations, issues room changes, and queries campus availability (whitelist gated). |
| **E3** | **Admin** | Human User | Directs timetable operations (solver & direct ingest), configures faculty/courses/rooms, issues broadcasts, and registers staff. |
| **E4** | **Timetable Solver Engine** | External System | Python FastAPI service on Render running Google OR-Tools CP-SAT constraint optimization. |
| **E5** | **Firebase FCM & Mobile Push** | External System | Cloud delivery service receiving dispatch payloads from Supabase Edge Functions and delivering native OS notifications to user phones. |

---

## 3. Data Flow Inventory (Numbered F1 – F10)

| Flow # | Source (From) | Data Transferred (Label) | Destination (To) |
|---|---|---|---|
| **F1** | **Student** | Login credentials · profile updates · alert dismissals · Find Teacher search query · Room Availability query | **0 UniVerse** |
| **F2** | **0 UniVerse** | Personalized routine · live/next class countdown · study resources · notifications · teacher location · room vacancy status | **Student** |
| **F3** | **Teacher** | Login credentials (whitelist verified) · class cancellation (date + reason) · notice/room change text · Find Teacher/Room queries | **0 UniVerse** |
| **F4** | **0 UniVerse** | Teaching routine · today's assigned classes · cancellation status · notifications · room vacancy status | **Teacher** |
| **F5** | **Admin** | Login credentials · distribution `.xlsx` · pre-rendered `.xlsx` workbook · manual routine edits · room/faculty/eligibility/settings config · broadcast announcements · teacher whitelist data · resource uploads | **0 UniVerse** |
| **F6** | **0 UniVerse** | Solver report & validation · active routine status · user lists · broadcast history · dashboard analytics | **Admin** |
| **F7** | **0 UniVerse** | Course distribution `.xlsx` + solver configuration parameters (`time_limit`, `semester_label`, rules) | **Timetable Solver Engine** |
| **F8** | **Timetable Solver Engine** | Generated timetable rows · service rows · solver statistics · validation diagnostics · rendered workbook bytes | **0 UniVerse** |
| **F9** | **0 UniVerse** | Notification payload + target device tokens (via Supabase Webhook $\rightarrow$ Edge Function) | **Firebase FCM** |
| **F10** | **Firebase FCM** | Native OS push notification alerts (heads-up notifications on mobile devices) | **Student / Teacher** |

---

## 4. Architectural Data Pipeline Summary

1. **Authentication & Gating:** All users authenticate via F1, F3, or F5. For Teachers and Admins, credentials are automatically validated against the database whitelist before access is granted.
2. **Dual-Path Routine Pipeline:**
   - **Solver Path:** Admin uploads course distribution file $\rightarrow$ F7 to Timetable Engine $\rightarrow$ Engine returns solved schedule via F8 $\rightarrow$ Admin verifies and publishes.
   - **Direct Upload Path:** Admin uploads pre-rendered Excel workbook via F5 $\rightarrow$ UniVerse parses sheets client-side and publishes directly to routines.
3. **Campus Exploration Querying:** Real-time queries for teacher location and room vacancy arrive through F1/F3 and return current active slot calculations via F2/F4.
4. **Automated Notification Pipeline:** When any alert is created (cancellation, broadcast, resource upload, routine publication), UniVerse triggers F9 to Firebase FCM, which delivers F10 push notifications to mobile devices.

---

## 5. Placement & Layout Blueprint (draw.io)

```
        Student [E1]                                      Admin [E3]
         │       ▲                                         │       ▲
      F1 │       │ F2                                   F5 │       │ F6
         ▼       │                                         ▼       │
      ┌───────────────────────────────────────────────────────────────┐
      │                                                               │
      │                               0                               │
      │                           UniVerse                            │
      │                      A Campus Companion                       │
      │                                                               │
      └───────────────────────────────────────────────────────────────┘
         ▲       │                    ▲                 ▲          │
      F3 │       │ F4                 │ F8              │ F10      │ F7
         │       ▼                    │                 │          ▼
        Teacher [E2]         Timetable Solver Engine   Firebase   Timetable Solver
                                    [E4]                 FCM        Engine [E4]
                                                         [E5]
```

### Visual Layout Recommendations:
- Place human users (**Student**, **Teacher**) on the left.
- Place administrative and computational external systems (**Admin**, **Timetable Engine**) on the right.
- Place **Firebase FCM** at the bottom center to illustrate the outbound dispatch pipeline.
- Separate inbound and outbound arrow pairs with generous margins so text labels never overlap.
