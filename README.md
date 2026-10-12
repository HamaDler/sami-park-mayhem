# Sami Park — Golf Cart Explorer

Open `project.godot` in **Godot 4.7.1** and press **F6** in `scenes/main.tscn`, or **F5** from any scene. Uses the Compatibility renderer. No plugins, paid assets, account, or network connection is required to play.

## Controls

| Input | Action |
|---|---|
| W / Up | Accelerate (up to 200 km/h) |
| S / Down | Brake, then reverse |
| A / D or Left / Right | Steer |
| Space | Handbrake; tap or hold while turning above 30 km/h to drift |
| Hold right mouse + move | Orbit the camera; release to recenter |
| Mouse wheel | Set chase distance between 2.8 and 18 m |
| F | Exit the current cart; enter a nearby parked vehicle |
| R | Recover the vehicle to your last safe park path |
| Esc | Pause / resume, or close the map |
| M | Open / close the full park map |

**On foot:** WASD/arrows move relative to the camera, mouse looks around, Shift sprints, and Space jumps. Scroll adjusts walking-camera distance between 2.2 and 7 m. Press **1** for the pistol, **2** for the automatic rifle, or **3** for the sniper. Hold **right mouse** to aim, **left mouse** to fire, and **R** to reload. Pistol/sniper fire once per click; the rifle fires continuously while held. Sniper aiming uses a clear scoped view. While aiming, pistol mouse sensitivity is 70% of normal, rifle 55%, and sniper 20%, on both axes. Edit `aim_sensitivity_multiplier` in `data/weapon_settings.json` or base `mouse_sensitivity` in `data/player_settings.json` to tune it. Weapon inputs are disabled inside vehicles. Esc and M work in both modes.

Water and leaving the park recover the active vehicle or walking character automatically. Grass reduces speed and grip. The pause menu offers lower tree density, and the HUD reduces visible vegetation automatically if sustained frame rate is low. Distances on the map are metres. The small map points north up.

## Editing

- `scenes/main.tscn`: environment, light, and scene composition.
- `scenes/park.tscn`: layout source and vegetation density; meshes are generated from local data at runtime.
- `scenes/cart.tscn`: cart collision, controller, and imported Club '90 model. `scripts/cart.gd` animates its original wheels and seats the supplied rigged Hoodie character.
- `scenes/character_avatar.tscn`: supplied Hoodie GLB, animation and driver/weapon hand poses.
- `scenes/walk_player.tscn`: walking capsule, movement, jumping and weapon system.
- `scenes/vehicle_access.tscn`: reusable interaction, occupant state and three exit markers.
- `scripts/main.gd`: active vehicle/player switching and safe entry/exit.
- `scripts/weapon_system.gd`: aiming rays, firing, reloads, audio and bounded effects.
- `scripts/weapon_models.gd`: loads the three imported weapon scenes.
- `scenes/weapons/pistol.tscn`, `rifle.tscn`, `sniper.tscn`: editable model scale/orientation, held position and grip/muzzle markers.
- `scripts/combat_hud.gd`: crosshair, scope, ammo, reload progress and weapon slots.
- `data/player_settings.json`: walking, sprinting, jumping, camera limits and driver pose.
- `data/weapon_settings.json`: magazines, rate of fire, damage, range, recoil and reload time.
- `scenes/chase_camera.tscn`: camera distance, field of view, collision probe.
- `scenes/hud.tscn`: driving HUD, notifications and minimap.
- `scenes/speedometer.tscn`: circular tachometer and live speed readout.
- `scenes/game_menu.tscn`: Drive, Options and Controls pause tabs.
- `scripts/game_ui.gd`: shared palette, fonts, button styles and key prompts.
- `data/driving_settings.tres`: speed, acceleration, braking, steering, and wheelbase.
- `data/park_layout.json`: projected map coordinates and spawn.
- `data/map_reference.svg`: overhead reference from the same map data.

## Accuracy and approximations

The park boundary (OSM way 245683947), path coordinates, water outlines, and building footprints are based on an OpenStreetMap extract downloaded 11 October 2026. Coordinates use a local metre projection around 43.98413475 E, 36.19107735 N. Internal ways share their original coordinates, so their connections and distances are retained. The supplied screenshot was used to cross-check the circular routes and lake placement. Map details may differ from the screenshot or current park conditions.

