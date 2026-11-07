// POST /functions/v1/submit-score
// Body: { "score": int, "duration_ms": int, "drops": int }
// Auth: Authorization: Bearer <player access token> (anonymous players are fine)
//
// Logs the run, raises the player's all-time best if this run beat it (creating
// their leaderboard entry with a random name on their first run), and returns
//   { display_name, best_score, is_new_best, rank, total_players }
// rank is null while the player's best score is still 0.

import { handleCors } from "../_shared/cors.ts";
import { adminClient, error, getCaller, json, rankOf, readBody } from "../_shared/supabase.ts";
import { randomName } from "../_shared/names.ts";

// Plausibility limits. The score is computed on the player's device, so these
// cannot stop every cheat; they reject obviously impossible runs.
//
// MAX_POINTS_PER_DROP: a drop adds at most a Tier 3 monster (4 Tier 1 "units",
// see TierData.MAX_DROP_TIER). Merging one unit all the way to a boss and then
// through the boss merge earns about 11.3 points with the current TierData
// points and bonuses, so one drop is worth at most ~45 points. Raise this if
// points, bonuses or MAX_DROP_TIER grow, or once power-ups award points.
const MAX_POINTS_PER_DROP = 50;
const BOSS_MERGE_BONUS = 100; // headroom, matches TierData.BOSS_MERGE_BONUS
// The dropper has a 0.6 s cooldown between drops; allow some timer slack.
const MIN_MS_PER_DROP = 400;
const MAX_SCORE = 10_000_000;
const MAX_DROPS = 200_000;
// One submit per player per this many milliseconds.
const SUBMIT_COOLDOWN_MS = 5_000;

function isCount(value: unknown, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= max;
}

Deno.serve(async (req) => {
  const preflight = handleCors(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return error("Use POST.", 405);

  const user = await getCaller(req);
  if (!user) return error("Not signed in.", 401);

  const body = await readBody(req);
  if (!body) return error("Body must be a JSON object.", 400);
  const { score, duration_ms, drops } = body;
  if (!isCount(score, MAX_SCORE) || !isCount(duration_ms, 2_000_000_000) || !isCount(drops, MAX_DROPS)) {
    return error("score, duration_ms and drops must be non-negative integers.", 400);
  }
  if (score > drops * MAX_POINTS_PER_DROP + BOSS_MERGE_BONUS) {
    return error("Score is not possible for that many drops.", 400);
  }
  if (drops > 1 && duration_ms < (drops - 1) * MIN_MS_PER_DROP) {
    return error("Run is too fast for that many drops.", 400);
  }

  const db = adminClient();
  const now = new Date();
  const nowIso = now.toISOString();

  const { data: entry, error: readError } = await db
    .from("leaderboard_entries")
    .select("display_name, best_score, achieved_at, last_submit_at")
    .eq("player_id", user.id)
    .maybeSingle();
  if (readError) return error("Could not read the leaderboard.", 500);

  if (entry?.last_submit_at && now.getTime() - Date.parse(entry.last_submit_at) < SUBMIT_COOLDOWN_MS) {
    return error("Too many submissions, try again in a few seconds.", 429);
  }

  const { error: runError } = await db
    .from("score_runs")
    .insert({ player_id: user.id, score, duration_ms, drops });
  if (runError) return error("Could not save the run.", 500);

  let displayName: string;
  let bestScore: number;
  let achievedAt: string | null;
  let isNewBest: boolean;

  if (!entry) {
    displayName = randomName();
    bestScore = score;
    achievedAt = score > 0 ? nowIso : null;
    isNewBest = score > 0;
    const { error: insertError } = await db.from("leaderboard_entries").insert({
      player_id: user.id,
      display_name: displayName,
      best_score: bestScore,
      achieved_at: achievedAt,
      last_submit_at: nowIso,
    });
    if (insertError) return error("Could not save the score.", 500);
  } else {
    displayName = entry.display_name;
    isNewBest = score > entry.best_score;
    bestScore = isNewBest ? score : entry.best_score;
    achievedAt = isNewBest ? nowIso : entry.achieved_at;
    const update: Record<string, unknown> = { last_submit_at: nowIso };
    if (isNewBest) {
      update.best_score = bestScore;
      update.achieved_at = achievedAt;
    }
    const { error: updateError } = await db
      .from("leaderboard_entries")
      .update(update)
      .eq("player_id", user.id);
    if (updateError) return error("Could not save the score.", 500);
  }

  const ranking = bestScore > 0 ? await rankOf(bestScore, achievedAt) : null;

  return json({
    display_name: displayName,
    best_score: bestScore,
    is_new_best: isNewBest,
    rank: ranking?.rank ?? null,
    total_players: ranking?.total_players ?? 0,
  });
});
