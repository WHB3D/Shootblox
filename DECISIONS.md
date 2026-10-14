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