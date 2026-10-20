# Audio credits and licenses

Downloaded from the following public sources on 15 October 2026. All audio is bundled locally; gameplay needs no network access. The full original archives are kept outside the game in the development workspace. Only selected game-ready files are included here.

## Background music — CC0

**EmptyCity: Background Music**, by **yd**.
Source: https://opengameart.org/content/emptycity-background-music
Original file: EmptyCity.ogg. Bundled as `empty_city.ogg`, unmodified, played as a continuous loop.
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/

## Firearms — CC0

**The Free Firearm Sound Library**, created and recorded by **Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney**.
Source: https://opengameart.org/content/the-free-firearm-sound-library
Original archive: Prepared SFX Library.7z. Selected recordings:

- Pistol: `1911/A_42P.wav` — near-distance .45 handgun shot.
- Automatic rifle: `AR-15/D_32P.wav` — near-distance 5.56/.223 rifle shot, played per actual round.
- Sniper: `Mosin Nagant/M_26P.wav` — near-distance bolt-action rifle shot.

License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
Edits: leading silence removed, cropped tails, mono PCM16 at 44.1 kHz, peak normalization and short edge fades. The original archive's metadata sheet identifies each recording. Imported game gun models and these recordings represent their weapon classes; they are not an exact model-to-recording match.

## Engine and driving rumble — CC0

**racing car engine sound loops**, by **domasx2**.
Source: https://opengameart.org/content/racing-car-engine-sound-loops
Original files: loop_0.wav and loop_2_0.wav; the creator states these were remade from a public-domain source.
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
Edits: mono PCM16 44.1 kHz, peak normalization and short loop crossfade. The rolling layer additionally uses a 550 Hz low-pass filter. Runtime pitch and gain follow throttle and speed; this is an arcade cart sound treatment.

## Tire squeal / braking / drifting — CC BY 3.0

**Car tire squeal skid loop**, by **audible-edge (Tom Haigh)**, edited into a loop and submitted by **qubodup**.
Source: https://opengameart.org/content/car-tire-squeal-skid-loop
Original file: tires_squal_loop.wav.
License: **Creative Commons Attribution 3.0 Unported** — https://creativecommons.org/licenses/by/3.0/
Edits for this game: resampled from 96 kHz/24-bit to mono 44.1 kHz/16-bit PCM, peak normalization and 35 ms loop seam crossfade. Runtime volume and pitch change with braking, drifting, speed and road/grass surface. This attribution is also accessible in Pause → Audio → Audio Credits. No endorsement is implied.

## Driving wind — CC0

**wind1**, by **Luke.RUSTLTD**.
Source: https://opengameart.org/content/wind1
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
Edits: eight-second excerpt, 2.2 kHz low-pass, peak normalization, PCM16 and loop crossfade; blended according to vehicle speed.

## Interface, footsteps and impacts — CC0

**Interface Sounds** and **Impact Sounds**, by **Kenney**.
Sources: https://kenney.nl/assets/interface-sounds and https://kenney.nl/assets/impact-sounds
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
Original supplied licenses are preserved as `KENNEY_INTERFACE_LICENSE.txt` and `KENNEY_IMPACT_LICENSE.txt`.
Selections cover button hover/click, opening/closing menus, confirmation/error, weapon handling, reload clicks, dry firing, wave and pickup cues, three grass/concrete footsteps, metal cart impact and player impact. Reloads use mechanical switch cues, not recorded full firearm-reload sequences.
Edits: trimmed leading silence, mono PCM16 44.1 kHz, peak normalization and edge fades; hover shortened to 90 ms. Exact source filenames, hashes, duration and processing are recorded in `manifest.json`.

## Zombie voices — CC0

Downloaded 20 October 2026.

**zombie moans**, by **Darsycho**.
Source: https://opengameart.org/content/zombie-moans
Original file: darsycho__zombie-moans.ogg. Excerpts bundled as `zombie_groan_0`–`3.wav` and `zombie_death_0`–`1.wav`.
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/ (credit appreciated by the author).

**zombie noises and moans**, by **ianzazz**.
Source: https://opengameart.org/content/zombie-noises-and-moans
Original archive: zombienoises.zip. `zombienoise2.ogg` → `zombie_groan_4.wav`, `zombienoise3.ogg` → `zombie_attack.wav`, `fastzombie1.ogg` → `zombie_hit.wav`, `zombienoise1.ogg` → `zombie_scream.wav`.
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/

## Melee swings and dodge roll — CC0

**Swishes Sound Pack**, by **artisticdude**.
Source: https://opengameart.org/content/swishes-sound-pack
Original archive: swishes.zip. `swish-3.wav` / `swish-7.wav` → `melee_swing_0` / `1.wav`, `swish-11.wav` → `roll_whoosh.wav`.
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/

Edits for all of the above: mono PCM16 44.1 kHz, leading silence trimmed, peak normalization to -3.1 dB and short edge fades. Groans and deaths are cut from one longer recording; excerpt times are listed in `manifest.json`. Zombie sounds are played positionally in 3D. Melee impacts and hitmarkers reuse the Kenney impact/interface files above.
