# Monster sprites

Each tier has an eyes-open sprite plus 3 blink frames:

| File | What it is |
|---|---|
| `tier_N.png` | Tier N, eyes open (used everywhere, including the HUD) |
| `tier_N_blink_1.png` | eyes half closed |
| `tier_N_blink_2.png` | eyes closed |
| `tier_N_blink_3.png` | eyes half open again |

Tier 1 is the tiny dot, Tier 7 the big boss.

Tips:
- Transparent background, monster centred, cropped tight, resized to 768px max.
- All 4 files of a tier must be exactly the same pixel size, or the blink will jump.
- The game scales each tier so its width matches its collider, so swapping art never changes the in-game size.
- If a tier's blink frames are missing, that monster just doesn't blink.
- Sizes follow `docs/size_chart.png`; sizes and points per tier live in `scripts/tier_data.gd`.
- Blink speed and timing live in `scripts/blink_sprite.gd`.
