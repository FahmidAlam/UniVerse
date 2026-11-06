# UniVerse Project Structure

This document outlines the file and folder architecture of the **UniVerse (universe_v1)** project.

---

## 📂 High-Level Repository Overview

```text
universe_v1/
├── .agents/                 # Agent skills, specialist references, and UI/UX design systems
├── android/                 # Android native runner & Gradle build config
├── assets/                  # Static assets (app icons, foreground graphics)
├── docs/                    # Architecture audits, diagrams, defense PDFs & plans
├── engine/                  # Python-based Timetable Constraint Solver microservice
├── ios/                     # iOS native runner & Xcode workspace
├── lib/                     # Main Flutter application source code
├── linux/                   # Linux desktop platform configuration
├── macos/                   # macOS desktop platform configuration
├── new genarated routine/   # Generated Excel routines (Summer 2025)
├── supabase/                # Supabase Edge Functions, SQL migrations & seed data
├── test/                    # Flutter & Dart unit/integration tests
├── tool/                    # Python automation, verification probes & diagram tools
├── web/                     # Flutter Web runner & configuration
├── workbook/                # Academic distribution profiles & input Excel workbooks
├── analysis_options.yaml    # Dart static analysis configuration
├── pubspec.yaml             # Dart/Flutter package dependencies & asset declarations
└── render.yaml              # Render deployment configuration for the solver engine
```

---

## 📱 Flutter Application Structure (`lib/`)

The application code is organized using a **feature-first** architecture with shared core utilities and UI components:

