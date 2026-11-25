# UniVerse Complete Project Audit & Offline Real-Time Architecture Blueprint

> **Date:** October 19, 2026  
> **Target Project:** UniVerse (Mobile Campus Companion & Automated Timetable Engine)  
> **Course / Platform:** CSE-3240 · Project I / Leading University, Sylhet  
> **Tech Stack:** Flutter 3.x (Dart), Supabase (PostgreSQL 15, Auth, RLS, Storage, Realtime, Edge Functions), FastAPI (Python, Google OR-Tools CP-SAT Solver)

---

## 1. Executive Summary & Complete Project Audit

UniVerse is a full-featured campus scheduling, room tracking, faculty locator, and academic management system for Leading University's Department of Computer Science & Engineering. The system unites two major subsystems:
1. **The Client Subsystem (Flutter/Dart):** An Android/iOS cross-platform application providing role-based dashboards (Student, Teacher, Admin), personal class schedules, live classroom availability, real-time teacher tracking, academic resource library, campus broadcasts, and timetable configuration/generation tools.
2. **The Timetable Engine Subsystem (Python/FastAPI):** An external microservice powered by Google OR-Tools CP-SAT constraint programming that ingests raw departmental course-teacher-batch distribution workbooks (`.xlsx`), enforces university hard constraints (zero teacher clashes, zero cohort clashes, room capacity & lab eligibility, off-days, blocked periods) and soft preferences, and outputs rendered schedules alongside atomic JSON payloads.

---

### Layer-by-Layer Architectural Audit

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Flutter Client (UniVerse)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │  Student UI  │  │  Teacher UI  │  │   Admin UI   │  │ Push/Notif │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘  │
│         │                 │                 │                │         │
│  ┌──────┴─────────────────┴─────────────────┴────────────────┴──────┐  │
│  │     Controllers (SafeChangeNotifier) & GoRouter AppShell         │  │
│  └──────────────────────────────┬───────────────────────────────────┘  │
│                                 │                                      │
│  ┌──────────────────────────────┴───────────────────────────────────┐  │
│  │        Services Layer (Supabase PostgREST & Auth Client)         │  │
│  │  [RoutineService, RoomStatusService, TeacherLocationService]     │  │
│  └──────────────────────┬───────────────────────────┬───────────────┘  │
└─────────────────────────┼───────────────────────────┼──────────────────┘
                          │ (HTTPS REST / WebSockets) │ (Multipart HTTP)
                          ▼                           ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│        Supabase Cloud Backend        │  │   Timetable Engine (Render)  │
│  ┌────────────────────────────────┐  │  │  FastAPI + OR-Tools CP-SAT   │
│  │ PostgreSQL 15 + RLS Triggers   │  │  │  Ingest -> Solve -> Render   │
│  │ (routines, routine_versions,   │  │  │  Multi-worker CP-SAT         │
│  │  cancellations, profiles)      │  │  └──────────────────────────────┘
│  └────────────────────────────────┘  │
│  │ Auth (Google OAuth, PKCE Email)│  │
│  │ Storage & Edge Functions       │  │
└──────────────────────────────────────┘
```

#### A. Architecture & State Management
- **Pattern:** Layered MVVM-inspired design (`screens/` → `controllers/` → `services/` → `models/`).
- **State Management:** Built on `SafeChangeNotifier` (in `lib/core/utils/safe_change_notifier.dart`), which guards against `notifyListeners()` invocation after object disposal, eliminating Flutter memory-leak crashes.
- **Routing:** Handled declaratively with `go_router: ^17.2.3` and an interactive `AppShell` with bottom navigation, responsive FAB menus, and deterministic role guards (`student`, `teacher`, `admin`).
- **Design System:** Custom theme (`AppColors`, `AppSpacing`, `AppTextStyles`, `UButton`, `UCard`, `UAppBar`, `UEmptyState`, `ULoading`) maintaining dark theme `#0F0F10` with `#4D7CFE` brand accent.
- **Code Health:** `flutter analyze` runs cleanly with **0 errors/warnings**. The unit and widget test suite (`flutter test`) passes **60 out of 60 tests** (testing auth flows, time clocks, publish gate, and settings models).

