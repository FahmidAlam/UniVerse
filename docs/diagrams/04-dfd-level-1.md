# Diagram 4 — Data Flow Diagram, Level 1

> **Goal of this file:** draw a **clean, non-messy** Level-1 DFD by hand. The PNG looks crowded
> because several processes share the same data stores — the cure is the **placement plan in §4**
> (put the shared stores in the middle) plus the **complete numbered flow list in §5** so no arrow
> is guessed.
>
> **What a Level-1 DFD shows:** the inside of process 0 — its **processes** (numbered 1.x), the
> **data stores** (database tables) they read/write, the **external entities**, and every named
> data flow between them.
>
> **Balancing rule:** every Level-0 flow (F1–F10) reappears here, now attached to a specific 1.x
> process.

---

## 1. Processes (8 circles, numbered 1.1 – 1.8)

| # | Process | What happens inside |
|---|---|---|
| **1.1** | **Authentication** | Sign-up / login (Google or email + OTP), admin **whitelist** gate, create the profile row, save the device push token. |
| **1.2** | **Routine Viewing** | Return a student's / teacher's weekly schedule with cancelled classes marked. |
| **1.3** | **Resource Management** | Admin uploads files / Drive links; students browse by semester; alert students of new uploads. |
| **1.4** | **Profile Management** | View and edit the logged-in user's profile. |
| **1.5** | **Class Management** | Teacher cancels a class occurrence / posts a notice; writes the cancellation and fires an alert. |
| **1.6** | **Notification & Push Dispatch** | Read notifications, resolve audience, track per-user read state, send the push via FCM. |
| **1.7** | **Timetable Generation & Publish** | Send Excel + config to the engine, publish the solved routine, log the run, send "routine published" push alert; also manual routine / config edits. |
| **1.8** | **Admin Panel** | Broadcast campus notifications, manage users / roles, invite admins. |

---

## 2. Data stores (10, labelled D1 – D10)

A data store is an open-ended rectangle. The "touched by" column tells you which processes connect
to it — **this is what decides where you place it** (§4).

| ID | Data store (table) | Touched by — read (R) / write (W) |
|---|---|---|
| **D1** | Whitelists | 1.1 (R) · 1.8 (R/W) |
| **D2** | Profiles | 1.1 (W) · 1.4 (R/W) · 1.6 (R) · 1.8 (R/W)  ← **shared** |
| **D3** | Routines | 1.2 (R) · 1.5 (R) · 1.7 (W)  ← **shared** |
| **D4** | Cancellations | 1.2 (R) · 1.5 (W) |
| **D5** | Resources | 1.3 (R/W) |
| **D6** | Notifications | 1.3 (W) · 1.5 (W) · 1.7 (W) · 1.8 (W) · 1.6 (R)  ← **the HUB** |
| **D7** | Notification Reads | 1.6 (R/W) |
| **D8** | Device Tokens | 1.1 (W) · 1.6 (R) |
| **D9** | Timetable Config *(= timetable_rooms + timetable_faculty + timetable_settings)* | 1.7 (R) · 1.8 (R/W) |
| **D10** | Timetable Runs | 1.7 (W) |

> **D9 is one store standing for the three config tables** (rooms / faculty / settings). They are
> always read together to build the engine config, so merging them keeps the diagram readable. If
> your examiner wants all 12 tables shown, split D9 into D9a/D9b/D9c — but one box is cleaner.

---

## 3. External entities (5 — same as Level-0)

**Student**, **Teacher**, **Admin**, **Timetable Engine (OR-Tools)**, **Firebase FCM**.

---

## 4. Placement plan (THIS is what stops the mess)

The two stores that cause crossings are **D6 Notifications** (5 connections) and **D2 Profiles**
(4 connections). **Put them in the middle**, and place each process *next to the store it uses
most*. Draw on a **wide landscape page**.

