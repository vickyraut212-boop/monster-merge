// Supabase Edge Function entry for the game API: /functions/v1/api/...
// Wires the provider-neutral Hono app (app.ts) to Supabase (supabase_adapters.ts)
// and starts it with Deno.serve. Routes are listed in app.ts.
//
// Another provider would only need its own version of this file, e.g. on
// Cloudflare Workers: `export default createApp({...}, "/api")`, or on Node:
// `serve(createApp({...}))` from @hono/node-server.

import { corsHeaders } from "../_shared/cors.ts";
import { createApp } from "./app.ts";
import { serviceRoleClient, supabaseAuth, supabaseStore } from "./supabase_adapters.ts";

const db = serviceRoleClient();

const app = createApp({
  store: supabaseStore(db),
  auth: supabaseAuth(db),
  corsHeaders,
});

Deno.serve(app.fetch);