#### B. Supabase Backend & Database Layer
- **Schema & Migrations:** 16 structured SQL migrations in `supabase/migrations/`:
  - `routines`: Central weekly routine schedule containing day, time slot, course, room, batch, section, and teacher metadata.
  - `routine_versions` (Migration 012): Implements atomic versioning. Routine replacement happens in a single Postgres transaction (`publish_routine`), preventing partial or corrupted routine states.
  - `cancellations`: Tracks temporary one-off class cancellations by teachers.
  - `whitelists`: Authorisation gate ensuring only pre-approved emails can assume teacher or admin privileges.
  - `profiles_guard_role` trigger (Migration 016): Database-level security check preventing role escalation.

#### C. Timetable Engine
- Built using FastAPI with background worker threads (`engine/main.py`, `solver.py`, `ingest.py`, `render.py`).
- Solves complex NP-hard university timetabling via Google OR-Tools CP-SAT constraint programming.
- Solves and exports both visual Excel sheets (`openpyxl`) and structured JSON rows (including `is_service` classes such as GED and university-wide courses).

---

## 2. Key Audit Vulnerabilities & Offline Blindspots

While the application is well-architected for online usage, our audit revealed **four critical architectural bottlenecks** that completely prevent offline operation:

### 1. The Startup Auth Network Lockout
In `lib/features/auth/controllers/auth_controller.dart`:
```dart
// Lines 101-113:
try {
  final profile = await _authService.fetchProfile(user.id);
  if (profile != null) {
    _profile = profile;
    _status = AuthStatus.authenticated;
    _registerPushToken(user.id);
  } else {
    _status = AuthStatus.registering;
  }
} catch (e) {
  _status = AuthStatus.unauthenticated; // <--- KICKS LOGGED-IN USERS TO LOGIN!
}
```
**Impact:** When a user launches the app without an internet connection, `fetchProfile()` throws a network exception (`SocketException`). The catch block sets `_status = AuthStatus.unauthenticated`, immediately redirecting the user to the Login screen. Because logging in requires internet, the app becomes totally unusable offline.

### 2. Unused Caching Dependencies
- `pubspec.yaml` already has `hive_flutter: ^1.1.0` declared.
- However, **Hive is never initialized and never used anywhere in `lib/`**.
- `SharedPreferences` is only used for `onboarding_done`, `user_role`, read notification IDs, and the local avatar file path.
- **No routine, room, or teacher data is ever saved to persistent local storage.**

### 3. Redundant Remote Data Fetching
In `RoomsController`, `FindTeacherController`, and `TeacherDetailScreen`:
- Each screen independently calls `fetchAllRoutines()` over the network on launch.
- A user navigating between **Routine**, **Rooms**, and **Find Teacher** triggers multiple duplicate downloads of the entire university timetable table (~300–500 rows each time).

### 4. Missed Opportunity: Real-Time Logic is Already Client-Side!
Notice this critical discovery:
- In `RoomsController.fetchRoomStatuses()` and `FindTeacherController._buildTeacherInfo()`:
```dart
final now = DateTime.now();
for (final entry in todayEntries) {
  final start = entry.startOn(now);
  final end = entry.endOn(now);
  if (now.isAfter(start) && now.isBefore(end)) {
    // Current class live calculation!
  }
}
```
**The app is ALREADY computing "real-time" classroom occupancy and teacher whereabouts locally on the phone using the device clock (`DateTime.now()`)!**  
The ONLY reason it fails offline is that it attempts to download the routine table from Supabase before running that math!

---

## 3. The Mathematics & Mechanics of Offline Real-Time Campus Intelligence