Terrain is flat. Untagged paths use a 4 m approximation and service routes 7 m; very narrow mapped footpaths are widened to at least 3.8 m for the cart. Benches, lamps, gate architecture and memorial appearance are original procedural approximations. Trees, the driver and the three guns use separately credited imported Quaternius models; placement, scale and poses are approximations. Unknown building heights default to one storey. The cart starts eight metres inside the English Door, facing along entrance way 617259236 into the park. The English Door was identified from the supplied annotated screenshot and matched to OSM gate node 11273413272. The northern Divan Door is a separate entrance. Gate architecture remains approximate. Public streets and surrounding building footprints are scenery; the playable area is the park. Tree colliders are concentrated near routes. Roads are slightly elevated visually over a continuous flat collision floor, eliminating seams.

This version is single-player, daytime free driving and walking, with basic weapon aiming/firing. There are no racing objectives, AI pedestrians, traffic, enemies or multiplayer.

## Sources and credits

**© OpenStreetMap contributors. Map data is available under the Open Database License (ODbL) 1.0.**

- https://www.openstreetmap.org/copyright
- https://opendatacommons.org/licenses/odbl/1-0/
- Original extract: `data/sources/park_extract.osm`
- Download: https://www.openstreetmap.org/api/0.6/map?bbox=43.975,36.182,43.991,36.201
- Original park identification: https://www.openstreetmap.org/node/2400418953

The extracted/derived map database is supplied under ODbL 1.0. Game code and original procedural art are supplied under the MIT license; see `LICENSE`. No third-party satellite imagery or map tiles are bundled.

## Validation

See `VALIDATION.md` for the measured checks and `tests/` for repeatable driving tests. Double-click `Launch Game.cmd` to play or `Open Editor.cmd` to edit. The game launcher imports assets automatically on its first run.

## Vehicle asset

The playable cart uses **Club '90 - Low Poly model** by **Daniel Zhabotinsky**, licensed under **CC BY 4.0**. Full source links, license, and adaptation notes are in `assets/vehicles/club90/CREDITS.md`. The imported model and textures are separate from the MIT-licensed original code. The seated driver uses the separately credited Hoodie GLB.

## Faster driving and drifting

Forward speed is capped at 200 km/h. Acceleration has a short throttle ramp and strong launch torque that eases at higher speeds. Steering becomes less sharp as speed rises; body lean is capped. Grass limits speed to 40 km/h and reduces grip. S/Down brakes normally before engaging reverse.

To drift, accelerate above 30 km/h, turn with A/D or the arrows, and tap or hold Space. The handbrake reduces traction and retains travel direction as the body rotates, producing sideways movement. Holding Space sustains the slide. Release Space to regain grip; countersteer to straighten. Space without a fast turn brakes to a stop. The HUD shows DRIFT during a slide. Driving and drift parameters are editable in `data/driving_settings.tres`.

## Full park map

Press **M** to open a north-up stylized map of the actual local park layout. The game pauses while you browse. Scroll to zoom around the cursor, use the + / − buttons, and drag with the right or middle mouse button to pan. **FIT PARK** resets the view; **LOCATE PLAYER** centers your location. Press M or Esc to close.

Click a point on a path or open grass, then choose **Spawn here** or press **Enter**. Double-click a point to spawn directly. Water, building interiors, and areas outside the park are rejected. Points blocked by trees or colliding props shift by up to eight metres to a nearby clear position, shown by the selection marker. The active vehicle or walking character moves there, the camera snaps, and the safe recovery location updates. Vehicle travel also clears speed/drift. Spawning resumes gameplay; closing without spawning restores the prior pause state.

The map uses the same bundled OpenStreetMap geometry as the world and works offline. The satellite screenshot guides the appearance and landmarks; imagery and map tiles are not bundled. `scenes/full_map.tscn`, `scripts/full_map.gd`, `scripts/map_canvas.gd`, and `data/map_labels.json` contain the editable map interface, styling, and labels. Divan Door's label is matched to the mapped northern pair of western gates using the supplied entrance reference; English Door uses the established game gate.


## Nature scenery

The park uses Quaternius **Ultimate Stylized Nature**, May 2022, licensed CC0. See `assets/nature/CREDITS.md` and `License.txt`. Original FBX sources, supplied textures and editable model scenes are included. The actual playable world uses the supplied asset meshes, replacing the old cylinder-and-sphere trees.

The full planting plan contains 10,112 trees, 117,000 background grass tufts, 2,272 flower/flowering-plant instances, and 217 stones. Normal trees predominate, with green maples, small pine and birch groves, and palm accents. Same-species blocks, dense perimeter belts, aligned rows, and open interior lawns follow density zones interpreted from the supplied satellite screenshot. This is approximate landscaping rather than a survey of individual real trees. Maple leaves use the supplied grayscale texture tinted green; other foliage is tinted to a restrained daytime palette. Flowers occur intermittently along mapped garden borders. All five stone models appear in varied sizes and rotations around dry lake shores and gardens.

