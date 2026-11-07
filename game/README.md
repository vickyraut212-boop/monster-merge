# Monster Merge

A 2D drop-and-merge physics puzzle game made with Godot 4. Drop monsters into a jar; two of the same tier merge into the next tier, up to the Tier 7 boss.

## Open the project
1. Install Godot 4.7 (standard version, not .NET).
2. In Godot's Project Manager, click **Import** and pick `project.godot` in this folder.
3. Press **F5** to run. The Output panel says whether all 7 sprites were found.

## How to play
Move the mouse (or drag a finger) to aim the monster at the top, release to drop it. Two monsters of the same tier that touch merge into the next tier. Keep the pile below the dashed red line: if a monster stays above it for 2 seconds, it's game over.

## Folders
- `assets/monsters/` - the 7 monster PNGs (`tier_1.png` to `tier_7.png`)
- `assets/ui/` - background, planets, stars and the other UI art
- `docs/size_chart.png` - the art size chart the tier sizes follow
- `scenes/` - `main.tscn` (the game screen), `jar.tscn`, `hud.tscn` (settings button and pop-up, score cloud, Next preview, power-up buttons, game over)
- `scripts/`
  - `tier_data.gd` - sizes and points for each tier (edit this to tune)
  - `space_background.gd` - the space background and the randomly placed planets/stars (decoration only, never over the jar)
  - `jar.gd` - jar walls, floor and the danger line
  - `dropper.gd` - the alien spaceship: aiming, dropping and the drop order rule (set your own ship PNG on the Dropper node's "Ship Texture")
  - `monster.gd` - one monster's physics body
  - `main.gd` - merging, score and game over
  - `hud.gd` - on-screen UI
  - `game_audio.gd` - sound effects, music and vibration, plus the Sound / Music / Vibrate switches (placeholder sounds made in code; drop your own `pop.ogg`, `music.ogg` etc. into `assets/audio/` to replace them)

## Roadmap
1. Project setup (done)
2. Jar walls and the game-over line (done)
3. Monster scene and the dropper (done)
4. Merging, score and game over (done)