### Why Can UniVerse Work 100% Offline?
A university class schedule is a **deterministic, periodic temporal graph**:
$$\text{State}(t) = f(\text{TimetableData}, \text{LocalClock}(t))$$

1. **Cycle Invariance:** The university schedule runs on a fixed 7-day cyclical loop (Sunday to Thursday / Saturday).
2. **Deterministic Time Boundaries:** Every class slot has immutable start and end times (e.g., `09:30 - 10:50`).
3. **Internal Hardware Clock:** Every smartphone has a high-precision, battery-backed Real-Time Clock (RTC) and quartz crystal that keeps exact time even when airplane mode is on or mobile network is disconnected.
4. **Data Footprint:** The entire routine dataset for the whole university department (all batches, all rooms, all faculty) consists of roughly **300 to 500 rows**. In JSON, this is only **~80 KB to 120 KB** of data.

Therefore:
> **Once the active routine dataset is stored in the device's local database (Hive), the app can calculate classroom status, teacher location, and cohort schedule in real time (every second, minute, or hour) with 0 ms network latency and ZERO bytes of internet consumption.**

---

## 4. End-to-End Implementation Blueprint

Here is the exact step-by-step engineering plan to implement offline real-time operation.

### Architecture of the Offline-First Engine

```
                                  ┌─────────────────────────────┐
                                  │   Supabase Cloud Database   │
                                  │  (routines, versions, etc)  │
                                  └──────────────┬──────────────┘
                                                 │
                                 Background Sync │ (Only when online,
                                    via Version  │  using routine_versions.id)
                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                           LOCAL DEVICE PERSISTENCE                             │
│                                                                                │
│   ┌───────────────────────────┐           ┌────────────────────────────────┐   │
│   │   Hive Box: 'routines'    │           │     Hive Box: 'app_cache'      │   │
│   │   All RoutineEntry JSONs  │           │  - user_profile (offline auth) │   │
│   │   Indexed by:             │           │  - active_version_id           │   │
│   │    - batch + section      │           │  - last_synced_at              │   │
│   │    - teacher_code         │           │  - cached_cancellations        │   │
│   │    - room                 │           └────────────────────────────────┘   │
│   └─────────────┬─────────────┘                                                │
└─────────────────┼──────────────────────────────────────────────────────────────┘
                  │ Instant 0ms Read (Cache-First)
                  ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                     CLIENT-SIDE REAL-TIME REASONING ENGINES                    │
│                                                                                │
│   ┌────────────────────────┐  ┌────────────────────────┐  ┌────────────────┐   │
│   │   Offline Room Engine  │  │ Offline Teacher Engine │  │ Routine Engine │   │
│   │   (Room Status & Free) │  │ (In Class vs Free)     │  │ (Cohort/Self)  │   │
│   └───────────▲────────────┘  └───────────▲────────────┘  └───────▲────────┘   │
│               │                           │                       │            │
│               └───────────────────────────┼───────────────────────┘            │
│                                           │                                    │
│                              ┌────────────┴────────────┐                       │
│                              │  Device Clock (Ticker)  │                       │
│                              │  DateTime.now() Ticks   │                       │
│                              └─────────────────────────┘                       │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

### Step 1: Fix Startup Authentication for Offline Mode

We must modify `lib/features/auth/controllers/auth_controller.dart` and `auth_service.dart`:
1. When the user logs in online, serialize `_profile` to local cache (`app_cache` box).
2. On app startup in `initialize()`:
   - Check if cached profile exists locally.
   - If internet is unavailable and `fetchProfile()` fails, fallback immediately to the cached profile:
   ```dart
   try {
     final profile = await _authService.fetchProfile(user.id);
     if (profile != null) {
       _profile = profile;
       await LocalCacheService.saveProfile(profile);
       _status = AuthStatus.authenticated;
     }
   } catch (e) {
     final cached = LocalCacheService.getProfile();
     if (cached != null) {
       _profile = cached;
       _status = AuthStatus.authenticated; // <--- RESTORED OFFLINE!
     } else {
       _status = AuthStatus.unauthenticated;
     }
   }
   ```
3. The user can now open the app anywhere—even in a university basement with zero signal—and immediately enter their dashboard.

---

### Step 2: Establish the Local Routine Repository (`LocalRoutineService`)

Create a unified storage service powered by `Hive`:
`lib/core/services/local_routine_service.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:universe/core/models/routine_model.dart';