```text
lib/
├── firebase_options.dart
├── main.dart
│
├── core/                                # Core configurations, models, routing, and theming
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── app_enums.dart
│   ├── models/
│   │   ├── academic_model.dart
│   │   ├── notification_model.dart
│   │   ├── profile_model.dart
│   │   ├── resource_model.dart
│   │   ├── routine_model.dart
│   │   ├── timetable_config_model.dart
│   │   └── whitelist_model.dart
│   ├── platform/                        # Cross-platform web/native file & byte abstractions
│   │   ├── picked_bytes.dart
│   │   ├── picked_bytes_io.dart
│   │   ├── picked_bytes_stub.dart
│   │   ├── picked_bytes_web.dart
│   │   ├── platform_file_save.dart
│   │   ├── platform_file_save_io.dart
│   │   ├── platform_file_save_stub.dart
│   │   └── platform_file_save_web.dart
│   ├── router/
│   │   ├── admin_desktop_shell.dart     # Responsive web/desktop admin shell
│   │   ├── app_router.dart              # GoRouter route declarations
│   │   ├── app_shell.dart               # App shell scaffold with bottom navigation
│   │   └── route_names.dart
│   ├── services/
│   │   └── push_service.dart            # Push notification handling
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_spacing.dart
│   │   ├── app_text_styles.dart
│   │   └── app_theme.dart
│   └── utils/
│       ├── auth_callback_location.dart  # Browser/native auth callback location parser
│       ├── clock_time.dart
│       ├── date_utils.dart
│       ├── extensions.dart
│       ├── room_identity.dart
│       ├── safe_change_notifier.dart
│       └── validators.dart
│
├── features/                            # Modular domain features
│   ├── admin/                           # Campus Admin management & timetable configuration
│   │   ├── controllers/
│   │   │   ├── admin_dashboard_controller.dart
│   │   │   ├── broadcast_controller.dart
│   │   │   ├── course_eligibility_controller.dart
│   │   │   ├── manage_users_controller.dart
│   │   │   ├── resource_admin_controller.dart
│   │   │   ├── routine_admin_controller.dart
│   │   │   ├── routine_upload_controller.dart
│   │   │   ├── timetable_faculty_controller.dart
│   │   │   ├── timetable_gen_controller.dart
│   │   │   ├── timetable_rooms_controller.dart
│   │   │   ├── timetable_settings_controller.dart
│   │   │   └── whitelist_controller.dart
│   │   ├── screens/
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── admin_registration_screen.dart
│   │   │   ├── admin_routine_screen.dart
│   │   │   ├── broadcast_history_screen.dart
│   │   │   ├── campus_broadcast_screen.dart
│   │   │   ├── generate_timetable_screen.dart
│   │   │   ├── manage_course_eligibility_screen.dart
│   │   │   ├── manage_faculty_screen.dart
│   │   │   ├── manage_resources_screen.dart
│   │   │   ├── manage_rooms_screen.dart
│   │   │   ├── manage_users_screen.dart
│   │   │   ├── resource_library_screen.dart
│   │   │   ├── routine_management_screen.dart
│   │   │   ├── timetable_grid_screen.dart
│   │   │   ├── timetable_settings_screen.dart
│   │   │   └── upload_routine_screen.dart
│   │   └── services/
│   │       ├── academic_config_service.dart
│   │       ├── admin_service.dart
│   │       ├── generation_profile.dart
│   │       ├── routine_workbook_parser.dart
│   │       ├── timetable_config_service.dart
│   │       └── timetable_engine_service.dart
│   │
│   ├── auth/                            # Authentication, onboarding & role selection
│   │   ├── controllers/
│   │   │   └── auth_controller.dart
│   │   ├── screens/
│   │   │   ├── auth_callback_screen.dart
│   │   │   ├── email_login_screen.dart
│   │   │   ├── email_signup_screen.dart
│   │   │   ├── faculty_register_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── not_whitelisted_screen.dart
│   │   │   ├── onboarding_screen.dart
│   │   │   ├── placeholder_screen.dart
│   │   │   ├── reset_password_screen.dart
│   │   │   ├── role_selection_screen.dart
│   │   │   ├── splash_screen.dart
│   │   │   ├── student_register_screen.dart
│   │   │   └── verify_email_screen.dart
│   │   ├── services/
│   │   │   └── auth_service.dart
│   │   └── widgets/
│   │       ├── google_sign_in_button.dart
│   │       ├── google_sign_in_button_mobile.dart
│   │       ├── google_sign_in_button_stub.dart
│   │       ├── google_sign_in_button_web.dart
│   │       └── onboard_slide.dart
│   │
│   ├── dashboard/                       # Student dashboard
│   │   ├── controllers/
│   │   │   └── student_dashboard_controller.dart
│   │   └── screens/
│   │       └── student_dashboard_screen.dart
│   │
│   ├── find_teacher/                    # Teacher locator & status lookup
│   │   ├── controllers/
│   │   │   └── find_teacher_controller.dart
│   │   ├── screens/
│   │   │   ├── find_teacher_screen.dart
│   │   │   └── teacher_detail_screen.dart
│   │   ├── services/
│   │   │   └── teacher_location_service.dart
│   │   └── widgets/
│   │       └── teacher_location_card.dart
│   │
│   ├── notifications/                   # Push notifications & broadcast feed
│   │   ├── controllers/
│   │   │   └── notification_controller.dart
│   │   ├── screens/
│   │   │   └── notifications_screen.dart
│   │   └── services/
│   │       └── notification_service.dart
│   │
│   ├── profile/                         # User profile view and settings
│   │   ├── controllers/
│   │   │   └── profile_controller.dart
│   │   ├── screens/
│   │   │   └── profile_screen.dart
│   │   └── services/
│   │       └── profile_service.dart
│   │
│   ├── resources/                       # Academic resource repository
│   │   ├── controllers/
│   │   │   └── resource_controller.dart
│   │   ├── screens/
│   │   │   └── resources_screen.dart
│   │   └── services/
│   │       └── resource_service.dart
│   │
│   ├── rooms/                           # Room vacancy & real-time occupancy
│   │   ├── controllers/
│   │   │   └── rooms_controller.dart
│   │   ├── screens/
│   │   │   ├── room_detail_screen.dart
│   │   │   └── rooms_screen.dart
│   │   ├── services/
│   │   │   └── room_status_service.dart
│   │   └── widgets/
│   │       └── room_status_card.dart
│   │
│   ├── routine/                         # Student routine/schedule viewer
│   │   ├── controllers/
│   │   │   └── routine_controller.dart
│   │   ├── screens/
│   │   │   └── routine_screen.dart
│   │   └── services/
│   │       └── routine_service.dart
│   │
│   └── teacher/                         # Faculty dashboard & class management
│       ├── controllers/
│       │   ├── manage_classes_controller.dart
│       │   └── teacher_dashboard_controller.dart
│       ├── screens/
│       │   ├── manage_classes_screen.dart
│       │   └── teacher_dashboard_screen.dart
│       └── services/
│           └── teacher_service.dart
│
└── shared/                              # Shared reusable widgets and design components
    ├── utils/
    │   ├── nav_utils.dart
    │   └── phosphor_compat.dart
    └── widgets/
        ├── app_bottom_nav.dart
        ├── app_drawer.dart
        ├── chat_bubble.dart
        ├── class_card.dart
        ├── day_selector.dart
        ├── explore_fab_menu.dart
        ├── info_row.dart
        ├── live_class_card.dart
        ├── message_hero_card.dart
        ├── next_class_card.dart
        ├── notification_tile.dart
        ├── quick_action_card.dart
        ├── resource_card.dart
        ├── role_card.dart
        ├── scrollable_empty.dart
        ├── settings_tile.dart
        ├── shell_back_scope.dart
        ├── stat_card.dart
        ├── u_app_bar.dart
        ├── u_avatar.dart
        ├── u_badge.dart
        ├── u_blocking_overlay.dart
        ├── u_bottom_nav.dart
        ├── u_button.dart
        ├── u_card.dart
        ├── u_chip.dart
        ├── u_divider.dart
        ├── u_empty_state.dart
        ├── u_loading.dart
        ├── u_local_avatar.dart
        ├── u_section_header.dart
        ├── u_text_field.dart
        └── weekly_schedule_view.dart
```

