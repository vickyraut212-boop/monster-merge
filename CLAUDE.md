# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

Monorepo: `game/` is the Godot project, `supabase/` is the backend (config, migrations, Edge Functions), `docs/ARCHITECTURE.md` describes the backend design, and `.github/workflows/` holds CI. All game paths below are relative to `game/`.

## Game

"Monster Merge": a 2D drop-and-merge physics puzzle (Suika-style) in Godot 4.7 (standard build, GDScript, GL Compatibility renderer, portrait 720x1280). There is no build step, linter or test suite. Run it by opening `game/project.godot` in the Godot editor and pressing F5 (main scene is `res://scenes/main.tscn`). Headless/CLI runs, if needed: `godot --path game` (editor binary must be on PATH). On start, `main.gd` warns in the Output panel if any tier sprite is missing.

`scenes/main.tscn` wires four children together and `scripts/main.gd` is the coordinator:
- `Jar` (`jar.gd`) – walls, floor and the danger line; emits `game_over` when a monster stays above the line for 2 s.
- `Dropper` (`dropper.gd`) – the alien ship; aims, emits `dropped(tier, position)`, and owns the drop-order rule (first drop is Tier 1, then random up to `TierData.MAX_DROP_TIER`).
- `Monsters` node – container for spawned `Monster` bodies (`monster.gd`, created in code via `Monster.new()` + `setup(tier)`, not from a scene).
- `HUD` (`hud.gd`, `scenes/hud.tscn`) – score/best, Next preview, settings pop-up, power-ups, game-over panel; communicates via signals (`play_again_pressed`, `restart_pressed`).

Merge flow: a `Monster` emits `touched_same_tier(a, b)` -> `main.gd` sets `is_merging` on both (guards double merges) and defers `_merge()` because physics bodies can't be freed mid-step -> both are removed and a next-tier monster spawns at the midpoint with half the averaged velocity. Merging two Tier 7 bosses spawns nothing and awards `BOSS_MERGE_BONUS`. Restart is `get_tree().reload_current_scene()`; best score persists in `user://best_score.cfg`.

Autoloads (`project.godot`): `TierData` (`tier_data.gd`), `GameAudio` (`game_audio.gd`) and `Backend` (`backend/backend.gd`, the Supabase client: anonymous sign-in, score submit, leaderboard; URL and key in `backend/backend_config.gd`, and it stays offline while they're empty). On game over, `main.gd` sends the run (score, duration, drop count) to `POST /functions/v1/api/scores`. The leaderboard pop-up is `scenes/leaderboard.tscn` (`leaderboard_popup.gd`). Changing points, bonuses or `MAX_DROP_TIER` may require raising `MAX_POINTS_PER_DROP` in `supabase/functions/api/leaderboard.ts`. `TierData` is the single source of truth for tuning: collider radius derives from `BOSS_RADIUS * SIZE_CHART_RATIO * READABILITY_BOOST`, and sprites are auto-scaled to match collider width, so swapping art never changes gameplay size. Points/bonus per tier, `MAX_DROP_TIER` and `BOSS_MERGE_BONUS` also live there. Other helpers: `blink_sprite.gd` (blink animation timing), `shaker.gd` (phone shake / on-screen SHAKE jostles monsters), `intro.gd` (opening animation, first launch only), `space_background.gd` (decorative planets/stars, never over the jar).

Each tier needs `assets/monsters/tier_N.png` plus `tier_N_blink_1..3.png`, all exactly the same pixel size (transparent background, centred, max 768px); missing blink frames just disable blinking. `GameAudio` generates placeholder sounds in code; dropping files like `pop.ogg` or `music.ogg` into `assets/audio/` replaces them. Tier sizes follow `docs/size_chart.png`.

`game/export_presets.cfg` has the "Web" preset used by CI. It must stay single-threaded (`variant/thread_support=false`) because GitHub Pages can't send cross-origin isolation headers.

## Backend (Supabase)

The Supabase CLI runs through `npx supabase` (pinned to 3.0.0 in CI) and needs Docker for the local stack (`npx supabase start`, `npx supabase db reset`). Migrations go in `supabase/migrations/` (create them with `npx supabase migration new <name>`). Seed data meant for the hosted DB goes in a migration, because `db push` doesn't run `seed.sql`. `public.test_items` is a smoke-test table and can be dropped once real tables exist.

Rules (see `docs/ARCHITECTURE.md`):
- Godot talks to Supabase with plain `HTTPRequest` calls to `/auth/v1/`, `/rest/v1/` and `/functions/v1/`. No supabase-js and no plugins.
- Public data: RLS `select` for `anon` with `using (true)`, and no client writes.
- Private data: `to authenticated` with `auth.uid() = id`, and no `anon` policy.
- Currency, rewards and progression are written only by Edge Functions using the service-role key. Use Edge Functions for these, not SQL RPCs.
- Every Edge Function must use `supabase/functions/_shared/cors.ts`, because the Web build runs in a browser.
- Server endpoints go in the single Hono function `supabase/functions/api/` as routes, not as new functions. Keep `types.ts`, `leaderboard.ts` and `app.ts` free of Supabase code; Supabase access belongs only in `supabase_adapters.ts` and `index.ts`, so the API can move to another provider. Add `PUT`/`DELETE` routes only together with the matching CORS methods.
- Never commit real keys. Only the publishable/anon key may appear in game config.

CI: `deploy-supabase.yml` (`supabase/**`) and `deploy-game-pages.yml` (`game/**`) deploy on every push to `main` and on manual runs. On pull requests the Pages workflow only builds (to check the export works) and skips the deploy; the `github-pages` environment only accepts deploys from `main`.
