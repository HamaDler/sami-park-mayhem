# Sami Park — Zombie Survival

Open `project.godot` in **Godot 4.7.1** and press **F6** in `scenes/main.tscn`, or **F5** from any scene. Uses the Compatibility renderer. No plugins, paid assets, account, or network connection is required to play.

The playable park is enclosed by a continuous 4.2 m metal fence with a low concrete base. Outbound entrances are fenced shut for gameplay; the cart and player still start inside English Door. Overlapping solid sections stop walking, jumping, driving and rollovers at the boundary, and survival navigation treats them as obstacles. Fence height, spacing, colors and batching are editable in `data/perimeter_settings.json`; its reusable scene is `scenes/perimeter_fence.tscn`. This is an approximate gameplay barrier, not a reconstruction of the park's real fencing.

## Survival

Start on foot at English Door with a pistol (12 loaded / 96 reserve), 100 health, 500 dinars and the golf cart parked beside you. Wave 1 begins after five seconds: 24 zombies total, up to 12 alive at once. Each cleared wave adds 8 zombies and three simultaneous enemies (maximum 60), followed by 10 seconds to prepare. Health, damage and movement speed increase each wave. Zombies in the first three waves spawn already hunting you; later waves mix in wanderers. Zombies detect you within 60 metres with line of sight; firing attracts them within 110 metres. The final five enemies are marked to prevent a long search across the park.

Gun kills award 100 score and 100 dinars; headshots double bullet damage and award 150 of each. Roadkills award 50 of each and wear down the cart. Health regenerates after five seconds without damage. Magazines reload from finite reserves. Slots 2 and 3 remain locked until you obtain those weapons.

Four gold **BOX** map markers identify stations at English Door, the central plaza, lakeside and the fairgrounds. Approach the appropriate pedestal and press **F**: the mystery box costs **950 IQD**, selected-weapon ammunition costs **250 IQD**, and a three-second stationary cart repair costs **750 IQD**. Bring a damaged but drivable cart within 12 metres; a completely disabled cart can be serviced remotely from a station, at its existing location. Moving or taking damage interrupts repair without charging. A mystery box reveals a pistol/rifle/sniper after three seconds; press F again within 20 seconds to claim it. Damage tiers are Standard ×1, Improved ×1.5, Rare ×2.25 and Legendary ×3.4. Equal/lower rewards refill that slot without downgrading it.

Kills have an 8% chance to drop a pickup: **Infinite Ammo** (20 seconds without consuming ammunition or reloading), **Double Dinars** (30 seconds) or **Max Ammo** (instant refill of owned weapons). Walk or drive over one to collect it before its 30-second expiry. Repeated timed pickups refresh duration.

**Supply missions:** the first cache is marked after 45 seconds, with a new opportunity 90 seconds after each completion or expiry. Cyan markers on the HUD and map lead to a cache near the western loop, central plaza, lake or fairgrounds. Reach it within 210 seconds and secure its 14 m zone **on foot for 30 seconds**. Zombies within five metres of the crate contest progress; leaving the zone loses two seconds of progress per second. The beacon attracts nearby enemies. Success awards **500 score + 1,500 IQD** (Double Dinars applies), plus full ammunition or a 25% chance of a free random cart upgrade. Fully upgraded carts fall back to ammunition. Objectives do not add uncounted enemies to the wave.

**Enemy types:** regular walkers are joined by orange sprinters (60% health, double movement speed), blue armored zombies (150% health, 45% body bullet damage received, 70% ram damage received, slower movement) and purple-marked screamers. Headshots bypass armor and retain double damage. Screamers telegraph an alert within 35 m with line of sight, then alert living enemies within 95 m; killing them during the windup cancels it. All types reuse the imported animated models and pooled bodies. Specials become more common as waves advance. Variant movement is capped at 7.5 m/s and damage at 60.

