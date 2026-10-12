# Latest validation - northwestern running track - 2026-10-12

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

