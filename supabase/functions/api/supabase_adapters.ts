// The Supabase side of the game API: LeaderboardStore on Postgres (through
// supabase-js with the service-role key) and AuthVerifier on Supabase Auth.
// This is the only API file that knows about Supabase; another provider
// would replace just this file and index.ts.
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by Supabase into
// every Edge Function. The service-role key bypasses RLS, so it must only ever
// be used here, never in the game.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AuthVerifier, Entry, LeaderboardStore, Ranking, Run } from "./types.ts";

export function serviceRoleClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

/**
 * Checks the token with Supabase Auth, so this works whether or not the
 * gateway checks the JWT (verify_jwt is off for this function in config.toml).
 * Anonymous players are real users here.
 */
export function supabaseAuth(db: SupabaseClient): AuthVerifier {
  return {
    async playerIdFromToken(token) {
      const { data, error } = await db.auth.getUser(token);
      return error || !data.user ? null : data.user.id;
    },
  };
}

function check(error: { message: string } | null, what: string): void {
  if (error) throw new Error(`${what}: ${error.message}`);
}

export function supabaseStore(db: SupabaseClient): LeaderboardStore {
  const entries = () => db.from("leaderboard_entries");
  // Row count only, no rows returned.
  const countRows = () => entries().select("player_id", { count: "exact", head: true });

  function counted(result: { count: number | null; error: { message: string } | null }): number {
    check(result.error, "count leaderboard");
    return result.count ?? 0;
  }

  return {
    async getEntry(playerId) {
      const { data, error } = await entries()
        .select("display_name, best_score, achieved_at, last_submit_at")
        .eq("player_id", playerId)
        .maybeSingle();
      check(error, "read entry");
      return (data as Entry | null) ?? null;
    },

    async insertRun(playerId, run: Run) {
      const { error } = await db.from("score_runs").insert({ player_id: playerId, ...run });
      check(error, "save run");
    },

    async createEntry(playerId, entry) {
      const { error } = await entries().insert({ player_id: playerId, ...entry });
      check(error, "create entry");
    },

    async updateEntry(playerId, patch) {
      const { error } = await entries().update(patch).eq("player_id", playerId);
      check(error, "update entry");
    },

    async setName(playerId, name) {
      const { error } = await entries()
        .upsert({ player_id: playerId, display_name: name }, { onConflict: "player_id" });
      check(error, "save name");
    },

    async rankOf(bestScore, achievedAt): Promise<Ranking> {
      let ahead = counted(await countRows().gt("best_score", bestScore));
      if (achievedAt) {
        ahead += counted(await countRows().eq("best_score", bestScore).lt("achieved_at", achievedAt));
      }
      const total = counted(await countRows().gt("best_score", 0));
      return { rank: ahead + 1, total_players: total };
    },
  };
}
