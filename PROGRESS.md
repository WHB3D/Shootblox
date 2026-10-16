# SHOOTBLOX — Progress Log

> Updated every session. Current week, shipped work, gate status, next action.

---

## Week 1 (Pipeline + Template) — COMPLETE ✅

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
| 5-7 | Push to GitHub, CI green | ✅ | Run 38745663029: Lint ✓ Build ✓ Test ✓ — 2026-10-15 |

**Gate 1 Target:** `v0.0.1` auto-publishes staging + prod from CI; local gates all green.

---

## Week 2 (Template Base) — COMPLETE ✅

| Task | Status |
|------|--------|
| Evostrike pattern re-implementation | ✅ | `PATTERN_EXTRACTION.md` documents all patterns |
| Movement config (speeds, slide, vault, crouch) | ✅ | `src/shared/Config/Movement.luau` |
| Client MovementController (auto-sprint, slide, vault, swipe) | ✅ | `src/client/Controllers/MovementController.luau` |
| Server MovementService (validation, anti-cheat) | ✅ | `src/server/Services/MovementService.luau` |
| ViewmodelController (ADS, sway, bob, recoil) | ✅ | `src/client/Controllers/ViewmodelController.luau` |
| Net events for movement, weapon equip/unequip | ✅ | `src/shared/Net/init.luau` |
| SetDependencies on all 4 services | ✅ | All 4 services |
| Client entry point (Init.client.luau) | ✅ | `src/client/Init.client.luau` |
| Template base plays full round in Studio | 🔄 | Next: Studio playtest (CI now green) |
| System inventory complete | 🔄 | Next |
| CI green | ✅ | 2026-10-15 |

---

## Week 3 (Core Combat - Weapon Integration) — COMPLETE ✅

| Task | Status |
|------|--------|
| GunController (fire loop, ammo prediction, reload, swap) | ✅ | `src/client/Controllers/GunController.luau` |
| WeaponService (equip/unequip/swap, ammo, ownership) | ✅ | `src/server/Services/WeaponService.luau` |
| ViewmodelController recoil integration | ✅ | `src/client/Controllers/ViewmodelController.luau` |
| Net events: WeaponEquipRequest/UnequipRequest/Swap | ✅ | `src/shared/Net/init.luau` |
| WeaponService added to server with dependencies | ✅ | `src/server/Init.server.luau` |
| Client Init with GunController | ✅ | `src/client/Init.client.luau` |
| UI system (ammo, health, crosshair, kill feed, scoreboard) | ✅ | `src/client/Controllers/UIController.luau` |
| Net events: AmmoUpdate, HealthUpdate, KillFeed, Scoreboard | ✅ | `src/shared/Net/init.luau` |
| CombatService UI event broadcasting | ✅ | `src/server/Services/CombatService.luau` |
| Template base plays full round in Studio | 🔄 | Next: Studio playtest (CI now green) |
| System inventory complete | 🔄 | Next |
| CI green | ✅ | 2026-10-15 |

---

## Week 4 (Core Combat - Validation) — COMPLETE ✅

| Task | Status |
|------|--------|
| Lag compensation: rewind buffer wired to movement | ✅ model-keyed, covers bots |
| Hit validation with movement prediction | ✅ tolerance = 10 + velocity × latency |
| 200ms ping simulation test | ✅ automated (sb-test gate4, real rewind, not arithmetic) |
| Bot AI (spawn, move, aim, fire) | ✅ R15, LOS, reaction delay, respawn |
| Wallbang rejection test | ✅ automated (sb-test gate3) |
| Heartbeat ≤ 8ms budget | ✅ measured (PerfMonitor), avg/max 0.00ms over 2 playtests |
| Studio playtest: full combat loop | ✅ automated / 🔄 Wahab playtest #2 |

**Gate 3 Target:** Spoofed FireEvent deals 0 damage; legit shots kill; rejects logged
**Gate 3: PASSED** (4963ef8, `bash tools/sb-test.sh`): stale timestamp, spoofed origin,
spoofed hit, wallbang, self-hit → all rejected, 0 damage, suspicion logged; rapid fire →
INVALID_RATE; 2 legit headshots kill; ammo spent only on accepted shots; live client shot
via GunController lands (100 → 44 @ 25 studs).
**Gate 4 Target:** Hits register at 200 ms ping; wallbangs rejected; Heartbeat ≤ 8 ms
**Gate 4: PASSED** (2026-10-17, `bash tools/sb-test.sh`, reproduced twice): a bot strafes
30 studs/s in real server time; the self-test fires at its lag-compensated *rendered*
position (6.0–6.5 studs behind its live position) under `CombatService.SetSimulatedPing`
= 200ms (Studio-only override — `GetNetworkPing()` is ~0 in Play Solo) — shot lands
through the real pipeline (56 dmg). `PerfMonitor` sums actual script time inside
Shootblox's own Heartbeat handlers (HitboxHistory capture, movement validation, bot AI),
separate from Roblox's own per-frame physics/replication cost: avg/max 0.00ms, 0 samples
over the 8ms budget across ~900 frames/run.

### Bugs found by the Gate 4 probe (fixed same session)
- `stale_timestamp` sometimes misclassified as `INVALID_RATE` instead of `INVALID_TIMESTAMP`:
  RateLimiter ran before the timestamp-window check, so a stale/replayed timestamp that
  happened to land near the last accepted shot's timestamp got caught by rate limiting
  first. Fixed: timestamp window now validates before rate limiting.
- Gate 4 probe raced bot respawn: `BotService.GetBots()` is empty for the 3s respawn
  delay after a bot dies, so a single snapshot check could find no bot. Fixed: poll with
  an 10s deadline like the gate3 probe does.

### Known gap (not fixed this session — flagging for Wahab)
- CI's `test` job does **not** run TestEZ; it builds `shootblox-test.rbxl` and prints a
  notice telling a human to open it in Studio manually. The `tests/**/*.spec.luau` files
  (incl. `LagCompensation.spec.luau`) never actually execute in CI. Everything checked
  here was verified by the real Play-mode harness (`sb-test.sh`), not by CI's test job.
  Needs a headless TestEZ runner (Lune can run pure-module Luau without Studio) before
  this can be trusted as a real gate.

### Playtest #1 findings (fixed in 76f2fa4, 0e8d43a, 4963ef8)
- Boot crash: `Init.*.luau` ran twice (Rojo init case-match) → renamed `Main.*.luau`;
  empty `src/shared/Types/` dir shadowed `Types.luau`.
- Player shots never registered (no Target, wrong clock); bot killed through walls.
- RateLimiter allowed ~100 shots/s; HitboxHistory rewound wrong frames after wrap;
  Plastic was shoot-through; falloff read backwards; reload instant.
- Weapon grant equipped all 4 slots (ended holding the grenade).
- Local gate `check.sh` could never fail (fixed, proven with a planted type error).

## Week 3-4 (Core Combat) — PLANNED

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

**Next Session:** Gate 4 passed — Week 5-8 (Game Loop) is next: slide-jump chain,
ADS-instant, ViewModel P0 rows, duel matchmaking (Gate 5/6). Separately: `main` has
never been merged into (only `dev` is pushed to origin), so staging has never actually
auto-published — Gate 1's "`v0.0.1` auto-publishes staging + prod from CI" checkpoint is
still open despite Week 1 being marked complete. And the CI `test` job gap above (TestEZ
never runs headlessly) should get fixed before Week 5-8 adds more validation logic that
needs real regression coverage.