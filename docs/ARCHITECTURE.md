# Architecture

Monster Merge is a Godot 4.7 game with Supabase as its whole backend: auth, Postgres, storage and Edge Functions. There is no custom server.

## Repository layout

| Path | What it holds |
|---|---|
| `game/` | The Godot project (`game/project.godot`). Exported to Web for GitHub Pages. |
| `supabase/config.toml` | Local Supabase stack settings: Data API, Auth (anonymous sign-ins on), Storage. |
| `supabase/migrations/` | SQL migrations, applied in filename order: `test_items` (smoke-test table) and the leaderboard tables. |
| `supabase/functions/` | Edge Functions (Deno/TypeScript), one folder each. `_shared/` holds shared code and is never deployed on its own. |
| `.github/workflows/` | `deploy-supabase.yml` (migrations + functions) and `deploy-game-pages.yml` (Web export to Pages). |

## How the game talks to Supabase

Godot uses plain HTTPS with `HTTPRequest`. There is no supabase-js and no plugin. Every request sends the project's **publishable (anon) key** in the `apikey` header. Requests from a signed-in player also send `Authorization: Bearer <access_token>`.

| Purpose | Endpoint |
|---|---|
| Sign in (anonymous or password), refresh tokens | `/auth/v1/` |
| Read data (Data API / PostgREST) | `/rest/v1/` |
| Anything that changes currency, rewards or progression | `/functions/v1/<name>` |

The client is the `Backend` autoload (`game/scripts/backend/backend.gd`), with the project URL and publishable key in `game/scripts/backend/backend_config.gd`. While either value is empty, the game runs fully offline. `Backend` signs each player in as an anonymous user on first use and keeps the session in `user://session.cfg`. Its methods answer through signals (`score_submitted`, `leaderboard_loaded`, `name_changed`) rather than `await`, so a scene reload mid-request is harmless. A score that can't be sent is saved and retried on the next launch.

## Leaderboard

An all-time board: each player's best score, top 100.

| Piece | What it does |
|---|---|
| `public.leaderboard_entries` | One row per player: `display_name`, `best_score`, `achieved_at`. Public read-only. `anon` and `authenticated` can read only `player_id`, `display_name`, `best_score` and `achieved_at`. There are no write privileges or policies. |
| `public.score_runs` | Every submitted run (`score`, `duration_ms`, `drops`). Service role only. Use it to audit suspicious scores and to build weekly or daily boards later. |
| `functions/submit-score` | `POST {score, duration_ms, drops}`. Rejects impossible runs (more than 50 points per drop, faster than 0.4 s per drop) and limits each player to one submit every 5 s. Logs the run, raises the best score, and returns `{display_name, best_score, is_new_best, rank, total_players}`. A new player gets a random name like "Bouncy Blob 4821". |
| `functions/set-display-name` | `POST {name}`. Accepts 3–16 letters, digits, spaces, `_` or `-`, and checks a small blocklist (`_shared/names.ts`). |
| Game | Reads the top 100 straight from `/rest/v1/leaderboard_entries` with the publishable key. The game-over panel shows the world rank. The pop-up is `scenes/leaderboard.tscn`, opened by the HUD's TOP button or by the game-over Leaderboard button. |

Ranking is by `best_score` descending. On a tie, the earlier `achieved_at` ranks higher. Scores are computed on the device, so the server checks only catch impossible runs. If points, bonuses, `MAX_DROP_TIER` or power-ups change, update `MAX_POINTS_PER_DROP` in `submit-score/index.ts` to match.

Both functions have `verify_jwt = false` in `config.toml`. They check the caller themselves with `auth.getUser()` (`_shared/supabase.ts`), which also works with the newer asymmetric JWT signing keys.

## Access rules

1. **Public data** (leaderboards, public scores): RLS allows `select` to `anon` and `authenticated` with `using (true)`. Clients can never write to these tables.
2. **Private data** (profile, avatar, settings): RLS policies are `to authenticated` with `auth.uid() = id`. There is no `anon` policy.
3. **Currency, rewards, progression:** the client never writes these tables. It calls an Edge Function with a claim, such as "I finished a run with score X". The function validates the claim and writes with the service-role key, which bypasses RLS. That key exists only inside Edge Functions.

The publishable key is safe to ship in the game because RLS does the protecting. The service-role/secret key must never appear in `game/` or in git.

## Edge Functions and the Web build

The Web build runs in a browser, so every function must handle the `OPTIONS` preflight and return CORS headers. Use `supabase/functions/_shared/cors.ts` for this.

## Deploy pipeline

Both workflows run on a push to `main` that touches their folder. You can also start them from the Actions tab with "Run workflow".

| Workflow | Runs when these change | What it does |
|---|---|---|
| `deploy-supabase.yml` | `supabase/**` | Links the project, runs `supabase db push`, deploys any Edge Functions |
| `deploy-game-pages.yml` | `game/**` | Exports the game to Web with headless Godot 4.7 (keep `GODOT_VERSION` in sync with the editor), then publishes it to GitHub Pages. Also runs and deploys on pull requests, so a PR replaces the live site with its version. |

Seed data that must reach the hosted database goes in a migration. `supabase db push` does not run `seed.sql`.

The Web export is single-threaded (`variant/thread_support=false`). GitHub Pages cannot send the cross-origin isolation headers that a threaded build needs.

## Secrets

| Where | Name | Get it from |
|---|---|---|
| GitHub Actions secret | `SUPABASE_ACCESS_TOKEN` | supabase.com, then Account, then Access Tokens |
| GitHub Actions secret | `SUPABASE_PROJECT_REF` | Project Settings, then General, then Project ID |
| GitHub Actions secret | `SUPABASE_DB_PASSWORD` | The password set when the project was created (can be reset in Project Settings, then Database) |
| `game/scripts/backend/backend_config.gd` | `SUPABASE_URL`, `PUBLISHABLE_KEY` | Project Settings, then Data API (URL) and API Keys (publishable key) |
