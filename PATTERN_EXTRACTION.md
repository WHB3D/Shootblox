# Evostrike / Secure-Cast / Hindsight — Pattern Extraction Summary

**Purpose:** Document the combat/validation patterns from three reference templates (GPL-2.0 / MIT / MIT) for re-implementation in Shootblox under MIT license. **No code copied** — only architectural patterns and data structures.

---

## 1. Weapon Data Architecture (Evostrike → Shootblox `Weapons.luau`)

### Evostrike Pattern
```lua
-- Weapon type: primary | secondary | ternary
-- Weapon has: Configuration, Assets, Connections, Variables, Animations
-- Configuration includes: inventorySlot, damage, fireRate, spread, range, headMultiplier, etc.
```

### Shootblox Re-implementation (Already Done)
- `WeaponConfig` type with strict fields: `Id`, `Name`, `Slot`, `Damage`, `FireRate`, `Range`, `Spread`, `HeadshotMultiplier`, `DamageDropoff`, `MagSize`, `ReloadTime`, `ProjectileSpeed`, `ProjectileType`, `RecoilPattern`
- 12 weapons in TTK bands (3 ARs, 2 SMGs, 2 Snipers, 1 Shotgun, 2 Pistols, Knife, Frag)
- Damage dropoff as range→multiplier table (not per-meter falloff)

### Key Differences
| Evostrike | Shootblox |
|-----------|-----------|
| String-based slot (`"primary"`) | Enum-like (`"Primary" \| "Secondary" \| ...`) |
| Per-meter falloff | Range-bracket multipliers (simpler, predictable) |
| Head/leg multipliers | Headshot + hit-group multipliers |
| Wallbang material table | Penetration config (separate system) |

---

## 2. Damage Calculation Pipeline (Evostrike `Shared.lua` → Shootblox `CombatService.CheckDamage`)

### Evostrike Pattern (`getDamageFromHumanoidResult`)
```lua
-- 1. Base damage from weaponOptions.damage.base
-- 2. Hit part detection (Head, LowerLeg/Foot, else body)
-- 3. Apply multipliers: headMultiplier, legMultiplier
-- 4. Falloff: if distance > damageFalloffDistance then damage -= (distance - falloffDist) * (falloffPerMeter * calculateFalloff)
-- 5. Clamp to minDamage (damageFalloffMinimumDamage)
-- 6. Wallbang multiplier
-- 7. Round damage
-- 8. Apply via EvoPlayer:TakeDamage (shields, helmets, health)
```

### Shootblox Re-implementation (Already Done)
- 9-check validation pipeline includes `CheckDamage` (Check 5)
- Damage dropoff via bracket table lookup
- Headshot multiplier applied after dropoff
- Min damage percent floor (10%)
- Max damage validation (base × headshot × 1.1 tolerance)

### Patterns Adopted
- ✅ Range-based dropoff with configurable brackets
- ✅ Headshot multiplier on top of dropoff
- ✅ Min damage floor
- ✅ Wallbang as separate multiplier
- ❌ Helmet/shield system (simplified to hit-group multipliers)
- ❌ Per-meter linear falloff (replaced with bracket table)

---

## 3. Wallbang / Penetration Materials (Evostrike `Shared.WallbangMaterials`)

### Evostrike Pattern
```lua
WallbangMaterials = {
    LightMetal = 0.7,
    HeavyMetal = 0.4,
    LightWood = 0.85,
    HeavyWood = 0.5,
    Ignore = 1, -- no penetration
}
-- Applied via resultData.wallbangDmgMult in getDamageFromHumanoidResult
```

### Shootblox Equivalent (Future: Penetration System)
- Will use Hindsight/Secure-Cast penetration config
- `surfaceHardness` per material (Wood=2, Concrete=10, Default=10)
- Power budget spent against hardness
- Ricochet at angle threshold

---

## 4. Lag Compensation / Rollback (Secure-Cast + Hindsight)

### Secure-Cast Pattern
```lua
-- Snapshot system: RunService.PostSimulation:Connect(CreatePlayersSnapshot)
-- Voxel broadphase: 32-stud cells, 4096x512x4096 grid
-- Character hitboxes: R6 (6 parts) / R15 (13 parts) with half-extents
-- Simulation: Dispatcher with 16 threads, 0.048s interpolation
-- ServerFrameRate = 1/60, RemainingFrameTimeRatio = 0.5
```

### Hindsight Pattern
```lua
-- World factory: createWorld({ actorContainer, definitionsModule, ... })
-- RollbackConfig: lifetime, voxelSize, gridCenter, gridSize, hitboxSize, rigs
-- PenetrationConfig: surfaceHardness, defaultHardness, ricochetHardness
-- ProjectileDefinition: velocity, gravity, lifetime, power, angle, loss, range, collaterals, filter
-- CastOptions: caster, type, origin, direction, timestamp, visual, modifier
-- CharacterPose: rig, rootPosition, parts[], player
-- Rollback: capture(poses), queryRay(origin, direction, filter?)
```

### Shootblox Re-implementation (Already Done in `CombatService.CheckTarget`)
- PositionHistory buffer (10 ticks = 200ms at 50Hz)
- ServerTick from client matched to closest history entry
- Target drift tolerance: 6 studs
- Headshot detection: hit within 3 studs of rewound head
- No voxel broadphase yet (simple linear history lookup)

### Patterns to Adopt (Week 3-4)
- Voxel broadphase for O(1) character lookup
- Parallel-safe `Filter` predicate (Hindsight pattern)
- Snapshot lifetime ~1 second
- R15/R6 rig definitions with half-extents

---

