# UniVerse Timetable Engine

Automatic department timetable generator for UniVerse — **FastAPI + Google OR-Tools (CP-SAT)**.
This is the advisor-required differentiator: given a set of course offerings, teachers (with
day-offs), sections, and rooms, it produces a **conflict-free weekly timetable** and exposes it to
the Flutter app over a small async HTTP API.

## What it guarantees

- No teacher is in two places at once.
- No section has two classes at once.
- Teacher day-offs are respected (hard constraint).
- Labs occupy consecutive slots inside one block (morning 09:30–13:30 / afternoon 14:10–16:50).
- Per-slot class count never exceeds available rooms (so room assignment always succeeds).
- **Soft goal:** each section's daily load is spread out, not clumped.

Two phases (see `solver.py`):
1. **CP-SAT** assigns every class meeting a `(day, slot)`.
2. **Greedy** assigns a concrete room — sessionals → lab rooms first, theory → theory rooms.

## Run it

```bash
cd engine
python -m venv .venv
# Windows:  .venv\Scripts\activate
# macOS/Linux:  source .venv/bin/activate
pip install -r requirements.txt

# Quick standalone check (prints stats + validation, no server):
python solver.py

# Start the API:
uvicorn main:app --reload --port 8000
```

The Android emulator reaches your host machine at **`http://10.0.2.2:8000`** — set that as
`timetableBaseUrl` in the Flutter app's dart-define file.

## API

| Method | Path | Returns |
|---|---|---|
| `POST` | `/api/timetable/generate` | `{ "job_id": "..." }` — starts a background solve |
| `GET`  | `/api/timetable/status/{job_id}` | `{ state: queued\|solving\|done\|failed, progress, stats?, validation? }` |
| `GET`  | `/api/timetable/result/{job_id}` | `{ rows, stats, validation }` |

`rows` are shaped to match the Supabase `routines` table columns, so the Flutter client publishes
them verbatim and the **existing** student/teacher routine screens display them with no extra code.

Body for `generate` is optional. Pass `{ "dataset": {...}, "time_limit_s": 20 }` to override the
default input; otherwise it uses `fixtures/offerings.json`.

## Input data

`fixtures/offerings.json` — teachers, courses, sections, rooms, day-offs. Teachers/courses are kept
coherent with `../supabase/seed/seed_routine.sql`, and it generates a **brand-new cohort (batch 63)**
so published output never collides with the seeded batch 62.

## Deploy (optional, post-demo)

```
uvicorn main:app --host 0.0.0.0 --port $PORT
```
Works on Railway/Render free tier. Not required for the defense demo — local + `10.0.2.2` is enough.
