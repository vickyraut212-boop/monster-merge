// Shared CORS handling for every Edge Function.
//
// The Godot Web export runs in a browser on GitHub Pages, so each function must
// answer the browser's OPTIONS preflight and add these headers to every response.
// Native builds (desktop/mobile) ignore CORS, so this is harmless there.
//
// Usage inside a function:
//   import { corsHeaders, handleCors } from "../_shared/cors.ts";
//   Deno.serve(async (req) => {
//     const preflight = handleCors(req);
//     if (preflight) return preflight;
//     ...
//     return new Response(JSON.stringify(body), {
//       headers: { ...corsHeaders, "Content-Type": "application/json" },
//     });
//   });

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
};

/** Returns a ready response for an OPTIONS preflight, or null for real requests. */
export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}
