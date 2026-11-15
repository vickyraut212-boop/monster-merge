/* Loads the real Godot build from the packaged files: engine.gz.wasm (gunzipped in
   the browser) and data.part0..N.wasm (joined back into index.pck). Godot then runs unchanged.
   Also tells the portfolio page about loading progress and when the game is live. */
(function () {
  var PARTS = window.MM_PCK_PARTS || 1;
  var realFetch = window.fetch.bind(window);
  function tell(msg) { try { parent.postMessage(Object.assign({ mm: true }, msg), "*"); } catch (e) {} }

  function wasmResponse() {
    return realFetch("engine.gz.wasm").then(function (r) {
      if (!r.ok) throw new Error("Could not load the game (wasm).");
      var body = r.body.pipeThrough(new DecompressionStream("gzip"));
      return new Response(body, { headers: { "Content-Type": "application/wasm" } });
    });
  }
  function pckResponse() {
    var urls = [];
    for (var i = 0; i < PARTS; i++) urls.push("data.part" + i + ".wasm");
    return Promise.all(urls.map(function (u) {
      return realFetch(u).then(function (r) {
        if (!r.ok) throw new Error("Could not load the game data.");
        return r.arrayBuffer();
      });
    })).then(function (bufs) {
      return new Response(new Blob(bufs), { headers: { "Content-Type": "application/octet-stream" } });
    });
  }
  window.fetch = function (input, init) {
    var url = typeof input === "string" ? input : (input && input.url) || "";
    var name = url.split("?")[0].split("/").pop();
    if (name === "index.wasm") return wasmResponse();
    if (name === "index.pck") return pckResponse();
    return realFetch(input, init);
  };
  window.MM_TELL = tell;
})();
