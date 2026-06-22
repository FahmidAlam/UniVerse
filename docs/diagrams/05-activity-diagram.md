# Diagram 5 — Activity Diagram

> **What this shows:** the step-by-step flow of actions each type of user takes — from
> opening the app through to logging out — including decisions, branching paths (fork / join),
> and the "No" loop back when they stay in the app.
>
> **Tool to use:** draw.io / diagrams.net — use the UML Activity shape set (filled circle =
> start, circled filled circle = end, diamond = decision, rounded rectangle = action,
> horizontal bar = fork / join).

---

## 1. Three swimlanes (one per actor)

Draw the diagram in **landscape** orientation with **three side-by-side vertical swimlanes**,
each running top-to-bottom.

| Swimlane | Actor | Colour suggestion |
|---|---|---|
| Left | **Student / User** | Light blue |
| Centre | **Teacher / Faculty** | Light green |
| Right | **Admin** | Light orange |

Add a dashed vertical line between each swimlane.

---

## 2. Notation key

| Shape | Meaning |
|---|---|
| Filled black circle | **Start** node |
| Circled filled circle | **End** node |
| Rounded rectangle | **Action** (activity) |
| Diamond | **Decision** (Yes/No branch) |
| Dashed rounded rectangle | Error / exceptional action |
| Horizontal solid line spanning multiple columns | **Fork** (parallel) or **Join** (sync) |
| Arrow | Control flow — label "Yes" / "No" on decision branches |

---

## 3. Swimlane 1 — Student / User

**Entry path (linear, left to right at the top):**

```
● Start
  ↓
[Create Account / Login]  ← sign up or sign in (email or Google)
  ↓
◇ Verify Credentials
  ├── No ──→ [Show Error]  ──(loop)──→ [Create Account / Login]
  └── Yes ──→ [Home / Dashboard]
                ↓
              ◇ Select Option
```

**Fork (6 parallel branches from Select Option):**

```
          ┌──────────┬──────────┬──────────────┬────────────────┬──────────┐
       Dashboard  Routine   Resources    Notifications  ManageClasses  Profile
          │          │          │             │               │           │
   [Live/Next    [Load      [Load         [Load Alerts]  [Select      [Load
   Class Count]  Routine]   Resources]                   Class]       Profile]
          │          │          │                              │           │
   [Today's      [View       [Browse by    [Mark/Dismiss   [Cancel/     [Edit
   Classes]      Weekly       Semester]    Alert]          Post Notice  Profile]
          │       Grid]          │                          / Undo]
   [Recent       │          [Open File /                       │
   Alerts]    [Cancelled     Link]                        [Alert Sent
               Classes]                                   to Students]
```

**Join → logout:**

```
          └──────────┴──────────┴──────────────┴────────────────┴──────────┘
                                       ↓  (join)
                                   ◇ Logout?
                         ┌── Yes ──→ ⊙ End
                         └── No  ──────────────────────→ ◇ Select Option (loop back)
```

---

## 4. Swimlane 2 — Teacher / Faculty

**Entry path:**

```
● Start
  ↓
[Teacher Login]
  ↓
◇ Verify Credentials
  ├── No ──→ [Show Error] ──(loop)──→ [Teacher Login]
  └── Yes ──→ [Teacher Dashboard]
                    ↓
                ◇ Select Option
```

**Fork (5 parallel branches from Select Option):**

```
        ┌──────────┬──────────┬─────────────────┬────────────────┬──────────┐
     Dashboard  Routine   Manage Classes     Notifications     Profile
        │          │          │                   │               │
 [Live/Next    [Load      [Select Day         [Load Alerts]  [Load
 Class Count]  Routine]    & Class]                           Profile]
        │          │          │               [Mark/Dismiss
 [Today's      [View      [Cancel / Post      Alert]          [Edit
 Classes]      Weekly      Notice / Undo]                     Profile]
        │       Grid]          │
 [Recent       │          [Confirm &
 Alerts]    [Cancelled     Send Alert]
             Classes]
```