## 5. Shot Validation Pipeline (Hindsight `ProjectileDefinition` → Shootblox 9-Check)

### Hindsight ProjectileDefinition Fields
```lua
velocity, gravity, lifetime, power, angle, loss, range, collaterals, raycastFilter, filter, onImpact, onIntersection, onDestroyed
```

### Shootblox 9-Check Mapping
| Hindsight Concept | Shootblox Check |
|-------------------|-----------------|
| `filter` (parallel-safe) | Check 1: Origin, Check 3: Angle, Check 4: Target |
| `range` + `velocity` | Check 7: Range |
| `power` + `surfaceHardness` | Check 8: LOS (penetration) |
| `onIntersection` callback | Check 4: Target → ApplyDamage |
| Timestamp + rollback | Check 4: Target (rewind) |
| Caster identity | Check 1: Origin |

### Shootblox 9-Check Pipeline (Already Implemented)
1. **Origin** — drift ≤12 studs from head
2. **Fire Rate** — server-enforced cooldown with jitter window
3. **Angle** — deviation ≤4° from head look vector
4. **Target** — rewind to server tick, drift ≤6 studs, headshot flag
5. **Damage** — bracket dropoff + headshot multiplier, max validation
6. **Ammo** — server-authoritative decrement
7. **Range** — weapon range + 10 stud tolerance
8. **LOS** — raycast, penetrable materials (glass/plastic), block on solid
9. **Cooldown** — max 3 shots/tick global

---

## 6. Network Architecture (Evostrike + Secure-Cast + Hindsight)

### Evostrike
- RemoteEvent/RemoteFunction for weapon add/remove
- Replicate event for bullet/hole replication
- Client fires server for weapon actions

### Secure-Cast
- `SecureCast.Cast(caster, type, origin, direction, timestamp, pvInstance, modifier)`
- Dispatcher with actor pool (16 threads)
- Server: PostSimulation snapshot capture
- Client: visual replication via `visualsContainer`

### Hindsight
- `World:cast({ caster, type, origin, direction, timestamp, visual, modifier })`
- Parallel simulation actors
- Rollback snapshots via `Rollback:capture(poses)`
- `queryRay` for manual raycasts with filter

### Shootblox (Already Done)
- Zap typed remotes: `ClientToServer.Fire`, `Reload`, `SwapWeapon`, `VoteMap`, `QueueJoin`, `AdminCommand`
- Server validates all 9 checks on `ClientToServer.Fire`
- `HitConfirm`, `KillFeed`, `Error` responses
- Timestamp + ServerTick from client for rewind

---

## 7. Player Data / Economy (Evostrike → Shootblox `Economy.luau` + `DataService`)

### Evostrike
- PlayerData module with paths (pstats.kills, deaths)
- Weapon contracts, skins, daily/weekly tasks
- Shield/helmet attributes

### Shootblox (Already Done)
- ProfileStore with migrations
- Coins/Keys/XP/Level/RankedRating
- Weapon contracts (5 milestones per weapon)
- Daily/weekly tasks with idempotency keys
- Strike system with 1-week decay, auto-ban at 3

---

## 8. License Compliance Strategy

| Template | License | Shootblox Approach |
|----------|---------|-------------------|
| Evostrike | GPL-2.0 | **Reference only** — patterns extracted, re-implemented in MIT |
| Secure-Cast | MIT | **Study + adapt** — voxel/rollback concepts, rewrite from scratch |
| Hindsight | MIT | **Study + adapt** — rollback/definition patterns, rewrite from scratch |
| FastCast2, Zap, ProfileStore, etc. | MIT/Apache-2.0 | **Use directly** via Wally |

### Files in Shootblox That Are Original MIT Re-implementations
- `src/shared/Config/Combat.luau` — tolerances, damage types, hit multipliers
- `src/shared/Config/Weapons.luau` — 12 weapon configs, bracket dropoff
- `src/shared/Config/Maps.luau` — 3 map specs with spawns/cover
- `src/shared/Config/Economy.luau` — cosmetics-only, PolicyService-gated
- `src/server/Services/CombatService.luau` — 9-check validation pipeline
- `src/server/Services/MatchService.luau` — queue, reserved servers, map voting
- `src/server/Services/DataService.luau` — ProfileStore, migrations, strikes
- `tests/CombatService/*.spec.luau` — 9 validation test suites

---

## 9. Remaining Week 1 Work (Before v0.0.1)

### Evostrike Pattern Extraction → DONE
- [x] Weapon data structure
- [x] Damage calc with dropoff/headshot
- [x] Wallbang materials concept
- [x] Player damage flow (simplified)

### Secure-Cast / Hindsight Pattern Extraction → DONE
- [x] Snapshot/rollback architecture
- [x] Voxel broadphase design
- [x] Character hitbox definitions (R6/R15)
- [x] Penetration/ricochet config
- [x] Projectile definition + modifier pattern
- [x] Parallel-safe filter predicate

### Next: Push & Tag v0.0.1
```bash
git push origin dev
# Open PR → CI green → merge to main → auto-tag v0.0.1 → staging publish
```

---

## 10. Week 2 Preview (Template Base)

| Task | Source Pattern |
|------|----------------|
| Movement controller | Evostrike EvoPlayer movement + Hindsight character pose |
| Viewmodel system | Evostrike Viewmodel module |
| ADS / slide-jump | Evostrike movement tech (melee dash, double jump) |
| Bot AI | Evostrike BotServiceModule (simplified) |
| Lobby + map vote | Arena Clash MapService (already built) |

---

*This document captures the "70% template" patterns per Blueprint Ch.4. The remaining 30% (shot validation, juice, mobile controls) is Shootblox-original.*