**Cart workshops:** park an upright, working cart within 16 m of a station, exit, and press **F** at the workshop pedestal. Buy three levels each of reinforced bumper (more ram damage / less wear; 1,000 / 1,800 / 3,000 IQD), armor (more durability / reduced damage; 1,500 / 2,500 / 4,000 IQD), and handling (grip / brakes / stability; 1,200 / 2,200 / 3,500 IQD). Parts appear on the cart. Armor preserves the cart's damage percentage and upgrades do not replace repairs. The 200 km/h limit and handbrake drift remain available. **Combat continues while shopping**; damage closes the menu and restores controls. F or Esc closes it manually. Upgrades and mission progress reset with each run.

Edit `data/supply_missions.json`, `data/zombie_types.json` and `data/vehicle_upgrades.json` to tune the new systems. Runtime components are separate children of `scenes/survival.tscn`.

The cart retains its 200 km/h limit, drifting and physical rollovers, but zombies, ramming and crashes damage it. Destruction stops the cart and ejects you to safe nearby ground. Once an overturned cart stops moving, exit with F, stand within five metres and **hold R for three seconds** to right it in place. Recovery does not restore health. The map supports navigation and waypoints; survival disables teleportation. Death ends the run. **Try Again** or **Restart Run** resets weapons, money, pickups, enemies and wave state; local best score, highest completed wave and lifetime kills remain saved in `user://survival_records.json`. Quitting does not save an unfinished run.

Balance and loot settings are in `data/survival_settings.json`; station anchors are in `data/survival_locations.json`. `scenes/survival.tscn`, `scenes/zombie.tscn` and `scenes/mystery_station.tscn` are editable separately. The survival director replaces the ambient crowd during runs, preserving the civilian assets and tools. Three animated Quaternius zombies use head hitboxes derived from their actual skin weights; the pack's headless ribcage model is retained as source but excluded from the roster. Source/license information is in `assets/zombies/quaternius/CREDITS.md`.

Navigation uses a locally bundled three-metre grid across paths and grass, excluding water, buildings, enclosed padel courts and tree trunks. Live scenery adds furniture, nets and station obstacles. To rebuild after changing map/vegetation geometry, run `tools/build_survival_navigation.py` with Python + NumPy. `tools/build_zombie_hitboxes.py` rebuilds bone-relative head hitboxes from the source glTFs. Python is not required to play.

See `SURVIVAL_VALIDATION.md` for gameplay checks and local performance measurements. When preparing a future export, include the non-resource data files (`*.json,*.bin.gz,*.txt,*.md`) in the export filters; this development update does not rebuild a release.

## Controls

**Audio:** press **Esc → Audio** for Master, Music, Effects and UI volume sliders. Settings save automatically. The background music continues through map/pause menus and new runs, ducking slightly while paused; world sounds pause. Gun types use different recorded shots with overlapping tails. Engine pitch/loudness follows throttle and speed; road rumble, driving wind and tire squeal respond to motion, braking and drifting. Leaving a cart fades its engine out. Footsteps change between paths and grass. Zombies groan, lunge, flinch and die with positional 3D sounds (nearest enemies take priority), and melee swings and dodge rolls have their own whooshes. Menu hover/click/open/close, reload/empty/equip, pickup, purchase and wave cues are included. Mix/event settings are editable in `data/audio_settings.json`, with credits/licenses in `assets/audio/CREDITS.md` and **Audio Credits** in the menu. All sounds are local files and work offline.

| Input | Action |
|---|---|
| W / Up | Accelerate (up to 200 km/h) |
| S / Down | Brake, then reverse |
| A / D or Left / Right | Steer |
| Space | Handbrake; tap or hold while turning above 30 km/h to drift |
| Hold right mouse + move | Orbit the camera; release to recenter |
| Mouse wheel | Set chase distance between 2.8 and 18 m |
| F | Enter/exit a vehicle, buy supplies, use a box or claim its weapon |
| R | Reload on foot; hold near a stationary overturned cart to right it |
| Esc | Pause / resume, or close the map |
| C | Dodge roll (on foot) |
| V | Melee kick (on foot) |
| M | Open / close the full park map |

