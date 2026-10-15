# Zombie survival validation — 15 October 2026

Godot 4.7.1, Windows, Compatibility renderer, NVIDIA GeForce RTX 5050. Native editable project; no release archive or executable rebuilt.

## Functional checks

- `tests/survival_validation.gd`: **65 checks** covering initial loadout, map restrictions, safe unseen spawning, dry ground at all station pedestals, connected navigation, health/difficulty caps, damage and duplicate-reward prevention, finite reloads, all power-ups, weapon tiers, mystery-box timing, purchases, repair cancellation, regeneration, rollover recovery, wave transitions, pause, cart destruction and game over.
- `tests/survival_combat_validation.gd`: **15 checks** using actual physics hitscan against animated head/body hitboxes, double head damage, cover blocking bullets, timed melee, blocked melee, real pursuit, relocation identity and all three zombie animation sets.
- `tests/survival_run_validation.gd`: **15 checks** spawning and killing a complete 100-zombie wave while holding the 40-enemy limit, exact score/dinar/lifetime accounting, final-five markers, no spawns between waves, actual driven roadkill and wall-impact damage, remote service of a disabled cart, and a real scene restart with saved records retained.
- `tests/weapon_pose_validation.gd`: **10 checks**, including 12,000 animation/IK updates, unchanged local bone scale, stable arm lengths, all three weapon slots firing and pause focus. Fixture updated for pistol-only survival start.
- `tests/player_safety_validation.gd`: **18 checks** of blocked exits, parked-cart/wall collision, interaction line of sight, separate camera zoom limits, scope/restored avatar, a second vehicle and camera recovery. Fixture explicitly enters a vehicle and grants the sniper before testing those features.

**123 checks passed, zero failures.** Tests run with a separate APPDATA profile so their records do not change the player's records.

The Godot MCP was also used to launch the native project and inspect debug output. No runtime script errors occurred. Model clips were checked in the source glTFs and after Godot import. Skin-weight-derived head centers fixed head/body hitbox overlap discovered by the real hitscan test. A busy-box early-claim bug was found and fixed before final validation.

## Rendered inspection and performance

`tests/survival_capture.gd` rendered gameplay, the navigation-only map with four BOX markers and the game-over screen. These were visually inspected; the survival HUD sits below map/pause overlays, and the map controls remain accessible.

`tests/survival_performance.gd` sampled eight seconds per stage after a two-second warmup in the central-plaza district, with full vegetation, active pursuit, normal Compatibility rendering and VSync disabled. Window 1280×800; configured canvas 1440×900. Results are a local stress sample rather than a whole-park minimum-FPS guarantee.

| Alive zombies | Average FPS | 95th percentile frame time | Static memory |
|---|---:|---:|---:|
| 0 | 297.6 | 7.36 ms | 188.0 MiB |
| 40 | 252.3 | 7.79 ms | 193.2 MiB |
| 80 | 224.9 | 8.16 ms | 198.6 MiB |

Zombies share imported resources, use pooled bodies, staggered navigation, a small-cell tree/separation index, reduced distant animation frequency and at most ten retained corpses. The 1,000-person ambient crowd is not initialized during survival.

## Running the checks

Run the three survival validation scripts using Godot's `--headless --path <project> --script res://tests/<script>.gd` flags. Run the pose/safety checks, capture and performance scripts in the actual renderer (omit `--headless`). Navigation and head-hitbox rebuilding require Python + NumPy; gameplay and tests use the bundled generated data and require no Python runtime.
