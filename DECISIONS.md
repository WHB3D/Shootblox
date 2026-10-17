# SHOOTBLOX — Decisions Log

> Append-only log of every Level-2/3 decision with one-line rationale.

| Date | Decision | Level | Rationale |
|------|----------|-------|-----------|
| 2026-10-14 | New repo `Shootblox/` separate from Arena Clash | 2 | Pipeline-first requires clean history; Arena Clash is Ali's game with different scope (operatives, abilities, Clash Meter) |
| 2026-10-14 | Evostrike → re-implement (not copy) | 2 | GPL-2.0 incompatible with proprietary publish; Blueprint mandates re-implement |
| 2026-10-14 | Zap for networking (ByteNet fallback) | 2 | Typed remotes, battle-tested, fits Rojo/Wally workflow |
| 2026-10-14 | ProfileStore for data | 2 | Roblox-native, migration support, tested at scale |
| 2026-10-14 | Cosmetics-only monetization | 1 (Blueprint non-negotiable) | PolicyService gate from Day 1; no paid power ever |
| 2026-10-14 | 16-week hard deadline with scope cuts | 2 | Blueprint schedule; Week 16 buffer absorbs one slip |
| 2026-10-14 | 12 weapons, 3 maps, 4 modes | 2 | Blueprint Ch. 9 scope; TTK-banded for balance |
| 2026-10-14 | 9-check validation pipeline | 1 (Blueprint core) | The 70% we deeply own; server-authoritative moat |
| 2026-10-14 | Mobile-native from Week 1 | 1 (Blueprint non-negotiable) | Aim assist, auto-fire, auto-sprint, custom touch HUD |
| 2026-10-14 | Pipeline first (CI before gameplay) | 1 (Blueprint non-negotiable) | No hand-edited live places; one-command publish |
| 2026-10-14 | License hygiene: MIT/Apache-2.0 only | 1 (Blueprint non-negotiable) | GPL = re-implement; no unlicensed copies |
| 2026-10-14 | Roblox FPS Framework via `assets/templates/` | 2 | Limited Use License; arena + weapon models extracted legally |
| 2026-10-14 | Arena Clash → cherry-pick only | 2 | MapService, Config patterns, Net pattern, Round state machine, Bot AI, AdminService |
| 2026-10-14 | Blackout / MonzterDev → study only | 1 | No license / unlicensed; architecture study only |
| 2026-10-17 | `CombatService` validates the timestamp window before the rate limiter | 2 | Found via Gate 4 probe: a stale/replayed timestamp that lands near the last accepted shot's timestamp was misclassified `INVALID_RATE` instead of `INVALID_TIMESTAMP`; timestamp sanity must gate before using that timestamp for rate math |
| 2026-10-17 | `CombatService.SetSimulatedPing` + `PerfMonitor` module, Studio-only | 2 | `Player:GetNetworkPing()` is ~0 in Play Solo and Roblox's Heartbeat `dt` includes physics/replication cost outside our control — Gate 4 ("200ms ping", "Heartbeat ≤ 8ms") needed real overridable/measurable signals, not constant-math unit tests, to actually prove the gate |
| 2026-10-17 | Rebuilt `ViewmodelController` to Blueprint §6.1 spec; dropped the single top-level CFrame lerp | 2 | Lerping `camera.CFrame * offsets` as a whole double-smoothed on top of the offset chain's own springs/ADS-lerp — the exact "gun swims" bug the Blueprint names. All smoothing now lives inside the ordered offset array; the root CFrame assignment itself is never lerped |
| 2026-10-17 | ADS suppressed to 0 during reload (`ViewmodelController.SetReloading`), not just slowed | 2 | Blueprint §6.1.2 trap 1: reload motion must not transfer into ADS wobble. There's no real reload animation yet to counter-animate against, so full suppression is the simplest correct behavior until one exists |
| 2026-10-17 | No literal `AimPart` instance yet; `ViewModelOffset`/`ADS_OFFSET` CFrame constants stand in | 2 | An AimPart only means something welded to real sight geometry on a real weapon mesh; the current weapon is a placeholder box. Building a literal AimPart now would be checkbox theater — revisit when real weapon models land |
| 2026-10-17 | Spread bloom computed client-side only, not re-validated server-side | 2 | `CombatService` already doesn't validate weapon spread server-side (only the 5° direction-vs-claimed-hit angle, a different check) — bloom is cosmetic/feel, same category as recoil/sway; no server change needed or wanted here |
| 2026-10-17 | Equip-time enforced client-side only; empty-vs-tactical reload timing server-side | 2 | Equip-time is pure feel (Ch.6, client cosmetics boundary); reload timing is game state (`Ammo_<id>`, `ReloadingUntil`) that Chapter 5/CombatService already owns — the empty-check reads the same server-truth attribute CombatService's own ammo check uses |
| 2026-10-17 | `SelfTest.probeLagComp` retries past a transient `INVALID_RATE` (up to 3x) before failing | 2 | A genuinely-held real mouse button can fire the same weapon near-simultaneously with the probe's crafted shot; `RateLimiter` rejecting the second as a rate violation is a test-isolation artifact, not a lag-comp bug — don't let it produce a false gate4 FAIL |
| 2026-10-17 | `ReloadingUntil` keyed per-weapon, not per-player; firing cancels a tactical reload, can't cancel an empty one | 2 | Per-player keying meant reloading weapon A blocked firing weapon B after a swap (a real pre-existing bug); per-weapon keying + `CheckAmmo` cancelling only `WasEmpty == false` reloads matches the Ch.6 "tactical vs empty reload" P0 row without a bigger state-machine rewrite |
| 2026-10-17 | Stopped running live `sb-test.sh` Studio sessions when Wahab is at the keyboard | 1 (standing) | Confirmed it force-closes a real Studio window with no save prompt if it steals focus, and real mouse/keyboard input leaking into the automated window produces false test failures (RateLimiter collisions, `INVALID_STATE` from unexpected death/respawn) — only run it when he's confirmed away from the computer |