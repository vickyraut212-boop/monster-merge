// The Daily Ranking: each player's best run of the current day (UTC), best
// first. Pure logic on top of LeaderboardStore, no provider code.
//
// Demo players (is_bot, seeded by a migration) never submit runs. So the
// board looks alive, each one gets a made-up score for the day that is the
// same for everyone who looks: a stable hash of (player, day) decides whether
// they "play" that day, at what minute, and how well (a share of their
// all-time best). They only appear once that minute has passed, so the board
// fills up through the day like a real one.

import type { LeaderboardStore, PlayerCard } from "./types.ts";

/** Share of demo players who play on a given day. */
export const DEMO_PLAY_CHANCE = 0.6;
/** Their daily best is this range of their all-time best. */
const DEMO_SCORE_MIN = 0.3;
const DEMO_SCORE_MAX = 0.95;

const DAY_MS = 24 * 60 * 60 * 1000;

export interface DailyEntry {
  player_id: string;
  display_name: string;
  /** Today's best score (same field name as the all-time board). */
  best_score: number;
}

export interface DailyBoard {
  day: string; // "2026-11-21"
  resets_at: string; // ISO time of the next reset (next UTC midnight)
  entries: DailyEntry[];
}

/** A number in [0, 1) from a string, stable everywhere (FNV-1a + mixing). */
export function unitHash(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  h ^= h >>> 16;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  h = Math.imul(h, 0xc2b2ae35);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

/** A demo player's score for `day`, or null if they haven't played (yet). */
export function demoDailyScore(
  bot: PlayerCard,
  day: string,
  msIntoDay: number,
): { score: number; at_ms: number } | null {
  if (bot.best_score <= 0) return null;
  if (unitHash(`${bot.player_id}|${day}|plays`) >= DEMO_PLAY_CHANCE) return null;
  const at = Math.floor(unitHash(`${bot.player_id}|${day}|time`) * DAY_MS);
  if (at > msIntoDay) return null;
  const share = DEMO_SCORE_MIN + (DEMO_SCORE_MAX - DEMO_SCORE_MIN) * unitHash(`${bot.player_id}|${day}|score`);
  return { score: Math.max(1, Math.round(bot.best_score * share)), at_ms: at };
}

export async function getDailyBoard(
  store: LeaderboardStore,
  now = new Date(),
  limit = 100,
): Promise<DailyBoard> {
  const start = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const day = new Date(start).toISOString().slice(0, 10);
  const msIntoDay = now.getTime() - start;

  const [runs, bots] = await Promise.all([
    store.bestRunsSince(new Date(start).toISOString(), limit),
    store.demoPlayers(),
  ]);
  const cards = await store.playerCards(runs.map((r) => r.player_id));
  const names = new Map(cards.map((c) => [c.player_id, c.display_name]));

  const rows: { entry: DailyEntry; at: number }[] = [];
  for (const run of runs) {
    const name = names.get(run.player_id);
    if (name === undefined) continue;
    rows.push({
      entry: { player_id: run.player_id, display_name: name, best_score: run.score },
      at: Date.parse(run.at) - start,
    });
  }
  for (const bot of bots) {
    const played = demoDailyScore(bot, day, msIntoDay);
    if (!played) continue;
    rows.push({
      entry: { player_id: bot.player_id, display_name: bot.display_name, best_score: played.score },
      at: played.at_ms,
    });
  }
  // Higher score first; on a tie, whoever got there first.
  rows.sort((a, b) => b.entry.best_score - a.entry.best_score || a.at - b.at);

  return {
    day,
    resets_at: new Date(start + DAY_MS).toISOString(),
    entries: rows.slice(0, limit).map((r) => r.entry),
  };
}
