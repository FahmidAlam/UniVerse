# Global Flutter & Dart Skills Installation Report

> **Role:** Developer Tooling & Agent-Skills Installation Engineer  
> **Environment:** Windows 11, PowerShell 5.1, Node.js v26.13.0, npm/npx 11.20.0  
> **CLI Tool:** Official `npx skills` CLI (v1.4.11)  
> **Scope:** User-Level Global (`--global`), Copied (`--copy`)  
> **Date:** 2026-11-07  

---

## 1. Executive Summary

All eight selected official Flutter and Dart agent skills have been successfully installed globally via `npx skills` with zero collisions, zero overwrites, and zero modifications to any repository source code, dependencies, or configuration.

- **Flutter Skills (5):** Installed from `flutter/agent-plugins`
- **Dart Skills (3):** Installed from `dart-lang/skills`
- **Target Agents:** Antigravity, Codex, and Claude Code (detected and configured)
- **UniVerse Project Integrity:** All six project-specific skills in `universe_v1/.agents/skills/` remain untouched and retain complete priority.

---

## 2. Pre-Installation Collision Audit Results

Before initiating any installations, a comprehensive collision audit was performed:

| Check | Target / Scope | Result | Details |
|---|---|---|---|
| **CLI Verification** | `npx skills --help`, `add --help` | **PASS** | Validated flags: `--global`, `--skill`, `--agent`, `--copy`, `--yes`. |
| **Existing Global Skills** | `npx skills ls -g` | **PASS** | Only `codex-research` was installed globally. |
| **GitHub Source Validation** | `flutter/agent-plugins`, `dart-lang/skills` | **PASS** | Both repositories queried; all 8 requested skill names confirmed present. |
| **Project-Level Collision Check** | `universe_v1/.agents/skills/` | **PASS** | No exact-name overlap with the 6 UniVerse-specific skills (`universe-ux-principles`, `universe-visual-design-system`, `flutter-web-responsive-ui`, `flutter-interaction-motion`, `accessibility-performance`, `visual-ui-qa`). |
| **Global Path Collision Check** | `~\.agents\skills\`, `~\.claude\skills\` | **PASS** | None of the 8 skill directories existed in either global directory prior to installation. |

---

## 3. Installed Skills & Source Repositories

### A. Flutter Skills (`flutter/agent-plugins`)

1. **`flutter-build-responsive-layout`**
   - *Description:* Use `LayoutBuilder`, `MediaQuery`, or `Expanded/Flexible` to create adaptive layouts for both mobile and tablet/desktop form factors.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).
2. **`flutter-fix-layout-issues`**
   - *Description:* Diagnose and resolve Flutter layout errors (RenderFlex overflow, unbounded height/width constraints) using Dart and Flutter MCP tools.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).
3. **`flutter-add-widget-test`**
   - *Description:* Implement component-level tests using `WidgetTester` to verify UI rendering and user interactions.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).
4. **`flutter-add-widget-preview`**
   - *Description:* Add interactive widget previews to the project using the `previews.dart` system.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).
5. **`flutter-add-integration-test`**
   - *Description:* Configure Flutter Driver for app interaction and convert MCP actions into permanent integration tests using `integration_test`.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).

### B. Dart Skills (`dart-lang/skills`)

1. **`dart-run-static-analysis`**
   - *Description:* Execute `dart analyze` to identify warnings and errors, and use `dart fix --apply` to automatically resolve mechanical lint issues.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).
2. **`dart-add-unit-test`**
   - *Description:* Write and organize unit tests for functions, methods, and classes using `package:test`.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).
3. **`dart-collect-coverage`**
   - *Description:* Collect test coverage using `package:coverage` and generate an LCOV report.
   - *Security Risk Assessment:* Gen Safe, 0 alerts (Socket), Low Risk (Snyk).

---

## 4. Global Installation Paths & Agent Discoverability

The `npx skills` CLI automatically resolved canonical global destinations and copied the skills across all target agents on Windows:

| Skill | Canonical Store (Codex & Antigravity) | Claude Code Destination |
|---|---|---|
| `flutter-build-responsive-layout` | `C:\Users\fahmi\.agents\skills\flutter-build-responsive-layout\` | `C:\Users\fahmi\.claude\skills\flutter-build-responsive-layout\` |
| `flutter-fix-layout-issues` | `C:\Users\fahmi\.agents\skills\flutter-fix-layout-issues\` | `C:\Users\fahmi\.claude\skills\flutter-fix-layout-issues\` |
| `flutter-add-widget-test` | `C:\Users\fahmi\.agents\skills\flutter-add-widget-test\` | `C:\Users\fahmi\.claude\skills\flutter-add-widget-test\` |
| `flutter-add-widget-preview` | `C:\Users\fahmi\.agents\skills\flutter-add-widget-preview\` | `C:\Users\fahmi\.claude\skills\flutter-add-widget-preview\` |
| `flutter-add-integration-test` | `C:\Users\fahmi\.agents\skills\flutter-add-integration-test\` | `C:\Users\fahmi\.claude\skills\flutter-add-integration-test\` |
| `dart-run-static-analysis` | `C:\Users\fahmi\.agents\skills\dart-run-static-analysis\` | `C:\Users\fahmi\.claude\skills\dart-run-static-analysis\` |
| `dart-add-unit-test` | `C:\Users\fahmi\.agents\skills\dart-add-unit-test\` | `C:\Users\fahmi\.claude\skills\dart-add-unit-test\` |
| `dart-collect-coverage` | `C:\Users\fahmi\.agents\skills\dart-collect-coverage\` | `C:\Users\fahmi\.claude\skills\dart-collect-coverage\` |

### How Agents Discover These Skills

- **Codex (Terra & Sol):** Reads directly from `%USERPROFILE%\.agents\skills\`. All 8 skills are present with intact `SKILL.md` files.
- **Claude Code:** Reads from `%USERPROFILE%\.claude\skills\`. All 8 skills were copied directly into this directory.
- **Antigravity:**
  - `npx skills` associates `~\.agents\skills\` with Antigravity and Antigravity CLI.
  - In addition, Antigravity has the official `flutter` plugin mounted in `%USERPROFILE%\.gemini\config\plugins\flutter\skills\`, ensuring full native availability across both plugin and CLI-managed discovery routes.

---

## 5. Post-Installation Verification Evidence

### 1. `npx skills ls -g` Output
```text
Global Skills

