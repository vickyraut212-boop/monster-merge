// POST /functions/v1/set-display-name
// Body: { "name": string }
// Auth: Authorization: Bearer <player access token>
//
// Sets the caller's leaderboard name (3-16 letters, numbers, spaces, _ or -).
// Creates their entry with a best score of 0 if they have not submitted yet.
// Returns { display_name } or { error } with status 400 for a rejected name.

import { handleCors } from "../_shared/cors.ts";
import { adminClient, error, getCaller, json, readBody } from "../_shared/supabase.ts";
import { validateName } from "../_shared/names.ts";

Deno.serve(async (req) => {
  const preflight = handleCors(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return error("Use POST.", 405);

  const user = await getCaller(req);
  if (!user) return error("Not signed in.", 401);

  const body = await readBody(req);
  if (!body) return error("Body must be a JSON object.", 400);
  const result = validateName(body.name);
  if ("error" in result) return error(result.error, 400);

  const { error: upsertError } = await adminClient()
    .from("leaderboard_entries")
    .upsert({ player_id: user.id, display_name: result.name }, { onConflict: "player_id" });
  if (upsertError) return error("Could not save the name.", 500);

  return json({ display_name: result.name });
});
