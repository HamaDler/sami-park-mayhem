# Latest validation - imported Quaternius weapons - 2026-10-12

Replaced all three procedural weapon placeholders with the user's Pistol, Assault Rifle and Sniper Rifle GLBs. Original files and materials are preserved under CC0; source and bundled SHA-256 hashes match for all three.

- Godot 4.7.1 headless editor import succeeds for all three assets. Models are self-contained, static GLBs with original materials. The three source meshes total 8,130 vertices; resources are shared between avatar instances.
- Editable wrappers `scenes/weapons/pistol.tscn`, `rifle.tscn`, `sniper.tscn` apply a 0.16 scale and rotate the exported +X barrels toward game -Z. Per-model height corrections align the barrel centers. Right/left grip and muzzle markers are separate from source geometry. Muzzle markers sit approximately 8 mm beyond the measured barrel tips.
- A direct runtime probe confirms each equipped Model is the correct imported GLB. Both wrist-to-grip distances stay below 4 mm across all three weapons at pitch -0.8, -0.18, 0 and 0.65 radians. Right-hand maximum is below 0.03 mm; the largest left-hand distance is 3.58 mm at the sniper's downward aiming limit.
- Actual renderer captures of all three equipped guns and the sniper scope were inspected. Original colors, barrel directions, scale and hand placement are visible in the game. The driver and walking character remain the supplied Hoodie model.
- `tests/player_validation.gd`: 34/34, covering switching, actual hitscan firing, reload, automatic rifle, sniper scope, pause/map travel and entering/exiting vehicles. `tests/weapon_pose_validation.gd`: 10/10 with 12,000 animation/weapon updates; maximum local bone scale change remains 0.0. Combined: 44 checks, zero failures.
- Existing pistol/rifle/sniper aim-sensitivity multipliers remain 0.70/0.55/0.20. Magazines, firing rates, recoil and controls remain configured in `data/weapon_settings.json`.
- No release ZIP updated.

# Previous validation - weapon-hand mesh distortion fix - 2026-10-12

Reproduced the reported distorted graphics after leaving the cart, switching weapons and repeatedly firing. The hand IK was writing complete global bone transforms every frame. Transform decomposition progressively changed local bone scales and arm lengths, stretching the skinned mesh. The correction writes normalized local bone rotations only; seated foot adjustment writes position only. Source model and animation scales remain intact.

- Before/after rendered reproduction: 950 physics frames, 317 actual shots, rotating/moving character, vertical aiming and repeated weapon changes. Largest bone basis scale grew to **1.74134** before the fix; after the fix it stayed at **1.00000048**. Tracer width remained normal in both runs, identifying the character skin rather than bullet effects as the source.
- `tests/weapon_pose_validation.gd`: **10/10**. Accelerates 12,000 real animation/IK updates (200 seconds of animation time) through all weapon slots, idle/run/strafe/backward/airborne poses, character turns, recoil and vertical aiming. Maximum local bone scale change is **0.0**; maximum arm segment length deviation is **0.00005464 m**. Also checks valid transforms, original weapon scale, firing all three weapons afterward, and pause-menu focus.
- `tests/player_validation.gd`: **34/34** after the fix, including both seated hands on the steering wheel and feet above the floor, movement/jump, weapon firing/reload/scope, pause/map travel, recovery and second-vehicle interaction. Combined: **44 relevant checks, zero failures**.
- Actual rendered character view after the accelerated stress test was inspected. The arms and hands stay at normal size, and the UI remains readable. No source GLB changes or release ZIP updates.

Run the new test with `--path <project> --script res://tests/weapon_pose_validation.gd` in a rendered Godot instance. Bone rotation API reference: https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html#class-skeleton3d-method-set-bone-pose-rotation

# Previous validation - Hoodie character, walking, vehicles and weapons - 2026-10-12

Godot 4.7.1, Windows, Compatibility renderer, NVIDIA GeForce RTX 5050.

