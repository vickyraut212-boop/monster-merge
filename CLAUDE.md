# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Monster Merge": a 2D drop-and-merge physics puzzle (Suika-style) in Godot 4.3+ (standard build, GDScript, GL Compatibility renderer, portrait 720x1280). There is no build step, linter or test suite. Run it by opening `project.godot` in the Godot editor and pressing F5 (main scene is `res://scenes/main.tscn`). Headless/CLI runs, if needed: `godot --path . ` (editor binary must be on PATH). On start, `main.gd` warns in the Output panel if any tier sprite is missing.

## Architecture

`scenes/main.tscn` wires four children together and `scripts/main.gd` is the coordinator:
- `Jar` (`jar.gd`) – walls, floor and the danger line; emits `game_over` when a monster stays above the line for 2 s.
- `Dropper` (`dropper.gd`) – the alien ship; aims, emits `dropped(tier, position)`, and owns the drop-order rule (first drop is Tier 1, then random up to `TierData.MAX_DROP_TIER`).
- `Monsters` node – container for spawned `Monster` bodies (`monster.gd`, created in code via `Monster.new()` + `setup(tier)`, not from a scene).
- `HUD` (`hud.gd`, `scenes/hud.tscn`) – score/best, Next preview, settings pop-up, power-ups, game-over panel; communicates via signals (`play_again_pressed`, `restart_pressed`).

Merge flow: a `Monster` emits `touched_same_tier(a, b)` -> `main.gd` sets `is_merging` on both (guards double merges) and defers `_merge()` because physics bodies can't be freed mid-step -> both are removed and a next-tier monster spawns at the midpoint with half the averaged velocity. Merging two Tier 7 bosses spawns nothing and awards `BOSS_MERGE_BONUS`. Restart is `get_tree().reload_current_scene()`; best score persists in `user://best_score.cfg`.

Autoloads (`project.godot`): `TierData` (`tier_data.gd`) and `GameAudio` (`game_audio.gd`). `TierData` is the single source of truth for tuning: collider radius derives from `BOSS_RADIUS * SIZE_CHART_RATIO * READABILITY_BOOST`, and sprites are auto-scaled to match collider width, so swapping art never changes gameplay size. Points/bonus per tier, `MAX_DROP_TIER` and `BOSS_MERGE_BONUS` also live there. Other helpers: `blink_sprite.gd` (blink animation timing), `shaker.gd` (phone shake / on-screen SHAKE jostles monsters), `intro.gd` (opening animation, first launch only), `space_background.gd` (decorative planets/stars, never over the jar).

## Assets

Each tier needs `assets/monsters/tier_N.png` plus `tier_N_blink_1..3.png`, all exactly the same pixel size (transparent background, centred, max 768px); missing blink frames just disable blinking. `GameAudio` generates placeholder sounds in code; dropping files like `pop.ogg` or `music.ogg` into `assets/audio/` replaces them. Tier sizes follow `docs/size_chart.png`.
