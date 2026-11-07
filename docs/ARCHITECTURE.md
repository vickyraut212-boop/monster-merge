# Architecture

Monster Merge is a Godot 4.7 game with Supabase as its whole backend: auth, Postgres, storage and Edge Functions. There is no custom server.

## Repository layout

| Path | What it holds |
|---|---|
| `game/` | The Godot project (`game/project.godot`). Exported to Web for GitHub Pages. |
| `supabase/config.toml` | Local Supabase stack settings: Data API, Auth (anonymous sign-ins on), Storage. |
| `supabase/migrations/` | SQL migrations, applied in filename order. Currently only `test_items`, a public read-only smoke-test table with seed rows. |
| `supabase/functions/` | Edge Functions (Deno/TypeScript), one folder each. `_shared/` holds shared code and is never deployed on its own. |
| `.github/workflows/` | `deploy-supabase.yml` (migrations + functions) and `deploy-game-pages.yml` (Web export to Pages). |

## How the game talks to Supabase

Godot uses plain HTTPS with `HTTPRequest`. There is no supabase-js and no plugin. Every request sends the project's **publishable (anon) key** in the `apikey` header. Requests from a signed-in player also send `Authorization: Bearer <access_token>`.

| Purpose | Endpoint |
|---|---|
| Sign in (anonymous or password), refresh tokens | `/auth/v1/` |
| Read data (Data API / PostgREST) | `/rest/v1/` |
| Anything that changes currency, rewards or progression | `/functions/v1/<name>` |

The planned client is one autoload in `game/scripts/backend/` that wraps these calls. It is not written yet.

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
| `deploy-game-pages.yml` | `game/**` | Exports the game to Web with headless Godot 4.7 (keep `GODOT_VERSION` in sync with the editor), then publishes it to GitHub Pages. Pull requests and manual runs (by default) only build, without publishing. |

Seed data that must reach the hosted database goes in a migration. `supabase db push` does not run `seed.sql`.

The Web export is single-threaded (`variant/thread_support=false`). GitHub Pages cannot send the cross-origin isolation headers that a threaded build needs.

## Secrets

| Where | Name | Get it from |
|---|---|---|
| GitHub Actions secret | `SUPABASE_ACCESS_TOKEN` | supabase.com, then Account, then Access Tokens |
| GitHub Actions secret | `SUPABASE_PROJECT_REF` | Project Settings, then General, then Project ID |
| GitHub Actions secret | `SUPABASE_DB_PASSWORD` | The password set when the project was created (can be reset in Project Settings, then Database) |
| Game config (later step) | Project URL, publishable key | Project Settings, then API Keys / Data API |
