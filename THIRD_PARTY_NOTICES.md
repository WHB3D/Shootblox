# SHOOTBLOX — Third-Party Notices

> One line per dependency, updated the day it's added. All are MIT/Apache-2.0 compatible.

## Wally packages (`wally.toml`)

| Dependency | Version | License | Source | Purpose |
|------------|---------|---------|--------|---------|
| Charm | 0.11.1 | MIT | littensy/charm | Atomic state management |
| Vide | 0.4.1 | MIT | centau/vide | Declarative UI |
| Signal | 2.0.3 | MIT | sleitnick/signal | Typed events |
| Trove | 1.8.0 | MIT | sleitnick/trove | Connection cleanup |
| TestEZ (dev) | 0.4.1 | MIT | roblox/testez | Unit testing |

## Vendored (`src/shared/Vendor/`)

| Dependency | License | Source | Purpose |
|------------|---------|--------|---------|
| ProfileStore | Apache-2.0 | MadStudioRoblox/ProfileStore | Session-locked DataStore persistence (LICENSE file alongside) |

## Toolchain (`rokit.toml`, not shipped in the game)

rojo 7.7.1 · wally 0.3.2 · selene 0.31.0 · stylua 2.3.1 · luau-lsp 1.53.0 · lune 0.10.4 · rbxcloud 0.17.0

## Reference-only (no code copied — see DECISIONS.md)

Evostrike (GPL-2.0), Secure-Cast (MIT), Hindsight (MIT) — architecture patterns documented in `PATTERN_EXTRACTION.md`; all Shootblox code is an original re-implementation.