Performance: spatial MultiMesh batches share model resources. Detailed tree meshes draw nearby; distant groves use six-triangle, single-material atlas impostors captured from the original models. Grass/flowers have shorter draw distances. A bounded ring streams dense close grass with dithered distance fading, rather than storing millions of tufts across the park. Two tiles at most are generated per physics tick. Textures are capped at 1024px with mipmaps. A pool of at most 320 nearby trunk colliders follows the active vehicle or walking character and updates after map travel. The pause menu's vegetation option thins trees and grass and shortens detail distances. Hidden trees leave no collision obstacles.

Editable files:
- `data/nature_settings.json`: draw distances, grass tile limits, collider pool, and seed.
- `data/planting_zones.json`: approximate world-space planting regions, density, row patterns, and species families.
- `data/vegetation_layout.json`: locally bundled individual placements; gameplay works offline.
- `assets/nature/scenes/`: drag any textured tree, rock, grass or flower scene into the editor to place it manually.
- `assets/nature/materials/` and `foliage.gdshader`: textures, foliage palette and gentle wind.
- `scripts/nature.gd`: batching, close grass streaming and nearby collisions.

Run `python tools/generate_vegetation.py` from the project to rebuild placements after changing zones. `tools/bake_nature.gd` rebuilds textured meshes and captured impostors with Godot: run Godot with `--path <project> --script res://tools/bake_nature.gd`, then import in the editor. Asset textures should retain their 1024px limit and mipmaps. No new release ZIP is generated during development.


## Tire effects, scroll zoom, and rollovers

Tire contact points leave world-space trails: faint tread marks during ordinary driving and darker continuous skid marks under braking/drifting. Road marks are dark gray, grass marks brown. Rear tires produce small smoke puffs when braking or drifting and dust on fast grass travel. Trails fade after 65 seconds and use a fixed 3,000-segment ring; two CPU particle emitters cap particles at 120. Teleports, recovery, and airborne/rolling states break contact continuity, so marks never stretch across the map.

Scroll up/down controls chase distance between **2.8 and 18 metres**. Field of view and follow height are fixed, and speed never changes selected zoom. Smooth follow, right-mouse orbit, collision avoidance and interpolation remain active. Zoom survives R recovery and map travel. Edit `data/camera_settings.tres` to change limits/defaults.

Top speed is **200 km/h**, with stronger launch acceleration and brakes, and an increased grass deceleration to retain the 40 km/h grass limit. Hard steering above roughly 140 km/h can accumulate enough lateral load to roll the cart. Braking while turning lowers the risk threshold to roughly 120 km/h; gentler inputs and moderate-speed drifts remain controllable. Rollover thresholds, exposure gain and launch/spin are in `data/driving_settings.tres`.

On rollover, `scenes/rollover_body.tscn` supplies real rigid-body motion, collision, gravity, and continuous collision detection. The cart can tumble onto its side or roof; the camera stays level. Press **R** to recover to the last safe path. Map spawning also restores an upright cart. If it settles upright by itself, normal controls resume. Water and leaving the park still recover automatically.

## Southwest sports courts

Beside the swimming pool and Zaytun Library, the three mapped parcels contain **three padel courts on the left**, **one volleyball court in the middle**, and **one basketball court on the right**. Source geometry uses OSM ways 550516487, 550516490, 550516492; the user screenshot overrides the older tennis tags on the first two. Regulation-sized playing areas are fitted within the mapped parcels; paint, runoff, signs and fittings are approximations.

Basketball has two hoops, backboards and court markings. Volleyball has posts, net and attack/center lines. Each padel court has a central net, service lines, glass back/side panels, mesh fencing and side openings. Hoops, fences and nets collide with the cart. Trees and decorative vegetation are removed from these footprints, and streamed grass also skips them. The full map shows the parcels and labels for locating/spawning nearby.

Edit `scenes/sports_area.tscn`, `scripts/sports_area.gd`, and `data/sports_layout.json`. The planting generator preserves the court clearings. All work remains in the native project; release archives are unchanged.


## Game interface

The driving HUD uses a transparent circular tachometer with white ticks, a redline, a smoothed needle, large italic speed digits, and a gear indicator. KPH is the actual controller speed. The gear and RPM readings are visual approximations for the arcade controller; the cart does not simulate a combustion engine or physical gearbox. Reverse shows R and idle shows N. DRIFT, OFF ROAD and rollover recovery prompts appear below the dial.