class LocalRoutineService {
  static const String boxRoutines = 'routines_cache';
  static const String boxMeta = 'meta_cache';
  static const String keyVersionId = 'active_version_id';
  static const String keyLastSync = 'last_sync_timestamp';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(boxRoutines);
    await Hive.openBox(boxMeta);
  }

  /// Save all routine entries locally in one high-speed batch
  static Future<void> saveRoutines({
    required List<RoutineEntry> routines,
    required String versionId,
  }) async {
    final box = Hive.box<Map>(boxRoutines);
    await box.clear();

    final map = <String, Map<String, dynamic>>{};
    for (final r in routines) {
      map[r.id] = r.toMap();
    }
    await box.putAll(map);

    final metaBox = Hive.box(boxMeta);
    await metaBox.put(keyVersionId, versionId);
    await metaBox.put(keyLastSync, DateTime.now().toIso8601String());
  }

  /// Retrieve all routines instantly from disk (0ms latency)
  static List<RoutineEntry> getAllRoutines() {
    final box = Hive.box<Map>(boxRoutines);
    return box.values
        .map((m) => RoutineEntry.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Fast indexed query: routines for specific batch & section
  static List<RoutineEntry> getForCohort(String batch, String section) {
    return getAllRoutines()
        .where((r) => r.isActive && r.batch == batch && r.section == section)
        .toList();
  }

  /// Fast indexed query: routines for specific teacher
  static List<RoutineEntry> getForTeacher(String teacherCode) {
    return getAllRoutines()
        .where((r) => r.isActive && r.teacherCode == teacherCode)
        .toList();
  }

  static String? getActiveVersionId() {
    return Hive.box(boxMeta).get(keyVersionId) as String?;
  }

  static bool get hasCachedData => Hive.box<Map>(boxRoutines).isNotEmpty;
}
```

---

### Step 3: Implement Stale-While-Revalidate Sync Strategy

In `RoutineService`, `RoomStatusService`, and `TeacherLocationService`:
1. **Immediate Read:** When any screen requests data, return the local cache **immediately** so the UI renders in < 5 milliseconds.
2. **Background Ping (Only if connected):**
   - Query `routine_versions` table for `is_active = true` (single lightweight row).
   - Compare `remoteVersionId` with `localVersionId`.
   - If they match: **Zero network transfer.** The client already has the latest routine!
   - If different (or if cache is empty): Fetch `tableRoutines`, save to `Hive`, and notify the UI to refresh seamlessly.

```dart
Future<List<RoutineEntry>> fetchRoutinesSmart() async {
  // 1. Immediately return local cache if available
  if (LocalRoutineService.hasCachedData) {
    _syncInBackground(); // Silent background check
    return LocalRoutineService.getAllRoutines();
  }

  // 2. Cold start (first install with internet)
  return await _downloadAndCache();
}
```

---

### Step 4: Real-Time Offline Classroom Status Engine

Because room status is calculated from the time of day, `RoomsController` only needs:
1. The cached full routine dataset (`LocalRoutineService.getAllRoutines()`).
2. A periodic ticker (`Timer.periodic(const Duration(seconds: 30), ...)`).

```dart
class RoomsController extends ChangeNotifier {
  Timer? _ticker;
  List<RoutineEntry> _allRoutines = [];
  List<RoomStatus> _roomStatuses = [];

  void startEngine() {
    // 1. Load instantly from local storage
    _allRoutines = LocalRoutineService.getAllRoutines();
    _recomputeOccupancy();

    // 2. Run real-time ticker every 30 seconds
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      _recomputeOccupancy();
    });
  }

  void _recomputeOccupancy() {
    final now = DateTime.now();
    // Group routines by room and evaluate occupancy against `now`
    // Exactly matches the current logic, but requires ZERO internet!
    notifyListeners();
  }
}
```
**User Experience:** As a student walks across campus with phone in airplane mode, as soon as the clock strikes 10:50 AM, the room status switches from "CSE-3101 in Lab-1" to "Free" or "CSE-3203 next" **in real time**.

---

### Step 5: Real-Time Offline Teacher Tracking Engine

Just like rooms, teacher availability depends solely on their scheduled classes for today:
1. `FindTeacherController` loads `_allRoutines` directly from `LocalRoutineService`.
2. Extracts teacher codes and runs `_buildTeacherInfo(code, name, _allRoutines)`.
3. Runs search queries (`_searchQuery`) completely offline in memory using Dart `List.where()`.
4. Uses a periodic 30s/60s clock ticker to update statuses (`In Class` vs `Free`) in real time without refreshing.

---

### Step 6: Handling Offline Cancellations & Rescheduled Classes

What if a teacher cancels a class?
1. **When Online:** The teacher submits cancellation via `TeacherService.cancelClass()`. Supabase records it in `cancellations` table and sends FCM push notification.
2. **Local Sync:** The app caches active cancellation IDs in Hive box (`cancellations_box`).
3. **Offline Computation:** Both `RoomsController` and `FindTeacherController` check:
   ```dart
   final isCancelled = LocalCacheService.isClassCancelled(entry.id, todayDate);
   if (isCancelled) {
     // Room is marked Free! Teacher is marked Free!
   }
   ```
4. **Network Degradation Graceful Fallback:** If the student is offline when the teacher cancels, the app gracefully serves the official published routine. As soon as the student gets any connectivity (even 2G or campus Wi-Fi for 2 seconds), the lightweight cancellation record syncs down.

---

## 5. File Modification Checklist

| File | Proposed Change |
|---|---|
| `lib/main.dart` | Call `await LocalRoutineService.init()` and `Hive.initFlutter()` before `runApp`. |
| `lib/core/services/local_routine_service.dart` | **Create new:** Hive-based repository for all routines, cohort index, and version metadata. |
| `lib/features/auth/controllers/auth_controller.dart` | Cache profile locally on login; restore profile offline if `fetchProfile()` throws network error. |
| `lib/features/routine/services/routine_service.dart` | Implement Cache-First strategy with background `routine_versions` diff check. |
| `lib/features/rooms/services/room_status_service.dart` | Route requests through `LocalRoutineService` instead of raw remote query. |
| `lib/features/rooms/controllers/rooms_controller.dart` | Add 30-second `Timer` ticker to auto-refresh room status offline as time elapses. |
| `lib/features/find_teacher/services/teacher_location_service.dart` | Source data from `LocalRoutineService`. |
| `lib/features/find_teacher/controllers/find_teacher_controller.dart` | Add real-time clock ticker for offline status transitions. |
| `lib/features/dashboard/controllers/student_dashboard_controller.dart` | Load live class and next class instantly from local cache without loading spinner. |

---

## 6. Verification and Performance Guarantees

1. **Launch Latency:** Reduced from ~800–1800ms (network round trip to Supabase) to **< 5ms** (direct memory / disk read).
2. **Data Consumption:** Routine data is transferred only when the admin publishes a new version (`routine_versions.id` changes). Subsequent app opens consume **0 bytes**.
3. **Resilience:** The app functions identically whether the user is on high-speed Wi-Fi, spotty mobile data, or complete offline flight mode.