**On foot:** WASD/arrows move relative to the camera, mouse looks around, Shift sprints (8 m/s vs 4.5 m/s walking), and Space jumps. Sprinting drains stamina (yellow bar under health); at zero, sprint locks until stamina recovers to 25%. Firing breaks a sprint, and the gun comes up after a short delay. **C** dodge-rolls in your movement direction (backwards when standing), costs 30 stamina and makes you invulnerable for the first 0.35 s; a well-timed roll avoids a zombie's strike. **V** kicks: 55 damage in a short cone in front of you, with knockback and stagger. Rolling and kicking pause a reload rather than cancelling it. Scroll adjusts walking-camera distance between 2.2 and 7 m. Press **1** for the pistol, **2** for the automatic rifle, or **3** for the sniper. Hold **right mouse** to aim, **left mouse** to fire, and **R** to reload. Pistol/sniper fire once per click; the rifle fires continuously while held. Shots land inside a cone that is wide from the hip, tighter while moving slowly and very tight while aiming; sustained fire blooms it. The crosshair shows the live cone. Each shot kicks the camera and shakes it slightly; hitmarkers (white body, gold head, red kill) and floating score popups confirm hits. Zombies bleed, stagger and get knocked back; corpses sink into the ground after a few seconds. The screen edge shows which direction damage came from and pulses red at low health. Death plays out in slow motion before the summary. Spread, kick and shake are per-weapon in `data/weapon_settings.json`; stamina, roll and melee tuning are in `data/player_settings.json`. Sniper aiming uses a clear scoped view. While aiming, pistol mouse sensitivity is 70% of normal, rifle 55%, and sniper 20%, on both axes. Edit `aim_sensitivity_multiplier` in `data/weapon_settings.json` or base `mouse_sensitivity` in `data/player_settings.json` to tune it. Weapon inputs are disabled inside vehicles. Esc and M work in both modes.

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

Click to place a waypoint; gold BOX markers locate weapon, ammunition and repair stations. Survival disables map spawning, Enter-to-spawn and double-click fast travel. Closing the map restores the previous pause state.

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

On rollover, `scenes/rollover_body.tscn` supplies real rigid-body motion, collision, gravity, and continuous collision detection. The cart can tumble onto its side or roof; the camera stays level. Once it stops, exit with F and hold R nearby to right it in place. If it settles upright by itself, normal controls resume. Water and leaving the park recover to nearby valid ground without healing.

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


## Park visitors

The park starts with 1,000 ambient visitors: 500 men and 500 women, with randomized
civilian outfits, clothing tints, heights, walking speeds and animation phases.
Most walk along the mapped path network, choose new connected paths at junctions,
and occasionally stop to idle, wave or interact. Nearby visitors stop for the
active actor and turn back when a sampled scenery obstacle blocks their route.
They are ambient visuals, with no damage, ragdolls or physical crowd collision.

`scenes/crowd.tscn` and `scripts/crowd.gd` are separate from mission logic.
`data/crowd_settings.json` controls population, seed (0 means a new random crowd),
speeds, pause probability, visibility distance and entrance density.
`data/crowd_routes.json` derives from actual mapped centerlines and excludes spans
through water, buildings or beyond the park. Run `python tools/build_crowd_routes.py`
after editing `data/park_layout.json`.

All 21 user-supplied Quaternius CC0 glTF originals remain unchanged in
`assets/characters/crowd/men/` and `women/`. Twelve civilian outfits are used by
default, without weapon props. Shared vertex animation textures drive Walk,
Idle_Neutral, Idle, Wave and Interact; the population does not create 1,000 live
skeletons or pathfinding agents. Visibility uses spatial MultiMeshes, movement
runs at 20 Hz and positions interpolate between updates. Animation follows the
pausable game clock. `tools/bake_crowd.py` (Python + NumPy) rebuilds the compressed
pose data from the originals. Keep `*.json` and `*.bin.gz` in export include filters
when producing a standalone build, along with the existing park JSON data.

For future missions, `Crowd.get_person_state(id)`, `nearest_person(point, radius)`,
`set_person_paused(id, value)`, `person_arrived` and `person_state_changed` expose
visitor state. IDs and mission metadata persist during a session even outside
render distance; session save/load and full interactive character bodies can be
added when mission requirements are defined.

Run `res://tests/crowd_validation.gd` to check population, safe walking, pause,
visibility and mission hooks. No release archive is generated by this change.
