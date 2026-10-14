# Shootblox

A competitive, mobile-native, round-based duel FPS on Roblox — Rivals-tier, built in 16 weeks.

## Overview

- **Genre:** Round-based FPS duel (1v1–5v5, first-to-5)
- **Platform:** Roblox (PC, Mobile, Console)
- **Architecture:** Server-authoritative, lag-compensated, mobile-native
- **Monetization:** Cosmetics-only, PolicyService-gated
- **Pipeline:** CI/CD auto-publish, one-command deploy

## Quick Start

```bash
# Install toolchain (via rokit)
rokit install

# Install dependencies
wally install

# Typecheck & lint
stylua --check src/
selene src/
rojo sourcemap -o sourcemap.json
luau-lsp analyze --sourcemap sourcemap.json --definitions types/globalTypes.d.lua src/

# Build
rojo build -o shootblox.rbxl

# Run tests
lune run tests/run.luau
```

## Project Structure

```
src/
├── server/
│   ├── Init.server.luau          # Server entry point
│   └── Services/
│       ├── CombatService.luau    # 9-check validation pipeline
│       ├── MatchService.luau     # Queue, matchmaking, reserved servers
│       └── DataService.luau      # ProfileStore persistence
├── shared/
│   ├── Types.luau                # Core type definitions
│   ├── Net/                      # Zap typed remotes
│   └── Config/
│       ├── Combat.luau           # Tolerances, damage, rewards
│       ├── Weapons.luau          # 12 weapons, TTK-banded
│       ├── Maps.luau             # 3 curated maps
│       └── Economy.luau          # Cosmetics-only, PolicyService
└── client/                       # Controllers, UI (to be built)
```

## Key Systems

### 9-Check Validation Pipeline (CombatService)
1. Origin drift ≤ 12 studs
2. Fire rate enforced server-side
3. Angle deviation ≤ 4°
4. Target position validated via rewind buffer (200ms)
5. Damage matches weapon config at range
6. Server-authoritative ammo tracking
7. Range ≤ weapon max + tolerance
8. Line-of-sight raycast from validated origin
9. Global shot throttling (3/tick)

### Matchmaking (MatchService)
- Modes: 1v1, 2v2, 5v5, FFA
- Reserved server teleport
- Map voting + ban phase (ranked)
- Region-locked queues

### Data (DataService)
- ProfileStore with migrations
- Cosmetics-only economy (Coins, Keys, Glory)
- Daily/weekly tasks, weapon contracts
- Strike-based anti-cheat with decay

## Roadmap

See [SHOOTBLOX_ROADMAP.md](2- Mission to Build it/SHOOTBLOX_ROADMAP.md) for 16-week execution plan.

## License

Proprietary. All code MIT-licensed unless noted. Third-party notices in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).