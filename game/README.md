# Monster Merge

A 2D drop-and-merge physics puzzle game made with Godot 4. Drop monsters into a jar; two of the same tier merge into the next tier, up to the Tier 8 boss.

## Open the project
1. Install Godot 4.7 (standard version, not .NET).
2. In Godot's Project Manager, click **Import** and pick `project.godot` in this folder.
3. Press **F5** to run. The Output panel says whether all 8 sprites were found.

## How to play
Move the mouse (or drag a finger) to aim the monster at the top, release to drop it. Two monsters of the same tier that touch merge into the next tier. Keep the pile below the dashed line across the top of the jar: if a monster stays above it for 2 seconds, it's game over. The battery button (4th, under the jar) shakes the jar to jostle the monsters (shaking a phone works too); the other three power-ups are:

- **Merge** (1st): every Tier 1 and Tier 2 monster in the jar vanishes.
- **Bomb** (2nd): a red target appears on every monster; tap one and a bomb drops on it, destroying it in a cloud of smoke.
- **Upgrade** (3rd): green targets appear; tap a monster to turn it into the next tier (Tier 8 bosses have no target).

While a target is showing, the ship stops dropping; tap the button again or tap empty space to cancel (cancelling is free). Power-ups give no points.

**Limited uses:** the bubble on each button shows the uses left. A game starts with Merge 1, Bomb 2, Upgrade 1 and Battery 3. A use is only spent when the power-up does something (shaking the phone spends a battery use too); at 0 the button greys out. Every 500 points, each power-up gets one more use, up to 9. These numbers are at the top of `scripts/power_ups.gd`, which holds all the power-up logic.

**Combos:** merges that follow each other within 1.5 seconds (chain reactions in the jar, or a quick drop that merges straight after the last one) form a chain. Each merge after the first earns extra points: half its merge points again per step (x2 adds half, x3 a whole extra, x4 one and a half...), and at least 5 per step. Feedback stays small and shows one thing at a time: an ordinary merge shows its points ("+21", bonus and combo extra included); a chain shows one short word above the merge instead: **NICE!** (2nd merge), **COMBO x3**, **SUPER!** (4th), **WELL DONE!** (5th and on, or two Tier 8 bosses vanishing). A big tier bonus (Tier 6 and up) outside a chain shows **BONUS +30** / **+40** / **+50**. A new word replaces the one before. The chain ends when 1.5 seconds pass with no merge. The window and the extra points are at the top of `scripts/main.gd`.

## Folders
- `assets/monsters/` - the 8 monster PNGs (`tier_1.png` to `tier_8.png`), each with 3 blink frames
- `assets/ui/` - background, planets, stars and the other UI art
- `docs/size_chart.png` - the art size chart the tier sizes follow (reference only, not shown in the game)
- `scenes/` - `main.tscn` (the game screen), `jar.tscn`, `hud.tscn` (settings button and pop-up, score cloud, Next preview, power-up buttons, game over)
- `scripts/`
  - `tier_data.gd` - sizes and points for each tier (edit this to tune)
  - `space_background.gd` - the space background with the planets and stars placed as in the UI reference (decoration only)
  - `jar.gd` - the U-shaped glass jar (drawn in code), its walls and floor, and the dashed game-over line across its top
  - `dropper.gd` - the alien spaceship (`assets/ui/alien_ship.png`): aiming, dropping and the drop order rule
  - `monster.gd` - one monster's physics body
  - `main.gd` - merging, score, combos and game over
  - `reward_text.gd` - the floating score numbers and the feedback words (NICE!, COMBO x3, SUPER!, WELL DONE!, BONUS +N): size, colours and fade
  - `hud.gd` - on-screen UI
  - `game_audio.gd` - sound effects, music and vibration, plus the Sound / Music / Vibrate switches (placeholder sounds made in code; drop your own `pop.ogg`, `music.ogg` etc. into `assets/audio/` to replace them)

## Roadmap
1. Project setup (done)
2. Jar walls and the game-over line (done)
3. Monster scene and the dropper (done)
4. Merging, score and game over (done)
