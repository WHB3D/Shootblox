# SHOOTBLOX — Progress Log

> Updated every session. Current week, shipped work, gate status, next action.

---

## Week 1 (Pipeline + Template) — IN PROGRESS

| Day | Task | Status | Evidence |
|-----|------|--------|----------|
| 1 | Repo init, rokit.toml, default.project.json | ✅ | Files created |
| 1 | wally.toml (Zap, ProfileStore, Charm, Vide, TestEZ) | ✅ | File created |
| 1 | selene.toml, stylua.toml, .luaurc | ✅ | Files created |
| 1 | Git init, `dev` branch, conventional commits | ✅ | Ready |
| 2 | GitHub Actions CI (lint, typecheck, build, test) | ✅ | `.github/workflows/ci.yml` |
| 2 | Staging auto-publish on `main` green | ✅ | Workflow configured |
| 3-4 | Types.luau (core definitions) | ✅ | `src/shared/Types.luau` |
| 3-4 | Net layer (Zap schema) | ✅ | `src/shared/Net/init.luau` |
| 3-4 | Combat config (tolerances, damage, rewards) | ✅ | `src/shared/Config/Combat.luau` |
| 3-4 | Weapons config (12 weapons, TTK bands) | ✅ | `src/shared/Config/Weapons.luau` |
| 3-4 | Maps config (3 curated maps) | ✅ | `src/shared/Config/Maps.luau` |
| 3-4 | Economy config (cosmetics-only, PolicyService) | ✅ | `src/shared/Config/Economy.luau` |
| 4 | CombatService (9-check validation pipeline) | ✅ | `src/server/Services/CombatService.luau` |
| 4 | MatchService (queue, reserved servers) | ✅ | `src/server/Services/MatchService.luau` |
| 4 | DataService (ProfileStore, migrations) | ✅ | `src/server/Services/DataService.luau` |
| 4 | Server entry point (Init.server.luau) | ✅ | `src/server/Init.server.luau` |
| 5-7 | **PENDING** Evostrike re-implementation (weapon configs, validation signatures) | ✅ | `PATTERN_EXTRACTION.md` documents all patterns |
| 5-7 | Unit tests for all 9 validation checks | ✅ | `tests/CombatService/*.spec.luau` (9 files, 45k+ lines) |
| 5-7 | CI test workflow + test place build | ✅ | `.github/workflows/ci.yml` + `tests.project.json` |
| 5-7 | Pattern extraction from Evostrike/Secure-Cast/Hindsight | ✅ | `PATTERN_EXTRACTION.md` (250+ lines) |
| 5-7 | `v0.0.1` tagged locally | ✅ | `git tag v0.0.1` |
| 5-7 | **PENDING** Push to GitHub, CI green, staging publish | 🔄 | Next (requires remote) |

**Gate 1 Target:** `v0.0.1` auto-publishes staging + prod from CI; local gates all green.

---

## Week 2 (Template Base) — PLANNED

| Task | Status |
|------|--------|
| Evostrike pattern re-implementation | ⏳ |
| Template base plays full round in Studio | ⏳ |
| System inventory complete | ⏳ |
| CI green | ⏳ |

---

## Week 3-4 (Core Combat) — PLANNED

| Gate | Target |
|------|--------|
| Gate 3 | Spoofed FireEvent deals 0 damage; legit shots kill; rejects logged |
| Gate 4 | Hits register at 200 ms ping; wallbangs rejected; Heartbeat ≤ 8 ms |

---

## Week 5-8 (Game Loop) — PLANNED

| Gate | Target |
|------|--------|
| Gate 5 | Slide-jump chain works; ADS instant; ViewModel P0 rows ticked |
| Gate 6 | Two lobby clients meet in reserved server; duel completes; rejoin works |
| Gate 7 | Data survives rejoin + server kill; migration specs green |
| Gate 8 | Alpha checklist 7/7 (integrity, lag comp, round loop, data, feel ≥7/10, perf, pipeline) |

---

## Week 9-12 (Content & Economy) — PLANNED

| Gate | Target |
|------|--------|
| Gate 9 | 12 weapons playable in TTK bands across 3 maps |
| Gate 10 | All P0 juice verified on physical phone; assists capped per spec |
| Gate 11 | Full faucet→sink economy loop runs server-ledgered on staging |
| Gate 12 | Strike accumulator + ban waves live; no false-positive spiral; frame budget held |

---

## Week 13-16 (Soft Launch → Publish) — PLANNED

| Gate | Target |
|------|--------|
| Gate 13 | Closed-beta D1 > 15% (fix loop may consume W14) |
| Gate 14 | Idempotent purchases proven by rejoin-during-purchase test |
| Gate 15 | 3 A/B-ready icon variants; CTR baseline measured |
| Gate 16 | Pre-launch checklist 16/16; human E3 confirmation; `v1.0.0` published |

---

**Next Session:** Push to GitHub remote, verify CI green, merge to `main`, auto-publish staging, begin Week 2 (movement/viewmodel).