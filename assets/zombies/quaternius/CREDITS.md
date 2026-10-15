# Zombie Apocalypse Kit — Quaternius

Original creator: Quaternius. Original pack: https://quaternius.com/packs/zombieapocalypsekit.html

Downloaded from the creator's linked public Google Drive folder on 15 October 2026:
https://drive.google.com/drive/folders/1mWP6sCHun7OUMHQeDNZLrXTteXlzWg_t

License: **CC0 1.0 Universal / Public Domain Dedication**. https://creativecommons.org/publicdomain/zero/1.0/

The creator's supplied `License.txt` is preserved verbatim (its heading refers to a different pack; the official Zombie Apocalypse Kit page independently identifies this kit as CC0). `SOURCE.json` records the source URL, hashes, sizes, embedded image/buffer information and verified animation names.

The game uses Zombie_Basic, Zombie_Chubby and Zombie_Arm, with Walk, Idle, Run, Punch, HitReact and Death animations. The headless Zombie_Ribcage is included as an unused original source. All original glTF bytes are unmodified. Runtime scenes normalize height and animate the originals; bone-relative head-hitbox measurements in `head_hitboxes.json` are generated from head-weighted source vertices by `tools/build_zombie_hitboxes.py`. The atlas is also supplied separately; the glTF files embed their texture and geometry, so gameplay works offline.
