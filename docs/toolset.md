# Active Toolset — Intent Map

## Project Profile

- **Domain:** Flutter journal/diary app (privacy-first, FOSS, Android primary; iOS/macOS secondary)
- **Tech stack:** Flutter 3.29 / Dart 3.11, Provider + ChangeNotifier (MVVM), ObjectBox, flutter_quill, easy_localization
- **Current phase:** Phase 2 — Foundation

## How to Use This File

1. Identify the task type you are about to perform.
2. Find its row in the Intent Map below.
3. Invoke every skill, sub-agent, and rule listed in that row before doing the work.
4. Always-On rules apply to every task regardless of row.
5. Do not use anything in the Excluded table for this project.
6. At task end, run the code-reviewer sub-agent on the final diff (non-negotiable for non-trivial work).

## Intent Map

| Task Type | Skills / Commands | Sub-Agents | Rules |
|---|---|---|---|
| Implement from plan/spec | `/ce-work` | code-reviewer | 05 |
| Commit staged changes | `/ce-commit` | git-master | 26 |
| Debug a bug | `/ce-debug`, `/debug` | debugger | 06 |
| Write tests | `/testing` | test-engineer | 07 |
| Database/model change (ObjectBox) | `/database` | database-engineer | 16 |
| Security audit (biometric lock, PIN, backups) | `/security` | security-auditor | 09 |
| i18n / translations | `/i18n` | i18n-specialist | 15 |
| Docs update | `/documentation` | docs-writer | 31 |
| Refactor / migration | `/migration` | migration-specialist | 17 |
| Performance optimization | `/performance` | performance-engineer | 10 |
| Commit + push + PR | `/ce-commit-push-pr` | git-master | 26 |

## Always-On Rules

| Rule | Domain | Why always on for this project |
|---|---|---|
| 05 | Code review before merging | Every change gets a code-reviewer pass on the final diff |
| 06 | Bug fix & debugging discipline | Regression tests required for every fix |
| 07 | Testing & QA | Backup/restore and model changes are data-loss hotspots |
| 26 | Git workflow & version control | Conventional commits, clean history, fork hygiene |
| 36 | Anti vibe coding | Prevent slop; keep MVVM/state conventions intact |

## Excluded (not applicable to this project)

| Sub-Agent / Skill | Rationale |
|---|---|
| frontend-designer | Web UI design — Flutter app, skip |
| css-architect | No CSS in a Flutter codebase |
| pwa-engineer | Not a web app |
| seo-specialist | No public website in scope |
| search-optimization | Same — no web presence to optimize |
| playwright-design-clone | No web UI to clone |
| payment-integrator | RevenueCat exists upstream, but the community flavor is FOSS/key-free (F-Droid); payment work is out of scope |
| monorepo-manager | Single repo, no monorepo tooling |
| real-time (realtime-engineer) | No websockets/real-time features |
| email (email-engineer) | No email sending in scope |

## Meta Skills (always included)

`ce-work`, `ce-commit`, `ce-debug`, `ce-plan`, `ce-commit-push-pr`, `ce-handoff`, `lfg`, `caveman`, `ce-explain`, `ce-brainstorm`, `ce-compound`, `ce-code-review`