codex-research                  ~\.agents\skills\codex-research                 
  Agents: Antigravity, Antigravity CLI, Codex, Cursor, Gemini CLI +1 more  Source: untracked
dart-add-unit-test              ~\.agents\skills\dart-add-unit-test             
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: dart-lang/skills
dart-collect-coverage           ~\.agents\skills\dart-collect-coverage          
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: dart-lang/skills
dart-run-static-analysis        ~\.agents\skills\dart-run-static-analysis       
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: dart-lang/skills
flutter-add-integration-test    ~\.agents\skills\flutter-add-integration-test   
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: flutter/agent-plugins
flutter-add-widget-preview      ~\.agents\skills\flutter-add-widget-preview     
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: flutter/agent-plugins
flutter-add-widget-test         ~\.agents\skills\flutter-add-widget-test        
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: flutter/agent-plugins
flutter-build-responsive-layout ~\.agents\skills\flutter-build-responsive-layout
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: flutter/agent-plugins
flutter-fix-layout-issues       ~\.agents\skills\flutter-fix-layout-issues      
  Agents: Antigravity, Antigravity CLI, Claude Code, Codex, Cursor +2 more  Source: flutter/agent-plugins
```

### 2. Disk & Content Validation
All 16 destination files (8 in `~\.agents\skills\`, 8 in `~\.claude\skills\`) were verified on disk with non-zero byte lengths and valid YAML frontmatter:
- `flutter-build-responsive-layout/SKILL.md`: 6,944 bytes (Readable)
- `flutter-fix-layout-issues/SKILL.md`: 5,456 bytes (Readable)
- `flutter-add-widget-test/SKILL.md`: 6,535 bytes (Readable)
- `flutter-add-widget-preview/SKILL.md`: 8,179 bytes (Readable)
- `flutter-add-integration-test/SKILL.md`: 7,505 bytes (Readable)
- `dart-run-static-analysis/SKILL.md`: 5,137 bytes (Readable)
- `dart-add-unit-test/SKILL.md`: 4,831 bytes (Readable)
- `dart-collect-coverage/SKILL.md`: 5,034 bytes (Readable)

### 3. UniVerse Project Integrity Confirmation
The six UniVerse project-specific skills in `universe_v1/.agents/skills/` remain unmodified:
- `universe-ux-principles/SKILL.md`: 5,751 bytes (Unchanged)
- `universe-visual-design-system/SKILL.md`: 5,212 bytes (Unchanged)
- `flutter-web-responsive-ui/SKILL.md`: 4,483 bytes (Unchanged)
- `flutter-interaction-motion/SKILL.md`: 3,568 bytes (Unchanged)
- `accessibility-performance/SKILL.md`: 3,603 bytes (Unchanged)
- `visual-ui-qa/SKILL.md`: 4,392 bytes (Unchanged)

`git status` confirms zero changes to application code, dependencies (`pubspec.yaml`), or tests.

---

## 6. Skill Coexistence & Precedence Model

The established instruction priority across projects is:

```text
Priority 1: Project's explicit architecture, security, and permanent constraints (AGENTS.md / CLAUDE.md)
    ▼
Priority 2: Project's domain-specific skills (e.g., UniVerse UI/UX & CP-SAT scheduling skills)
    ▼
Priority 3: Global engineering skills (Flutter & Dart layout, analysis, testing, coverage)
    ▼
Priority 4: General agent baseline defaults
```

### UniVerse Safeguards
- Generic responsive skills (`flutter-build-responsive-layout`) provide layout implementation techniques (`LayoutBuilder`, `MediaQuery`), but `flutter-web-responsive-ui` and `universe-visual-design-system` govern UniVerse's specific breakpoints (1440, 1280, 1024, 768, 390 px), desktop-first web layout, dark/orange palette, and mandatory approval gate.
- Testing skills (`flutter-add-widget-test`, `dart-add-unit-test`) provide test authoring patterns, but the project's testing boundaries (e.g. not re-running passed suites, least-privilege RLS checks, and offline Python solver verification) remain authoritative.

---

## 7. Restart & Discovery Refresh Guidance

- **Antigravity:** If an Antigravity IDE window or daemon was running during installation, reload the window (`Ctrl+Shift+P` → *Developer: Reload Window*) or start a new conversation turn to refresh the global skills index.
- **Codex (Terra & Sol):** Codex reads `%USERPROFILE%\.agents\skills\` dynamically on new task execution. Starting a new session automatically discovers the new skills.
- **Claude Code:** Claude Code reads `%USERPROFILE%\.claude\skills\` on startup. Starting a fresh `claude` session in any project terminal will immediately recognize all 8 installed skills.
