# UniVerse Phase 3 Visual Review & Inspection Gallery

This gallery contains authentic, rendered browser screenshots of all Phase 3 screens captured across **Desktop (1440 × 900)**, **Tablet (920 × 800)**, and **Mobile (390 × 844)** viewports.

---

## 1. How to Manually Run & Inspect the App Locally

You can launch the live Flutter application on your local machine with hot reload:

### Option A: Desktop Chrome Browser (Recommended)
Run this command in your project terminal:
```powershell
flutter run -d chrome
```
*Tip: Resize your browser window or press `F12` to toggle Chrome DevTools device mode (e.g. iPhone 14 Pro `390x844`, iPad Mini `768x1024`, or Desktop `1440x900`) to test the responsive breakpoint transitions in real time!*

### Option B: Local Web Server (Fastest Build Preview)
Since the production web build is already compiled in `build/web`, you can also serve it instantly:
```powershell
python -m http.server 8080 --directory build/web
```
Then open `http://localhost:8080` in your browser.

---

## 2. Phase 3 Rendered Visual Gallery

### A. Startup Splash & Onboarding
| Screen & Viewport | File Path | Highlights & Evidence |
|---|---|---|
| **Splash Screen (Desktop 1440px)** | [`00_splash_desktop_1440.png`](00_splash_desktop_1440.png) | Obsidian Orbit `#0B0C0E` background, custom vector `_OrbitIcon`, high-contrast subtitle, 3 pulsing status dots. |
| **Splash Screen (Mobile 390px)** | [`00_splash_mobile_390.png`](00_splash_mobile_390.png) | Centered vertical mark, responsive font sizing, zero layout shift. |
| **Onboarding — Stage 1 (Desktop 1440px)** | [`01_onboarding_stage1_desktop_1440.png`](01_onboarding_stage1_desktop_1440.png) | Art-directed 58/42 split. Left pane: `01/02/03` pills, convergence cards (Distribution, Faculty, Rooms), `UniVerse Orbit Engine` node, and 4x3 timetable grid preview. Right pane: stage badge `01 / 03 · STAGE 01 · AUTOMATED ENGINE`, narrative, interactive stage pills, and `#FF7A00` primary CTA. |
| **Onboarding — Stage 2 (Desktop 1440px)** | [`01_onboarding_stage2_desktop_1440.png`](01_onboarding_stage2_desktop_1440.png) | Stage 2 narrative with stage-reactive 3D perspective tilt on showcase pane, Stage 02 header badge, outlined back-arrow button next to `Next` CTA. |
| **Onboarding — Stage 3 (Desktop 1440px)** | [`01_onboarding_stage3_desktop_1440.png`](01_onboarding_stage3_desktop_1440.png) | Connected campus showcase, stage 3 indicator, and `#FF7A00` `Get Started` primary CTA. |
| **Onboarding — Stage 1 (Tablet 920px)** | [`01_onboarding_medium_920.png`](01_onboarding_medium_920.png) | Proportional compact 50/50 split adapting naturally without crowding. |
| **Onboarding — Stage 1 (Mobile 390px)** | [`01_onboarding_mobile_390.png`](01_onboarding_mobile_390.png) | Single-column mobile layout. Top bar `01 / 03 · STAGE 01 ...` + Skip, bounded 240px vector showcase, display title, body text, and 52px thumb-friendly `Next` CTA. |

---

