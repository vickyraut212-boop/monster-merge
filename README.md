# Monster Merge

A 2D drop-and-merge physics puzzle made with Godot 4.7, with Supabase as the backend.

| Folder | What it is |
|---|---|
| [`game/`](game/) | The Godot project. See [game/README.md](game/README.md) for how to open and play it. |
| [`supabase/`](supabase/) | Supabase config, database migrations and Edge Functions. |
| [`docs/`](docs/) | [ARCHITECTURE.md](docs/ARCHITECTURE.md): layout, access rules, deploys and secrets. |
| [`.github/workflows/`](.github/workflows/) | CI: deploy Supabase, and publish the Web build to GitHub Pages. |

## Run the game
Open `game/project.godot` in Godot 4.7 (standard build) and press **F5**.

## Run Supabase locally
You need Docker Desktop running and Node.js. The Supabase CLI runs through `npx`.

```powershell
npx supabase start      # local stack; Studio at http://127.0.0.1:54323
npx supabase db reset   # rebuild the local DB from supabase/migrations
npx supabase stop
```

Pushing to `main` deploys automatically: `supabase/**` changes go to the Supabase project and `game/**` changes go to GitHub Pages.