---

## ⚙️ Timetable Engine Microservice (`engine/`)

Python service handling constraint satisfaction solving (CP-SAT/OR-Tools) and schedule generation:

```text
engine/
├── fixtures/
│   └── offerings.json                   # Sample course offerings
├── routine generation files/            # Input distribution workbooks
├── templates/
│   └── CSE_Routine_TEMPLATE.xlsx        # Output schedule Excel template
├── tests/                               # Solver validation & regression test suite
│   ├── conftest.py
│   ├── test_cross_semester_acceptance.py
│   ├── test_cse_readiness.py
│   ├── test_distribution_contract.py
│   ├── test_domain.py
│   ├── test_eligibility.py
│   ├── test_fixed_sessions.py
│   ├── test_ingest.py
│   ├── test_lab_allocation_and_tba.py
│   ├── test_legacy_mapping.py
│   ├── test_normalized_domain.py
│   ├── test_real_distribution.py
│   ├── test_render.py
│   ├── test_render_hygiene.py
│   ├── test_same_day.py
│   ├── test_semester_shapes.py
│   └── test_solver.py
├── tools/                               # Engine utility & seeding scripts
│   ├── expand_template.py
│   ├── make_engine_doc.py
│   └── seed_config.py
├── config.json                          # Engine configuration parameters
├── distribution.py                      # Phase 2a immutable Course Distribution source & revision contract
├── domain.py                            # Domain entity definitions
├── ingest.py                            # Excel parsing & validation pipeline
├── legacy_mapping.py                    # Legacy course/faculty code mappings
├── main.py                              # FastAPI/HTTP server entrypoint
├── Procfile                             # Process runner for deployment (Render)
├── render.py                            # Output timetable rendering to Excel
├── requirements.txt                     # Production Python dependencies
├── requirements-dev.txt                 # Development & test dependencies
├── room_policy.py                       # Room assignment & capacity rules
├── runtime.txt                          # Python runtime version
└── solver.py                            # Constraint satisfaction solver (OR-Tools)
```

---

## ⚡ Backend & Database (`supabase/`)

Supabase Postgres schema, migrations, edge functions, and tests:

