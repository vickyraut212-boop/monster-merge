# Monster sprites

Each tier has an eyes-open sprite plus 3 blink frames:

| File | What it is |
|---|---|
| `tier_N.png` | Tier N, eyes open (used everywhere, including the HUD) |
| `tier_N_blink_1.png` | eyes half closed |
| `tier_N_blink_2.png` | eyes closed |
| `tier_N_blink_3.png` | eyes half open again |

Tier 1 is the tiny dot, Tier 8 the big boss.

Tiers 6, 7 and 8 (the purple three-eyed monster, the mint five-eyed monster and the orange boss) use the final reference art. Their blink frames have no hand-made versions: `tier_6/7/8_blink_1..3.png` were generated from the eyes-open sprite by painting skin-coloured eyelids over each eye, in the same style as the other tiers. If you redraw one of these sprites, regenerate its blink frames to match.

Tips:
- Transparent background, monster centred, cropped tight, resized to 768px max.
- All 4 files of a tier must be exactly the same pixel size, or the blink will jump.
- The game scales each tier so its width matches its collider, so swapping art never changes the in-game size.
- If a tier's blink frames are missing, that monster just doesn't blink.
- Sizes follow `docs/size_chart.png`; sizes and points per tier live in `scripts/tier_data.gd`.
- Blink speed and timing live in `scripts/blink_sprite.gd`.

Colours: Tier 1 was recoloured electric fuchsia (about #F241E3) so it stands out against the purple space background. Only the body colour changed: each pixel keeps its own shading, with slightly stronger gloss and shadow and a soft rim light on the top-left edges. Its blink frames got exactly the same treatment. Tiers 7 and 8 are the final reference art, unchanged. Tier 6 is its reference art with the same colours made to pop against the background: about 20% more saturation, more contrast and brightness on the body, a soft gloss streak on the left side, and a light lavender edge around the whole silhouette (strongest on the top left). Its blink frames were regenerated from that version.
