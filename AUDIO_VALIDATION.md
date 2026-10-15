# Audio integration — 15 October 2026

Godot 4.7.1, Windows, Compatibility renderer. All 29 game-ready audio files imported successfully and are bundled locally. Source URLs, authors, license links and editing details are in `assets/audio/CREDITS.md`; original/processed hashes and clip information are in `assets/audio/manifest.json`.

## Validation

- `tests/audio_validation.gd`: **31/31** in the actual renderer/audio backend. Checks continuous looping music; distinct firearm recordings dispatched by actual weapon firing; non-silent, unclipped samples captured from the Master mixer; reload cues; cart engine and speed-dependent pitch/wind; brake/drift squeal; airborne tire-sound suppression; engine fade on exit; world pause and continuing menu/music audio; actual button hover/click connections; four volume controls; independent music adjustment; effects mute; saved preferences; resume; and music/manager continuity across a real scene restart.
- Master mixer sample peaks for pistol/rifle/sniper in the final run were approximately **0.504 / 0.251 / 0.481** (linear amplitude). A Master hard limiter has a −1 dB ceiling. This measures playback and clipping; it is not a subjective listening or loudness certification.
- `tests/survival_validation.gd`: **65/65** after integration. Combat, ammunition, waves, purchases, power-ups, recovery, vehicle destruction and game-over remain functional.
- Audio settings view was rendered at 1280×800 and visually inspected. Four sliders, values, the Audio sidebar tab and credits button fit the existing game UI.
- Game shutdown stops audio and releases playback before quitting. World effects use 24 pooled voices; UI uses six. Scene restart reuses one persistent music player and manager. Vehicle loops are per vehicle, positioned in 3D, and fade according to control/surface/contact state.

Run `--path <project> --script res://tests/audio_validation.gd` without `--headless` to test the actual sound mixer. Headless gameplay checks intentionally skip hardware playback while retaining sound-event dispatch. Tests use the workspace runner's separate APPDATA profile, preserving normal player settings.

## Editing and use

- **Esc → Audio**: Master, Music, Effects and UI volume. Preferences save to `user://audio_settings.cfg`.
- `data/audio_settings.json`: audio event files/gains, music/ducking, voice count, engine pitch, loop gains and audible distance.
- `scripts/game_audio.gd`: persistent music, buses, limiter, pooled effects, footsteps, preferences and graceful shutdown.
- `scenes/vehicle_audio.tscn`: reusable per-cart engine, driving rumble, wind and skid sound component.
- Full downloaded source archives remain in the development workspace's `work/audio` folder; only selected processed audio is inside the game project. No release ZIP or executable was rebuilt.
