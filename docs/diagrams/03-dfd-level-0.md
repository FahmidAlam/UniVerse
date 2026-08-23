# Diagram 3 — Data Flow Diagram, Level 0 (Context Diagram)

> **Goal of this file:** give you everything to draw the context diagram **by hand** in draw.io,
> with every arrow's exact *from → data → to* spelled out. Do not copy the PNG's layout — follow
> the placement plan in §5; it is cleaner.
>
> **What a Level-0 DFD shows:** the whole app as **one process** in the middle, the outside
> world (people + external systems) around it, and the **named data** moving in and out.
> No data stores at this level (those are Level-1 only).

---

## 1. The one process (centre)

A single bubble in the middle:

```
        ┌──────────────────┐
        │        0         │
        │     UniVerse     │
        │ A Campus Companion│
        └──────────────────┘
```

Number it **0**. It is the only process on this page.

---

## 2. External entities (5 boxes around the centre)

| # | Entity | Type | Role in the system |
|---|---|---|---|
| E1 | **Student** | person | Views routine, dashboard, resources; reads/dismisses alerts. |
| E2 | **Teacher** | person | Views classes; cancels a class; posts notice / room change. |
| E3 | **Admin** | person | Manages routine, generates timetable, broadcasts, users, resources. |
| E4 | **Timetable Engine (OR-Tools)** | external system | Separate Python server that solves the timetable. |
| E5 | **Firebase FCM** | external system | Delivers push notifications to phones. |

> **Why no "Supabase" box?** Supabase (Postgres + Auth + Storage) **is** the system's own
> backend — it lives *inside* process 0, so it is not an external entity. Google OAuth is the only
> third-party used at login; it is minor, so we fold it into the system. (If your examiner insists,
> you may add a 6th box "Google OAuth" connected only to the login flow F1.)

---

## 3. Data flows — the exact arrows (from → data → to)

Each numbered row = **one arrow**. Draw the arrowhead pointing at the **To** column.
"⇄" entities get two arrows (one each way) — never a single double-headed line in a DFD.

| # | From | Data carried (label the arrow with this) | To |
|---|---|---|---|
| **F1** | Student | login / sign-up credentials · profile edits · "dismiss alert" action | **0 UniVerse** |
| **F2** | **0 UniVerse** | weekly routine · dashboard (live/next class) · resource files & links · notifications | Student |
| **F3** | Teacher | login credentials · cancel-class (date + reason) · notice / room-change text | **0 UniVerse** |
| **F4** | **0 UniVerse** | weekly routine · today's class list · cancellation alerts | Teacher |
| **F5** | Admin | login · Excel distribution file · manual routine edits · generator config · broadcast text · new-admin email · role changes · resource files / links | **0 UniVerse** |
| **F6** | **0 UniVerse** | dashboard counts · generation report + validation · user lists · broadcast history | Admin |
| **F7** | **0 UniVerse** | distribution **.xlsx** + config **JSON** (rooms, faculty, settings) | Timetable Engine |
| **F8** | Timetable Engine | generated timetable rows · solver stats · validation result · rendered workbook | **0 UniVerse** |
| **F9** | **0 UniVerse** | notification payload + target device tokens | Firebase FCM |
| **F10** | Firebase FCM | push notification (delivered to phones) | Student / Teacher |

That is **10 arrows total** (2 each for Student, Teacher, Admin, Engine; 2 for FCM). Nothing else.

---

## 4. Reading order (so you understand the story)

1. A user **logs in** → F1 / F3 / F5 in, F2 / F4 / F6 back out (what they see).
2. Admin sends the **Excel file** → F7 to the Engine; the Engine returns the **solved timetable**
   → F8; the app shows the report → F6 and the routine ends up visible to users → F2 / F4.
3. Any alert created in the app → F9 to FCM → F10 push lands on the phone.

---

## 5. Placement plan (draw it like this — avoids crossings)

```
   Student ┐                                   ┌ Admin
           │  F1↘        ┌─────────┐       F5↘ │
           │      ╲      │    0    │      ╱     │
           │  F2↖  ╲────►│ UniVerse│◄────╱  ↖F6 │
           │             └────┬────┘            │
   Teacher ┘  F3↘  ╱─────►  ▲ │ ▼  ◄─────╲ ↘F7  ┌ Timetable Engine
           │  F4↖ ╱       F9 │ │ F8        ╲ ↖F8│
           └             ┌───┴─┴───┐            └
                         │ Firebase │  (F9 down, F10 back up to Student/Teacher)
                         │  (FCM)   │
                         └──────────┘
```

- **Students/Teachers on the LEFT**, **Admin + Engine on the RIGHT**, **Firebase at the BOTTOM**.
- Keep the two arrows of each pair **parallel** and **clearly separated** (offset the labels so
  the "in" and "out" text never touch — that was the only flaw in the auto-generated PNG).

---

## 6. Build steps (draw.io)

1. Drop one **process** (circle or rounded rectangle) in the centre → label `0  UniVerse`.
2. Drop the **5 entity squares** per §5.
3. Add the **10 arrows** from §3, one at a time, **typing the data label on each as you go**.
4. Check every entity has the right number of arrows: Student 2, Teacher 2, Admin 2, Engine 2,
   FCM 2.
5. Export → PDF/PNG.

---

## 7. Don't-skip checklist

- [ ] Exactly **one** process, numbered **0**. No data stores.
- [ ] **5 entities**: Student, Teacher, Admin, Timetable Engine, Firebase FCM.
- [ ] All **10 arrows (F1–F10)** present and **each one labelled** with its data.
- [ ] Student / Teacher / Admin / Engine each have **one in + one out** arrow.
- [ ] FCM: one arrow in (F9 payload+tokens), one out (F10 push).
- [ ] Every flow here will reappear inside a process in Level-1 (balancing).
