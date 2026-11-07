// The game API as a Hono app. Hono runs on Deno, Node, Bun, Cloudflare
// Workers and more, and this file only depends on Hono and the interfaces in
// types.ts, so it is not tied to Supabase.
//
// Routes (under basePath, "/api" on Supabase = /functions/v1/api/...):
//   GET  /health     -> { ok: true }
//   POST /scores     -> submit a run   { score, duration_ms, drops }
//   PUT  /me/name    -> change name    { name }
// Signed-in routes need "Authorization: Bearer <player access token>".
// Errors are always JSON: { error: "message" } with a 4xx/5xx status.

import { Hono, type Context, type MiddlewareHandler } from "npm:hono@4.6.14";
import { ApiError, type AuthVerifier, type LeaderboardStore } from "./types.ts";
import { changeName, parseRun, submitScore } from "./leaderboard.ts";

export interface ApiDeps {
  store: LeaderboardStore;
  auth: AuthVerifier;
  /** CORS headers for every response (the Web build runs in a browser). */
  corsHeaders: Record<string, string>;
}

type Env = { Variables: { playerId: string } };

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** The request body as a JSON object, or ApiError(400). */
async function readBody(c: Context): Promise<Record<string, unknown>> {
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    throw new ApiError(400, "Body must be JSON.");
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new ApiError(400, "Body must be a JSON object.");
  }
  return body as Record<string, unknown>;
}

export function createApp(deps: ApiDeps, basePath = "/api") {
  const app = new Hono<Env>().basePath(basePath);

  // CORS: answer the browser's preflight, and add the headers to every
  // response, including errors and 404s.
  app.use("*", async (c, next) => {
    if (c.req.method === "OPTIONS") {
      return new Response("ok", { headers: deps.corsHeaders });
    }
    await next();
    for (const [name, value] of Object.entries(deps.corsHeaders)) {
      c.res.headers.set(name, value);
    }
  });

  // Signed-in player only. Sets c.get("playerId").
  const requirePlayer: MiddlewareHandler<Env> = async (c, next) => {
    const token = (c.req.header("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const playerId = token ? await deps.auth.playerIdFromToken(token) : null;
    if (!playerId) throw new ApiError(401, "Not signed in.");
    c.set("playerId", playerId);
    await next();
  };

  app.get("/health", (c) => c.json({ ok: true }));

  app.post("/scores", requirePlayer, async (c) => {
    const run = parseRun(await readBody(c));
    return c.json(await submitScore(deps.store, c.get("playerId"), run));
  });

  app.put("/me/name", requirePlayer, async (c) => {
    const body = await readBody(c);
    return c.json(await changeName(deps.store, c.get("playerId"), body.name));
  });

  app.notFound(() => jsonResponse({ error: "Not found." }, 404));

  app.onError((err) => {
    if (err instanceof ApiError) return jsonResponse({ error: err.message }, err.status);
    console.error(err);
    return jsonResponse({ error: "Server error." }, 500);
  });

  return app;
}
