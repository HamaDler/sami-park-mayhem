# Crowd characters

Original models: Quaternius, Ultimate Modular Men and Ultimate Modular Women.
License: CC0 1.0 (public domain), https://creativecommons.org/publicdomain/zero/1.0/

Official sources:
- https://quaternius.com/packs/ultimatemodularcharacters.html
- https://quaternius.com/packs/ultimatemodularwomen.html

The user supplied all 21 self-contained individual glTF files from the official
packs. Originals are preserved in men/ and women/. Twelve civilian outfits are
used by default. Space, military, fantasy and weapon props are excluded from
civilian rendering, while original files remain available for future use.

Baked data is derived from Walk, Idle_Neutral, Idle, Wave and Interact clips.
Position/normal frames and a combined colored mesh let the crowd share animation
work on the GPU. tools/bake_crowd.py rebuilds it from the unchanged originals.