- `tests/player_validation.gd`: 34/34 in the actual renderer. Checks the supplied rigged GLB, driver hips/feet and both hands at the steering wheel; F exit/entry, grounded exits, mouse capture, contextual HUD/minimap, walking and jumping, parked cart behavior, interaction range, all three weapon slots, semi/automatic firing, damage receiver hits, reload/cooldown, sniper FOV, paused input, active-actor map travel, nearby tree collision streaming, water/world recovery, preserved loadout, and entering a second vehicle instance.
- `tests/player_safety_validation.gd`: 18/18 in the actual renderer. Covers fallback to the right exit, refusing fully blocked exits, wall and parked-cart collisions, line-of-sight vehicle interaction, separate camera zoom limits and distance persistence, unobstructed scoped camera and restored avatar, preserved zoom after scope, and recovery/camera behavior on a second vehicle.
- Existing regression tests: `tests/integration.gd` 36/36, `tests/game_ui_validation.gd` 24/24, and `tests/map_navigation.gd` 32/32. Combined: **144 checks, zero failures**. UI geometry remains valid at 1280x800, 1920x1080 and 3440x1440.
- `tests/player_capture.gd` rendered the seated driver, on-foot chase view, three equipped weapons, sniper scope, jumping, and updated pause controls. These views were visually inspected; the magazine readouts show integer capacities, and the sniper camera hides the local avatar to avoid blocking its scope.
- The supplied character has 24 animation clips. Idle/gun and walking/running/strafe clips are reused. There is no supplied jump animation; the airborne pose is an approximation. Seated pose and weapon grips are applied separately, preserving the source GLB.
- Weapon meshes are original procedural placeholders. Ammo reserve is unlimited. There are no enemies or destructible scenery; collision hits call an optional generic damage receiver. Tracers and impact markers use a fixed 24-slot pool, and shot audio is generated locally. All gameplay remains offline.
- Walking movement, camera and driver pose settings are in `data/player_settings.json`; weapon tuning is in `data/weapon_settings.json`. Vehicle interaction uses an editable shared scene and group registry, validated against a second cart instance.
- Final editor import succeeds in Godot 4.7.1. Godot MCP run/debug/stop confirms a clean startup with no errors or warnings after type/name warning cleanup. The source and bundled Hoodie GLB have identical SHA-256 hashes.
- No release ZIP updated.

Run player validation with `--path <project> --script res://tests/player_validation.gd`, and safety validation with `--script res://tests/player_safety_validation.gd`. Do not use `--headless` for these two tests: they verify mouse capture and the actual camera, which the dummy display server does not implement. Existing driving/map/UI tests can run headlessly.

# Previous validation - northwestern running track - 2026-10-12

Godot 4.7.1, Windows, Compatibility renderer, NVIDIA GeForce RTX 5050.

- `tests/running_track_validation.gd`: 13/13 checks. Closed two-lane route matches the existing northwestern ways. All 195 lane/center samples have ground support, path grip, no water/tree blocking and no streamed grass. Eleven shared path points preserve connections. Map selection/spawn, speeds above the grass cap and active tire trails pass.
- A real controller lap follows dense targets along the 1,368.222 m mapped loop. Recorded travel: 1,367.3 m at the test's controlled 4 m/s; 719/719 targets reached, zero wall contacts, zero off-path frames, zero recovery resets. This is a continuity/driveability test, not a lap-time feature.
- `tests/map_navigation.gd`: 32/32 after adding track styling and label. Existing map zoom, pan, input, selection, spawn safety and pause behavior pass. Combined: 45 checks.
- Actual renderer captures inspected from the cart, above the whole running loop, and in the zoomed map. The outline follows the supplied marked area; a continuous white divider separates the two red lanes, with thin outer edge lines and connected walking paths. Width/material/color are documented approximations.
- Four shared terrain/paint meshes add 2,340 vertices. The track uses existing continuous ground collision and existing spatial path classification; trees/grass placements remain unchanged because they already excluded these paths.
- Final Godot MCP run/debug/stop startup reports no errors or warnings. No release ZIP updated.

Repeat with `--headless --path <project> --script res://tests/running_track_validation.gd`. `tests/running_track_capture.gd` reproduces the development captures.

# Previous validation - game UI - 2026-10-12

Godot 4.7.1, Windows, Compatibility renderer, NVIDIA GeForce RTX 5050.

