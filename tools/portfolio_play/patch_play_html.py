#!/usr/bin/env python3
"""Adds the loader shim and portfolio styling to Godot's exported index.html.
Usage: patch-play-html.py <exported index.html> <output index.html> <pck part count>"""
import sys

src, dest, parts = sys.argv[1], sys.argv[2], int(sys.argv[3])
html = open(src, encoding="utf-8").read()

style = """
<style>
body { background: #1e1a29 !important; }
#status { background: radial-gradient(120% 80% at 50% 30%, #3a2a5c 0%, #1e1a29 70%) !important; }
#status-splash { display: none !important; }
#status-progress { -webkit-appearance: none; appearance: none; height: 12px; width: 60% !important;
  bottom: 46% !important; border: 0; border-radius: 99px; background: rgba(255,255,255,.12); overflow: hidden; }
#status-progress::-webkit-progress-bar { background: rgba(255,255,255,.12); border-radius: 99px; }
#status-progress::-webkit-progress-value { background: linear-gradient(90deg, #ffe58a, #ffc93c, #e8961e); border-radius: 99px; }
#status-progress::-moz-progress-bar { background: linear-gradient(90deg, #ffe58a, #ffc93c, #e8961e); border-radius: 99px; }
#status-notice { font-family: system-ui, sans-serif; }
</style>
"""
html = html.replace("</head>", style + "</head>", 1)
html = html.replace('<script src="index.js"></script>',
    f'<script>window.MM_PCK_PARTS = {parts};</script>\n<script src="play-shim.js"></script>\n<script src="index.js"></script>', 1)
# Report progress and readiness to the portfolio page.
html = html.replace("statusProgress.value = current;",
    "statusProgress.value = current; window.MM_TELL && MM_TELL({ type: 'progress', current: current, total: total });", 1)
html = html.replace("setStatusMode('hidden');",
    "setStatusMode('hidden'); window.MM_TELL && MM_TELL({ type: 'ready' });", 1)
html = html.replace("function displayFailureNotice(err) {",
    "function displayFailureNotice(err) {\n\t\twindow.MM_TELL && MM_TELL({ type: 'error', message: String(err && err.message || err) });", 1)
assert "play-shim.js" in html and "type: 'ready'" in html
open(dest, "w", encoding="utf-8").write(html)