```
 D1 Whitelists      D2 Profiles(shared)                         D5 Resources
      │                 │      │                                     │
   (1.1 Auth)      (1.4 Profile)│                              (1.3 Resources)
      │  ╲              │       └─────────┐                          │
   D8 Tokens╲          │                 │                          │
      │       ╲   ┌─────────────┐        │                          │
 STUDENT ─────────│   centre    │──────────────────────── TEACHER  │
      │           │ (shared bus)│        │                          │
   (1.2 Routine)  └─────────────┘   D6 NOTIFICATIONS ──── (1.5 Class Mgmt)
     │     ╲                          (HUB - centre)            │
 D3 Routines  D4 Cancellations            │                     │
                                     (1.6 Notify/Push) ── D7 Reads
                                          │   ╲
 ADMIN ── (1.8 Admin Panel)               │    ╲── (reads D8 Tokens) ── FIREBASE FCM
              ╲                            │
               (1.7 Timetable Gen) ── ENGINE
                   │       ╲
              D9 Config   D10 Runs
```

**Zone-by-zone:**
- **Top-left:** D1 Whitelists, **1.1 Authentication**, D8 Device Tokens.
- **Top-centre:** **D2 Profiles** (keep central — 1.1, 1.4, 1.6, 1.8 all reach it), **1.4 Profile**.
- **Left side:** **1.2 Routine Viewing** with **D3 Routines** + **D4 Cancellations** to its left.
- **Right-upper:** **1.5 Class Management**.
- **Right-lower / centre:** **D6 Notifications (HUB)** with **1.6 Notify/Push** beside it; **D7
  Notification Reads** and **D8 Device Tokens** at the far right; **Firebase FCM** bottom-right.
- **Lower-left:** **1.3 Resource Management** with **D5 Resources**.
- **Bottom-left:** **Admin** entity, **1.8 Admin Panel**.
- **Bottom-centre:** **1.7 Timetable Generation** with **D9 Config** + **D10 Runs** below it and
  **Timetable Engine** to its right.

**Three rules that keep it clean:**
1. A line may only connect **process ↔ store**, **process ↔ entity**, or **process ↔ process** —
   **never store ↔ entity** directly.
2. For read **and** write to the same store, draw **one double-headed arrow** (halves the lines).
3. The unavoidable long lines are the 4 writers into **D6** (from 1.3, 1.5, 1.7, 1.8). Keep D6
   central so these stay short, and route 1.7→D6 along the bottom edge, not through the centre.

---

## 5. Complete flow list (every arrow, grouped by process)

Read each as **From → [data label] → To**. R = into a process from a store, W = into a store.

### Process 1.1 — Authentication
| # | From | Data | To |
|---|---|---|---|
| F1 | Student / Teacher / Admin | login & sign-up credentials | 1.1 |
| F2 | 1.1 | verify role (admin gate) **(R)** | D1 Whitelists |
| F3 | 1.1 ⇄ | create / read profile **(R/W)** | D2 Profiles |
| F4 | 1.1 | save device push token **(W)** | D8 Device Tokens |
| F5 | 1.1 | session + role (what to show next) | Student / Teacher / Admin |

### Process 1.2 — Routine Viewing
| # | From | Data | To |
|---|---|---|---|
| F6 | Student | routine request (batch + section) | 1.2 |
| F7 | Teacher | routine request (teacher code) | 1.2 |
| F8 | D3 Routines | active class rows **(R)** | 1.2 |
| F9 | D4 Cancellations | cancelled occurrences **(R)** | 1.2 |
| F10 | 1.2 | weekly routine / today's classes (cancelled marked) | Student / Teacher |

### Process 1.3 — Resource Management
| # | From | Data | To |
|---|---|---|---|
| F11 | Admin | upload file / Drive link + metadata | 1.3 |
| F12 | Student | browse request (semester) | 1.3 |
| F13 | 1.3 ⇄ | insert / read / delete **(R/W)** | D5 Resources |
| F14 | 1.3 | resource files & links | Student |
| F15 | 1.3 | "new resource" alert **(W)** | D6 Notifications |

### Process 1.4 — Profile Management
| # | From | Data | To |
|---|---|---|---|
| F16 | Student / Teacher | profile edits | 1.4 |
| F17 | 1.4 ⇄ | read / update profile **(R/W)** | D2 Profiles |
| F18 | 1.4 | profile data | Student / Teacher |

### Process 1.5 — Class Management (teacher)
| # | From | Data | To |
|---|---|---|---|
| F19 | Teacher | cancel (date + reason) / notice / room-change | 1.5 |
| F20 | D3 Routines | the class slot being acted on **(R)** | 1.5 |
| F21 | 1.5 | cancellation row (undo = delete) **(W)** | D4 Cancellations |
| F22 | 1.5 | class-cancel / room-change / notice alert **(W)** | D6 Notifications |