- `tests/game_ui_validation.gd`: 24/24 checks. Covers pause keyboard focus and resume, real KPH/neutral/reverse/forward and 200 KPH readouts, the visual tachometer redline, controls tab, real HIGH/LOW scenery changes, opening-hint fade, paused notification lifetime, and HUD/menu/map/sidebar bounds at 1280x800, 1920x1080 and 3440x1440. Resolution geometry is checked headlessly.
- `tests/integration.gd`: 36/36 after the UI rebuild. Existing driving, imported cart/wheels, recovery, camera, pause, vegetation and path support continue to pass.
- `tests/map_navigation.gd`: 32/32 during the UI rebuild, including zoom/pan, paused navigation, selection, Enter/button/double-click spawning, obstruction rejection and returning to the pause menu.
- Actual renderer captures inspected for driving HUD, all three pause tabs, full map, and the HUD at 1920x1080. The small default window is 1280x800 with a 1440x900 logical UI. The speedometer is transparent, controls and credits remain legible, and menus do not overlap their content.
- Final Godot MCP run/debug/stop launch check: empty error output, no script/runtime errors or warnings.
- Rajdhani font files and their SIL OFL 1.1 license are included locally. Fonts, maps and menus work offline. Gear/RPM are visual arcade readings; KPH uses actual cart speed.
- No release ZIP updated.

Repeat UI checks with `--headless --path <project> --script res://tests/game_ui_validation.gd`. `tests/game_ui_capture.gd` captures the rendered screens using fixed telemetry states; its output directory is this development chat's outputs folder.

# Previous validation — interactive park map



Validated on 11 October 2026 with Godot 4.7.1, Windows, Compatibility renderer.



- 32 map checks passed: M/ESC toggling, paused browsing, layout sourced from actual game geometry, viewport/sidebar layout, cursor-anchored zoom and limits, pan/release, fit and cart centering, click selection, button/Enter/double-click spawning, cleared drift and velocity, camera relocation, recovery point, travel-distance preservation, water/boundary/building rejection, and scenery/tree clearance. Opening from the pause menu restores that state when closed without spawning.

- All 36 existing game integration checks passed after the map was added.

- Full-park and zoomed map views were rendered and inspected. The complete mapped path network, circular routes, both principal lakes, gardens, approximate planting, surrounding streets/buildings, entrance labels, north compass, and metre scale are visible. Main labels avoid overlapping at the default fit scale. No remote imagery or network request is needed.



Repeat map checks with:



```powershell

& 'C:\Users\7amad\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\7amad\Desktop\godot\erbil-car-game' --script res://tests/map_navigation.gd

```



# Previous handling validation — 100 km/h and drift handling



Validated on 11 October 2026, Godot 4.7.1, Windows, Compatibility renderer.



- 36 game integration checks passed: imported cart and wheel bindings, acceleration, braking, reverse, grass, collision, recovery, pause, orbit, camera obstruction, solid support for all 2,649 mapped path segments, vegetation and HUD.

- 18 dedicated high-speed checks passed in a clear test arena: engine acceleration tapers, actual velocity reaches and remains capped at 100 km/h, high-speed normal grip, limited body lean, sustained drift, a quick Space tap, traction recovery, low-speed braking, reverse, the 40 km/h grass limit, a thin-wall collision at 100 km/h, and clearing drift on recovery.

- The drift test measured 94.09 km/h and a 37.06 degree difference between vehicle heading and actual travel direction. This confirms sideways movement rather than visual-only rotation.

- All three mapped route drives passed at the test follower's controlled 4 m/s: western loop 1,175.2 m, central loop 712.8 m, lake route 505.1 m. No wall contacts or recovery resets. The western follower briefly cuts grass at bends.

- A rendered in-game slide at English Door was inspected; the HUD shows DRIFT and the updated Space control. The camera pulls back and widens its field of view smoothly with speed. Godot MCP's final project startup reported no errors.

- Water detection uses a bounding rectangle and a horizontal half-open polygon ray with double-precision intersection arithmetic. Dry central and lake-route regression cases and lake recovery passed.



Run the native tests after importing the project:



```powershell

& 'C:\Users\7amad\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\7amad\Desktop\godot\erbil-car-game' --script res://tests/integration.gd

& 'C:\Users\7amad\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\7amad\Desktop\godot\erbil-car-game' --script res://tests/high_speed_driving.gd

& 'C:\Users\7amad\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\7amad\Desktop\godot\erbil-car-game' --script res://tests/routes.gd

```



## Prior smoothing verification



The cart uses physics interpolation, and the camera follows its interpolated pose every rendered frame. Spawn and recovery reset interpolation history. In a rendered stress comparison at 30 physics ticks and approximately 100 rendered frames per second, screen-motion deviation decreased from 94.61 to 4.47 pixels/second. Normal gameplay retains 60 physics ticks per second. Gradual body lean is intentional; no camera shake is added.