### B. Authentication & Role Selection
| Screen & Viewport | File Path | Highlights & Evidence |
|---|---|---|
| **Login Screen (Desktop 1440px)** | [`02_login_desktop_1440.png`](02_login_desktop_1440.png) | 58% showcase on left + 42% bounded card (460px max width). Mini orbit icon, "Welcome back", Google button with high contrast, "Continue with email", and "Create an account". |
| **Login Screen (Tablet 920px)** | [`02_login_medium_920.png`](02_login_medium_920.png) | Centered 50/50 compact split. |
| **Login Screen (Mobile 390px)** | [`02_login_mobile_390.png`](02_login_mobile_390.png) | Focused mobile column with 52px touch-friendly action buttons. |
| **Email Login (Desktop 1440px)** | [`03_email_login_desktop_1440.png`](03_email_login_desktop_1440.png) | Standardized `UTextField` form fields, clean input labels, password visibility toggle, forgot password link. |
| **Email Login (Mobile 390px)** | [`03_email_login_mobile_390.png`](03_email_login_mobile_390.png) | Keyboard-safe scroll container with zero layout overflow. |
| **Email Signup (Desktop 1440px)** | [`04_email_signup_desktop_1440.png`](04_email_signup_desktop_1440.png) | Pre-registration guidance notice, password strength meter, email input validation. |
| **Role Selection (Desktop 1440px)** | [`05_role_selection_desktop_1440.png`](05_role_selection_desktop_1440.png) | Role selection framed strictly as **intent**. Student, Teacher, and Admin role cards with departmental whitelist disclosure. |
| **Role Selection — Governance Modal (Desktop 1440px)** | [`05_role_selection_modal_desktop_1440.png`](05_role_selection_modal_desktop_1440.png) | Centered, top-lit obsidian modal dialog (`maxWidth: 440px`) with `GOVERNANCE & ENGINE` badge, shield icon, close button, and structured access explanation. |
| **Role Selection (Mobile 390px)** | [`05_role_selection_mobile_390.png`](05_role_selection_mobile_390.png) | Full-width thumb-friendly role cards with 8px radius and distinct role accents. |
| **Role Selection — Governance Modal (Mobile 390px)** | [`05_role_selection_modal_mobile_390.png`](05_role_selection_modal_mobile_390.png) | Clean floating modal sheet with subtle drag handle, shield icon, and full-width `Understood` action. |

---

### C. Live Routine & Teaching Lens Previews
| Screen & Viewport | File Path | Highlights & Evidence |
|---|---|---|
| **Student Register — Routine Lens Preview (Desktop 1440px)** | [`06_student_register_lens_preview_desktop.png`](06_student_register_lens_preview_desktop.png) | Live top-lit `UCard` dynamically rendering: `Routine Lens Preview · Batch 58 · Section B` with concise schedule/room linkage and `SECTION SCHEDULE` + `LIVE ALERTS & ROOMS` tags. |
| **Student Register (Mobile 390px)** | [`06_student_register_mobile_390.png`](06_student_register_mobile_390.png) | Mobile vertical layout with live Batch and Section input updates. |
| **Faculty Register (Desktop 1440px)** | [`07_faculty_register_desktop_1440.png`](07_faculty_register_desktop_1440.png) | Live top-lit `UCard` dynamically rendering: `Teaching Lens Preview · JR` explaining the acronym link to published slots and class tools. |
| **Faculty Register (Mobile 390px)** | [`07_faculty_register_mobile_390.png`](07_faculty_register_mobile_390.png) | Mobile vertical layout with department dropdown and teacher code input. |

---

### D. Verification, Recovery & Access Diagnostics
| Screen & Viewport | File Path | Highlights & Evidence |
|---|---|---|
| **Verify Email (Desktop 1440px)** | [`08_verify_email_desktop_1440.png`](08_verify_email_desktop_1440.png) | Pulsing envelope status indicator, 6–8 character OTP input with wide tracking, 60s cooldown resend button, and manual verification check. |
| **Verify Email (Mobile 390px)** | [`08_verify_email_mobile_390.png`](08_verify_email_mobile_390.png) | Non-blocking layout tested under 1.3x text scale and keyboard insets. |
| **Forgot Password (Desktop 1440px)** | [`09_forgot_password_desktop_1440.png`](09_forgot_password_desktop_1440.png) | Single-input password reset email form with 60s cooldown guard. |
| **Reset Password (Desktop 1440px)** | [`10_reset_password_desktop_1440.png`](10_reset_password_desktop_1440.png) | Secure password entry with strength evaluation and confirmation. |
| **Access Required / Not Whitelisted (Desktop 1440px)** | [`11_not_whitelisted_desktop_1440.png`](11_not_whitelisted_desktop_1440.png) | Top-lit `UCard` with amber/red lock icon, clear explanation that admin/teacher roles are server-governed by departmental whitelist, and sign-out path. |
| **Account Unavailable / Auth Error (Desktop 1440px)** | [`12_auth_error_desktop_1440.png`](12_auth_error_desktop_1440.png) | Blue offline cloud icon, calm human-readable error description, retry button, and fallback sign-out. |
