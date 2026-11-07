// Shared helpers for Edge Functions: the service-role client, the signed-in
// caller, and JSON responses with CORS headers.
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by Supabase into
// every Edge Function (locally and hosted). The service-role key bypasses RLS,
// so it must only ever be used here, never in the game.

import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "./cors.ts";

let admin: SupabaseClient | null = null;

/** Service-role client (bypasses RLS). */
export function adminClient(): SupabaseClient {
  if (!admin) {
    admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  }
  return admin;
}

/**
 * The player who sent the request, from `Authorization: Bearer <access_token>`.
 * Verified with Supabase Auth, so this works whether or not the gateway checks
 * the JWT (verify_jwt is off for these functions in config.toml). Anonymous
 * players are real users here.
 */
export async function getCaller(req: Request): Promise<User | null> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await adminClient().auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function error(message: string, status: number): Response {
  return json({ error: message }, status);
}

/** Parses the JSON body, or returns null if it is not a JSON object. */
export async function readBody(req: Request): Promise<Record<string, unknown> | null> {
  try {
    const body = await req.json();
    return body && typeof body === "object" && !Array.isArray(body) ? body : null;
  } catch {
    return null;
  }
}

/**
 * 1-based rank for a best score: players with a higher score, plus players
 * with the same score who reached it earlier, come first. Also returns how
 * many players have a score above zero.
 */
export async function rankOf(
  bestScore: number,
  achievedAt: string | null,
): Promise<{ rank: number; total_players: number }> {
  const db = adminClient();
  const higher = await db
    .from("leaderboard_entries")
    .select("player_id", { count: "exact", head: true })
    .gt("best_score", bestScore);
  let ahead = higher.count ?? 0;
  if (achievedAt) {
    const tiedEarlier = await db
      .from("leaderboard_entries")
      .select("player_id", { count: "exact", head: true })
      .eq("best_score", bestScore)
      .lt("achieved_at", achievedAt);
    ahead += tiedEarlier.count ?? 0;
  }
  const total = await db
    .from("leaderboard_entries")
    .select("player_id", { count: "exact", head: true })
    .gt("best_score", 0);
  return { rank: ahead + 1, total_players: total.count ?? 0 };
}
