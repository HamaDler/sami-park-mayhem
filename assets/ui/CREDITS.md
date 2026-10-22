# UI font credits

All fonts are licensed under the SIL Open Font License 1.1. Each license is next to its font in `fonts/`. The font files are unmodified.

| Font | Role in the game | Copyright | License file |
|---|---|---|---|
| Lilita One (`LilitaOne-Regular.ttf`) | Headings, buttons, HUD labels and numbers, weapon names, prompts, world signs | 2011 Juan Montoreano, Reserved Font Name "Lilita" | `fonts/OFL-LilitaOne.txt` |
| Nunito Sans (`NunitoSans-Variable.ttf`, `NunitoSans-Italic-Variable.ttf`) | Descriptions, settings help, credits, map place names, sign details | 2016 The Nunito Sans Project Authors | `fonts/OFL-NunitoSans.txt` |
| Bangers (`Bangers-Regular.ttf`) | Dramatic moments only: wave banners, HEADSHOT! / ROADKILL! callouts, game over, the title | 2010 The Bangers Project Authors | `fonts/OFL-Bangers.txt` |
| Rajdhani Bold / SemiBold | No longer used by the UI; kept for reference | 2014 Indian Type Foundry | `fonts/OFL.txt` |

Sources: Google Fonts (https://fonts.google.com/specimen/Lilita+One, https://fonts.google.com/specimen/Nunito+Sans, https://fonts.google.com/specimen/Bangers) and https://github.com/google/fonts/tree/main/ofl/rajdhani.

Nunito Sans weights are set at runtime through its variable `wght` axis. The speed digits use a runtime shear transform for the italic appearance.

UI layouts, drawing code, and panel shapes are original MIT-licensed project code. User-supplied game screenshots were used as visual references; no image assets from those games are bundled.
