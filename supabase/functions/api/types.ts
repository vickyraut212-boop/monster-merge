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