```text
supabase/
├── functions/                           # Edge functions (Deno / TypeScript)
│   ├── invite-admin/
│   │   └── index.ts                     # Admin invitation & role assignment
│   └── send-push/
│       ├── audience.js
│       ├── audience_cases.js
│       ├── audience_probe.ts
│       ├── audience_test.js
│       ├── index.ts                     # Webhook / notification push dispatch
│       ├── webhook_auth.js
│       └── webhook_auth_test.js
│
├── migrations/                          # Sequential database migrations
│   ├── 001_notification_reads.sql
│   ├── 002_drop_profiles_photo_url.sql
│   ├── 003_routines_teacher_text.sql
│   ├── 004_device_tokens.sql
│   ├── 005_register_device_token.sql
│   ├── 006_enable_rls_all_tables.sql
│   ├── 007_cancellations_schema.sql
│   ├── 008_rls_timetable_config.sql
│   ├── 009_drop_unused_objects.sql
│   ├── 011_timetable_schedule_config.sql
│   ├── 012_routine_versions.sql
│   ├── 013_faculty_course_eligibility.sql
│   ├── 014_publish_routine_safeupdate.sql
│   ├── 015_fixed_sessions_per_week.sql
│   ├── 016_teacher_whitelist_gate.sql
│   ├── 20261022140809_academic_catalog.sql
│   └── 20261106130000_course_distribution_contract.sql
│
├── reconciliation/                      # DB reconciliation & schema verification
│   ├── 001_test_tables.sql
│   ├── 002_test_functions_policies.sql
│   ├── 003_test_dml_grants.sql
│   ├── 004_test_realtime.sql
│   ├── 005_test_storage_policies.sql
│   ├── 20261021214512_reconstructed_baseline.sql
│   ├── export_sanitized_schedule.sql
│   └── storage_realtime_inventory.sql
│
├── seed/                                # Seed datasets
│   ├── seed_demo_accounts.sql
│   ├── seed_notifications.sql
│   ├── seed_resources.sql
│   ├── seed_routine.sql
│   ├── seed_timetable_config.sql
│   └── seed_whitelist.sql
│
└── tests/                               # Database pgTAP tests
    ├── academic_domain.test.sql
    ├── baseline.test.sql
    ├── course_distribution_authorization.test.sql
    ├── course_distribution_contract.test.sql
    ├── reconciliation_stage2.sql
    ├── reconciliation_stage3.sql
    ├── reconciliation_stage4.sql
    ├── reconciliation_stage5.sql
    ├── reconciliation_stage6.sql
    ├── task1_catalog_checks.sql
    └── task1_replay_rehearsal.sql
```

---

## 🧪 Test Suite (`test/`)

Flutter application unit/widget tests and JSON fixtures:

```text
test/
├── fixtures/
│   └── academic_catalog_v1.json
├── academic_model_test.dart
├── academic_service_test.dart
├── admin_web_layout_test.dart
├── auth_callback_location_test.dart
├── clock_time_test.dart
├── generation_profile_test.dart
├── google_sign_in_flow_test.dart
├── publish_gate_test.dart
├── routine_identity_test.dart
├── routine_workbook_parser_test.dart
├── showcase_controller_test.dart
├── showcase_preview_test.dart
├── timetable_settings_test.dart
└── web_admin_navigation_test.dart
```

---

## 🛠️ Utility Scripts & Diagnostics (`tool/`)

```text
tool/
├── tests/                               # Python tool test suite
│   ├── test_build_replay_rehearsal.py
│   ├── test_storage_api_probe.py
│   ├── test_task1_invite_checks.py
│   └── test_task1_local_checks.py
├── activity_diagram.py
├── audit_scheduler_probes.py
├── build_replay_rehearsal.py
├── cross_semester_rehearsal.py
├── defense_pdf_kit.py
├── dfd0.py
├── dfd1.py
├── diagram_helpers.py
├── er_diagram.py
├── generate_app_icon.py
├── generate_corrected_summer_routine.py
├── gen_concepts_pdf.py
├── make_defense_docs.py
├── make_defense_pdf.py
├── make_defense_pptx.py
├── make_locallens_pptx.py
├── make_search_system_pdf.py
├── phase1_browser_reverification.py
├── simulate_solve.py
├── storage_api_probe.py
├── task1_invite_checks.py
├── task1_local_checks.py
├── test_current_solve.py
├── test_new_constraints.py
├── test_solve_with_fall_profile.py
├── test_solve_with_lab_caps.py
├── usecase_diagram.py
├── verify_corrected_workbook.py
└── verify_fall_generated.py
```

---

## 📚 Documentation & Planning (`docs/`)

```text
docs/
├── implementation/                      # Authoritative roadmap & active phase checkpoints
│   ├── UniVerse_Implementation_Master_Plan_v1_1.md
│   ├── 20-browser-admin-foundation.md
│   └── 21-browser-admin-independent-review.md
├── timetable-audit-2026-10-20/          # Committee policy baseline, traceability & audit evidence
│   ├── README.md
│   ├── 02-workbook-and-rules.md
│   ├── 16-committee-traceability-2026-11-04.md
│   ├── 18-committee-decisions-and-policy-baseline-2026-11-04.md
│   └── ... (dated audit records 01–15)
├── archive/                             # Historical audits, handoffs, plans & defense diagrams
│   ├── 2026-10-audits/
│   ├── 2026-11-04/
│   ├── diagrams/
│   └── plans/
├── defense/                             # PDF presentation slides for defense
└── backend-setup.md                     # Supabase schema baseline & verification reference
```

