// Provider-neutral types for the game API. Nothing in this file (or in app.ts
// and leaderboard.ts) knows about Supabase: the database and the auth check
// are passed in as the two interfaces below. To move to another provider,
// write new implementations of LeaderboardStore and AuthVerifier (see
// supabase_adapters.ts) and a new entry file (see index.ts).

/** One finished game, as sent by the client. */
export interface Run {
  score: number;
  duration_ms: number;
  drops: number;
}

/** A player's row on the all-time leaderboard. */
export interface Entry {
  display_name: string;
  best_score: number;
  achieved_at: string | null; // ISO time the best score was reached
  last_submit_at: string | null; // ISO time of the last submitted run
}

export interface Ranking {
  rank: number; // 1-based
  total_players: number; // players with a score above zero
}

/** A player's best run since some moment (for the Daily Ranking). */
export interface RunBest {
  player_id: string;
  score: number;
  at: string; // ISO time of that run
}

/** The public face of a player: name, all-time best, demo flag. */
export interface PlayerCard {
  player_id: string;
  display_name: string;
  best_score: number;
  is_bot: boolean;
}

/** Where leaderboard data lives. Implementations throw on storage errors. */
export interface LeaderboardStore {
  getEntry(playerId: string): Promise<Entry | null>;
  insertRun(playerId: string, run: Run): Promise<void>;
  createEntry(playerId: string, entry: Entry): Promise<void>;
  updateEntry(playerId: string, patch: Partial<Entry>): Promise<void>;
  /** Sets the name, creating the entry (best score 0) if it does not exist. */
  setName(playerId: string, name: string): Promise<void>;
  /** Rank for a best score: higher scores first, then earlier achieved_at. */
  rankOf(bestScore: number, achievedAt: string | null): Promise<Ranking>;
  /**
   * Each player's best run (score above zero) submitted at or after sinceIso,
   * best first, at most `limit` players.
   */
  bestRunsSince(sinceIso: string, limit: number): Promise<RunBest[]>;
  /** Name and all-time best for these players (unknown ids are skipped). */
  playerCards(playerIds: string[]): Promise<PlayerCard[]>;
  /** Every demo player (is_bot), see migrations/*_leaderboard_demo_players.sql. */
  demoPlayers(): Promise<PlayerCard[]>;
}

/** Turns a client's access token into a player id, or null if invalid. */
export interface AuthVerifier {
  playerIdFromToken(token: string): Promise<string | null>;
}

/** An error the client should see, with its HTTP status. */
export class ApiError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}