The north-up minimap sits at the lower left. Opening driving hints fade after 19 seconds; map/menu/reset prompts remain at the bottom. Recovery notifications use a short angular banner. Press Esc for the pause menu's DRIVE, OPTIONS and CONTROLS tabs. OPTIONS has HIGH/LOW vegetation detail. The full map uses the same condensed typography, charcoal panels and lime selection accents.

UI scenes remain separate and editable. The shared style lives in `scripts/game_ui.gd`, with clipped panels in `scripts/game_plate.gd`. Rajdhani Bold/SemiBold by Indian Type Foundry is bundled under SIL Open Font License 1.1; see `assets/ui/CREDITS.md` and `assets/ui/fonts/OFL.txt`. The source font files are unmodified; digit italics use a runtime font transform.


## Northwestern running track

The loop identified in the supplied annotated satellite screenshot is now a reddish running surface with **two lanes**, a continuous white divider and thin outer white edge lines. Its closed centerline is 1,368.222 metres, from the existing mapped ways 1392513106 and 1392513107. Those ways share their original junction coordinates with the surrounding park paths, so entries and crossings remain open. Related OSM track way 238030569 has an older three-lane tag; the user's two-lane correction determines the game appearance.

Total width is 4 m (two 2 m lanes), retaining the game's cart-friendly path width. The older OSM track's 2.5 m width, paint dimensions, red shades and exact surface material are approximated. The track is flat and uses the park's continuous collision floor, with normal path grip and speed rather than grass handling. Tire trails/braking effects and map spawning work on it. Plants and streamed grass already exclude these mapped routes.

Press **M**, look in the northwest near **Divan Door** for **Running track**, select the red loop, and spawn there. The minimap also highlights it in red.

Edit `scenes/running_track.tscn`, `scripts/running_track.gd` and `data/running_track.json`. The two lanes, border and all white paint are four shared meshes with continuous joined ribbon geometry; no per-segment physics bodies or raised curbs are added. Map geometry remains bundled offline under the existing OpenStreetMap ODbL attribution. No release ZIP was changed.


## Hoodie character, walking and weapons

The supplied **Hoodie Character by Quaternius** is bundled unmodified in `assets/characters/hoodie/hoodie.glb`, under **CC0 1.0**. Source: https://poly.pizza/m/gKLBoRsyKe . See the adjacent `CREDITS.md`. The original rig and its animation clips remain editable. The game uses neutral/gun idle and walking/running/strafe clips. The source has no jump animation; airborne posture is a neutral pose with weapon-hand placement. Seated hips, bent legs, feet on the floor and hands on the actual cart steering wheel are posed separately in code.

Press F to leave the cart. Clear exit markers are checked against ground, water, buildings and physical obstacles; another side is used if the first is blocked. If all exits are blocked, the player stays inside. A rolling cart must be recovered with R before exiting. Entering requires a nearby unoccupied upright vehicle within the configured range, with a clear interaction ray. The cart stays parked while walking. Mouse look, HUD, minimap and map travel follow the current actor. Walking into water or beyond the playable boundary returns you to safe ground.

The three weapons use the supplied **Quaternius Pistol, Assault Rifle and Sniper Rifle GLBs**, under **CC0 1.0**. The originals are preserved in `assets/weapons/quaternius/`; adjacent credits link each source. Editable wrapper scenes in `scenes/weapons/` correct export orientation and scale, fit the grips to the character, and put the muzzle markers just beyond the actual barrels. The procedural placeholders have been replaced. Magazines hold 12 pistol rounds, 30 rifle rounds and 5 sniper rounds. Reload reserve is unlimited in this version. A center-camera aiming ray and a second ray from the muzzle prevent firing through close cover. Shots have recoil, brief muzzle flash/tracers, simple audio and pooled impact dots. Objects implementing `receive_hit(damage, position, normal)` can receive damage; existing park scenery does not have destructible health, and no enemies are added. Firing and movement pause with menus; resuming or interacting with UI requires releasing the fire button before another shot.

To add another compatible vehicle, instance the existing cart scene, or attach `scenes/vehicle_access.tscn` to a compatible `CharacterBody3D` controller and position its three exit markers. The parent controller supplies `set_control_enabled`, `teleport_to`, `recover`, `rolling`, `speed`, `distance_m`, and the existing driving telemetry, plus `recovered` and `rollover_started` signals. Initialize it with the park. Vehicles register in the `vehicles` group and start parked/empty; the main coordinator discovers the nearest available one. Imported GLBs alone still need a controller, collision and those markers.
