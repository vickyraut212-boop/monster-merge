class_name BackendConfig
## Where the game finds Supabase. Fill both in from the Supabase dashboard:
##   SUPABASE_URL    - Project Settings > Data API > Project URL
##                     (local stack: "http://127.0.0.1:54321")
##   PUBLISHABLE_KEY - Project Settings > API Keys > publishable key
##                     (sb_publishable_..., or the legacy "anon" key)
##                     (local stack: printed by `npx supabase status`)
##
## Only the publishable/anon key may ever go here: it is public by design and
## Row Level Security protects the data. NEVER put the service-role or secret
## key in the game.
##
## While either value is empty, online features are switched off and the game
## plays fully offline (the leaderboard shows "not set up yet").
##
## API_URL is the game API (supabase/functions/api, a Hono app). It is its
## own setting so the API can move to another host without touching the rest.

const SUPABASE_URL := "https://ijczhtwqvoffjpkjiaum.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_zf2h2NDkK1wjxIPDpb8lWw_JV7_xbVs"
const API_URL := SUPABASE_URL + "/functions/v1/api"