### Process 1.6 — Notification & Push Dispatch  *(reads the hub, sends the push)*
| # | From | Data | To |
|---|---|---|---|
| F23 | D6 Notifications | new notification rows **(R)** | 1.6 |
| F24 | D2 Profiles | audience (role / batch / section) **(R)** | 1.6 |
| F25 | D8 Device Tokens | target devices' tokens **(R)** | 1.6 |
| F26 | 1.6 ⇄ | read / dismiss marks **(R/W)** | D7 Notification Reads |
| F27 | 1.6 | in-app notification feed | Student / Teacher / Admin |
| F28 | 1.6 | push payload + tokens | Firebase FCM |
| F29 | Firebase FCM | push notification (to phones) | Student / Teacher |

### Process 1.7 — Timetable Generation & Publish
| # | From | Data | To |
|---|---|---|---|
| F30 | Admin | Excel distribution file + generate request; manual routine / config edits | 1.7 |
| F31 | D9 Timetable Config | rooms / faculty / settings **(R)** | 1.7 |
| F32 | 1.7 | distribution file + config JSON | Timetable Engine |
| F33 | Timetable Engine | generated rows + stats + validation + workbook | 1.7 |
| F34 | 1.7 | generation report + validation + grid | Admin |
| F35 | 1.7 | published / edited class rows **(W)** | D3 Routines |
| F36 | 1.7 | run record (stats / validation / status) **(W)** | D10 Timetable Runs |
| F37 | 1.7 | "routine published" alert **(W)** | D6 Notifications |

### Process 1.8 — Admin Panel
| # | From | Data | To |
|---|---|---|---|
| F38 | Admin | broadcast text; role change; invite-admin email | 1.8 |
| F39 | 1.8 | broadcast notification **(W)** | D6 Notifications |
| F40 | 1.8 ⇄ | read users / update roles **(R/W)** | D2 Profiles |
| F41 | 1.8 ⇄ | invite admin / read whitelist **(R/W)** | D1 Whitelists |
| F42 | 1.8 | dashboard counts / user lists / broadcast history | Admin |

---

## 6. The one thing to explain in the defense (the notification hub)

Look at **D6 Notifications**: processes **1.3, 1.5, 1.7, and 1.8** all *write* to it, and only
**1.6** *reads* it. Whenever any of those four writes a notification row (resource upload, class
cancel/notice, routine published, admin broadcast), process **1.6** picks it up, looks up the
audience in **D2 Profiles** and the phones in **D8 Device Tokens**, and pushes via **Firebase**.
So **"create a notification" and "send a push" are a single unified path** — that is the system's
signature design (flows F15, F22, F37, F39 all feed F23 → F28 → F29).

---

## 7. Optional: split into two pages if it still feels crowded

If one page is too busy, draw **DFD-1a (user side):** processes 1.1, 1.2, 1.3, 1.4, 1.5, 1.6 with
Student/Teacher/Firebase and stores D1–D8. Then **DFD-1b (admin / timetable side):** processes
1.7, 1.8, 1.6 with Admin/Engine/Firebase and stores D1, D2, D3, D6, D9, D10. Both are valid and
each is far cleaner.

---

## 8. Don't-skip checklist

- [ ] **8 processes** (1.1–1.8) and **10 stores** (D1–D10) — no `documents`/`assignments`/`submissions`.
- [ ] **5 external entities** (Student, Teacher, Admin, Engine, FCM).
- [ ] All **42 flows (F1–F42)** drawn and labelled; bidirectional ones use a double-headed arrow.
- [ ] **D6 Notifications** has 4 writers (1.3, 1.5, 1.7, 1.8) and 1 reader (1.6).
- [ ] **D2 Profiles** reached by 1.1, 1.4, 1.6, 1.8 — keep it central.
- [ ] Process 1.7 reads D9, writes D3 + D10 + D6, and exchanges with the Engine.
- [ ] **No store touches an entity directly** — always through a process.
- [ ] Diagram balances with Level-0 (F1↔F1.x, the Excel file goes into 1.7, etc.).