> **Manage Classes** is the Teacher's signature feature — the 3-step chain (Select →
> Action → Confirm+Alert) is the defence talking point for this swimlane.

**Join → logout:**

```
        └──────────┴──────────┴─────────────────┴────────────────┴──────────┘
                                      ↓  (join)
                                  ◇ Logout?
                        ┌── Yes ──→ ⊙ End
                        └── No  ─────────────────────→ ◇ Select Option (loop back)
```

---

## 5. Swimlane 3 — Admin

**Entry path:**

```
● Start
  ↓
[Admin Login]   ← admin must be on the whitelist
  ↓
◇ Verify Credentials
  ├── No ──→ [Show Error] ──(loop)──→ [Admin Login]
  └── Yes ──→ [Admin Dashboard]
                    ↓
                ◇ Select Option
```

**Fork (5 parallel branches from Select Option):**

```
       ┌───────────────┬────────────────┬───────────────┬──────────────┬────────────────┐
   Manage Routine  Generate Timetable  Broadcast     Manage Users  Manage Resources
       │               │                   │               │               │
 [Add / Edit /    [Upload Excel]       [Compose &     [View Users /  [Upload /
 Delete Routine]       │                Send Broadcast] Change Role]  Delete Resource]
                  [Run Engine                              │
                   & Review]                          [Invite Admin]
                       │
                  [Publish Routine]
```

> **Generate Timetable** has a 3-step chain — this is the system's differentiator.
> Mention it explicitly in the defence.

**Join → logout:**

```
       └───────────────┴────────────────┴───────────────┴──────────────┴────────────────┘
                                             ↓  (join)
                                         ◇ Logout?
                               ┌── Yes ──→ ⊙ End
                               └── No  ────────────────────→ ◇ Select Option (loop back)
```

---

## 6. Complete element count

| Swimlane | Start | End | Actions | Decisions | Forks/Joins |
|---|---|---|---|---|---|
| Student | 1 | 1 | 16 | 3 (verify, select, logout) | 1 fork, 1 join |
| Teacher | 1 | 1 | 14 | 3 | 1 fork, 1 join |
| Admin | 1 | 1 | 11 | 3 | 1 fork, 1 join |
| **Total** | **3** | **3** | **~41** | **9** | **3 + 3** |

---

## 7. Key paths to highlight in the defence

1. **Cancel class (Teacher):** Select Day & Class → Cancel / Post Notice / Undo →
   Confirm & Send Alert. Shows the real-time notification pipeline.

2. **Generate Timetable (Admin):** Upload Excel → Run Engine & Review → Publish Routine.
   Shows the OR-Tools CP-SAT engine integration — the system's differentiator.

3. **"No" logout loops** (all swimlanes): the user stays in the app and returns to
   "Select Option" — shows the app is session-based (not one-shot).

---

## 8. Don't-skip checklist

- [ ] **3 swimlanes** clearly labelled (Student, Teacher, Admin).
- [ ] Each swimlane has exactly **1 Start** (filled circle) and **1 End** (circled circle).
- [ ] Each swimlane has a **Verify Credentials** decision with Yes/No and an error dashed box.
- [ ] **Student**: 6-way fork (Dashboard, Routine, Resources, Notifications, Manage Classes, Profile).
- [ ] **Teacher**: 5-way fork (Dashboard, Routine, Manage Classes, Notifications, Profile).
  - Manage Classes has the 3-step chain: Select → Action → Alert.
- [ ] **Admin**: 5-way fork (Manage Routine, Generate Timetable, Broadcast, Manage Users, Manage Resources).
  - Generate Timetable has 3-step chain: Upload → Run & Review → Publish.
- [ ] Each swimlane has a **Logout decision** (Yes → End, No → loop back to Select Option).
- [ ] All branches meet at a **join bar** before the Logout decision.