Reference: https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html



## Scope



Terrain and scenery remain simplified and flat. Arcade drift handling is tunable in data/driving_settings.tres. The actual park has narrow paths, so the high-speed handling tests use a clear arena and route continuity tests use a slower follower. The imported Club '90 vehicle and its attribution are retained. This is a development project; no ZIP was updated for these changes.





## Satellite-guided nature upgrade - 2026-10-11



Godot 4.7.1, Compatibility renderer, NVIDIA GeForce RTX 5050.



- `tests/nature_validation.gd`: 16 checks passed. All 10,126 tree placements avoid park boundaries, water, buildings and roads; decorative samples also pass. All 38 selected asset variants load with linked capped/mipmapped textures. Checks cover near/far batching, six-triangle/one-material impostors, bounded close-grass streaming, pooled nearby collisions, map teleport updates, low density, hidden collider removal, and gentle wind.

- `tests/integration.gd`: 36 checks passed after the scenery upgrade, including cart controls, braking/reverse, recovery, camera collision/orbit, pause, and classification/solid ground for all 2,649 path segments.

- `tests/map_navigation.gd`: 32 checks passed, including picking trees and resolving a nearby safe destination.

- `tests/routes.gd`: western loop 1,175.2m, central loop 712.8m, lake loop 505.1m; all three passed with zero walls/recoveries. The western route controller briefly cuts grass (2.9 seconds), as before.

- Actual renderer captures reviewed at English Door, lake, central garden flower borders, dense grove, and overhead. Roads remain open, greenery replaces the original geometric trees, and flower/stone variations appear in-game. Density and species grouping are approximations guided by the user screenshot.

- Render sample at 1280x800, VSync disabled: 100.0000008 km/h on a mapped 7m-wide northern path. Engine-reported sample 140 FPS; process-frame intervals median 5.724ms and p95 6.238ms. Low vegetation sample 167 FPS. These are short local samples, not a guarantee of a sustained rate everywhere. Initial shader warmup is slower.

- Runtime startup/mesh loading in the capture sample: about 1.12 seconds, excluding editor import.



Reproduce images and the performance sample with `tests/nature_capture.gd`. Map and gameplay remain offline. The existing release archive has intentionally not been updated.



Final Godot MCP startup check: clean output, no script/runtime errors or warnings. Placement generator rerun reproduces the identical vegetation file (SHA-256 comparison). Final scenery validation remains 16/16 after warning cleanup.





## 200 km/h, tire effects, manual camera and sports courts - 2026-10-12



Completed the unfinished driving request together with the southwest courts.

- `tests/vehicle_courts_validation.gd`: 25/25. Camera minimum/maximum and speed independence; zoom recovery persistence; 200 km/h acceleration; four tire trails; braking smoke and emission shutoff; bounded 3,000-mark storage; gentle high-speed turns; sharp-turn and braking-turn real rigid-body rollovers; rotation past horizontal; R recovery; map teleport cleanup and trail discontinuities; moderate drifts; three mapped sports parcels; three enclosed padel courts; two basketball hoops; volleyball; cleared vegetation; solid court surfaces; streamed grass exclusions; full map court footprints.

- `tests/high_speed_driving.gd`: 18/18 at the 200 km/h cap. Covers engine taper, speed cap, moderate-speed drifts and taps, braking/reverse, grass transition, recovery and a thin-wall collision at 200 km/h. Grass deceleration was raised to 24 m/s² for the larger entry speed.

- `tests/integration.gd`: 36/36. `tests/map_navigation.gd`: 32/32. Combined 111 checks pass.

- Rendered captures reviewed for the court group, braking skid marks/particles, and a cart physically tipping beyond horizontal. Pale particles use a fixed light material and a scale envelope to render correctly in Compatibility; each rear tire emitter has 60 particles. Capture sample: about 81 FPS court overview and 88 FPS braking/drift at 1280x800 after warmup. Short samples vary by view.

- Court geometry comes from local OSM ways 550516487/490/492; the user's correction determines the sports. Placement is left padel (three), middle volleyball, right basketball. All five court playing surfaces have appropriate lines/nets or hoops and barriers. Fittings/runoff are simplified approximations.

- Updated planting contains 10,112 trees and 117,000 background grass tufts, with court footprints cleared and protected from streamed grass. The court-aware generator preserves seeded placement outside these clearings.

- No release ZIP updated.

