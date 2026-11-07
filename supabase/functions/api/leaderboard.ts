// Leaderboard rules: validating runs, keeping each player's best score, and
// player names. Pure logic on top of LeaderboardStore, no provider or HTTP
// framework code, so it moves unchanged to any other backend.

import { ApiError, type LeaderboardStore, type Run } from "./types.ts";
import { randomName, validateName } from "../_shared/names.ts";

// Plausibility limits. The score is computed on the player's device, so these
// cannot stop every cheat; they reject obviously impossible runs.
//
// MAX_POINTS_PER_DROP: a drop adds at most a Tier 3 monster (4 Tier 1 "units",
// see TierData.MAX_DROP_TIER). Merging one unit all the way to a boss and then
// through the boss merge earns about 11.3 points with the current TierData
// points and bonuses, so one drop is worth at most ~45 points. Raise this if
// points, bonuses or MAX_DROP_TIER grow, or once power-ups award points.
export const MAX_POINTS_PER_DROP = 50;
const BOSS_MERGE_BONUS = 100; // headroom, matches TierData.BOSS_MERGE_BONUS
// The dropper has a 0.6 s cooldown between drops; allow some timer slack.
export const MIN_MS_PER_DROP = 400;
const MAX_SCORE = 10_000_000;
const MAX_DROPS = 200_000;
const MAX_DURATION_MS = 2_000_000_000;
// One submit per player per this many milliseconds.
export const SUBMIT_COOLDOWN_MS = 5_000;

export interface SubmitResult {
  display_name: string;
  best_score: number;
  is_new_best: boolean;
  rank: number | null; // null while the best score is still 0
  total_players: number;
}

function isCount(value: unknown, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= max;
}

/** Checks a submitted body is a possible run. Throws ApiError(400) if not. */
export function parseRun(body: Record<string, unknown>): Run {
  const { score, duration_ms, drops } = body;
  if (!isCount(score, MAX_SCORE) || !isCount(duration_ms, MAX_DURATION_MS) || !isCount(drops, MAX_DROPS)) {
    throw new ApiError(400, "score, duration_ms and drops must be non-negative integers.");
  }
  if (score > drops * MAX_POINTS_PER_DROP + BOSS_MERGE_BONUS) {
    throw new ApiError(400, "Score is not possible for that many drops.");
  }
  if (drops > 1 && duration_ms < (drops - 1) * MIN_MS_PER_DROP) {
    throw new ApiError(400, "Run is too fast for that many drops.");
  }
  return { score, duration_ms, drops };
}

/**
 * Logs the run and raises the player's best score if it beat it, creating
 * their entry with a random name on their first run. Throws ApiError(429)
 * when the player submits again too soon.
 */
export async function submitScore(
  store: LeaderboardStore,
  playerId: string,
  run: Run,
  now = new Date(),
): Promise<SubmitResult> {
  const nowIso = now.toISOString();
  const entry = await store.getEntry(playerId);

  if (entry?.last_submit_at && now.getTime() - Date.parse(entry.last_submit_at) < SUBMIT_COOLDOWN_MS) {
    throw new ApiError(429, "Too many submissions, try again in a few seconds.");
  }

  await store.insertRun(playerId, run);

  let displayName: string;
  let bestScore: number;
  let achievedAt: string | null;
  let isNewBest: boolean;

  if (!entry) {
    displayName = randomName();
    bestScore = run.score;
    achievedAt = run.score > 0 ? nowIso : null;
    isNewBest = run.score > 0;
    await store.createEntry(playerId, {
      display_name: displayName,
      best_score: bestScore,
      achieved_at: achievedAt,
      last_submit_at: nowIso,
    });
  } else {
    displayName = entry.display_name;
    isNewBest = run.score > entry.best_score;
    bestScore = isNewBest ? run.score : entry.best_score;
    achievedAt = isNewBest ? nowIso : entry.achieved_at;
    await store.updateEntry(
      playerId,
      isNewBest
        ? { last_submit_at: nowIso, best_score: bestScore, achieved_at: achievedAt }
        : { last_submit_at: nowIso },
    );
  }

  const ranking = bestScore > 0 ? await store.rankOf(bestScore, achievedAt) : null;
  return {
    display_name: displayName,
    best_score: bestScore,
    is_new_best: isNewBest,
    rank: ranking?.rank ?? null,
    total_players: ranking?.total_players ?? 0,
  };
}

/** Validates and saves a new display name. Throws ApiError(400) if rejected. */
export async function changeName(
  store: LeaderboardStore,
  playerId: string,
  rawName: unknown,
): Promise<{ display_name: string }> {
  const result = validateName(rawName);
  if ("error" in result) throw new ApiError(400, result.error);
  await store.setName(playerId, result.name);
  return { display_name: result.name };
}
