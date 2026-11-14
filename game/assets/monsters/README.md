# Monster sprites

Each tier has an eyes-open sprite plus 3 blink frames:

| File | What it is |
|---|---|
| `tier_N.png` | Tier N, eyes open (used everywhere, including the HUD) |
| `tier_N_blink_1.png` | eyes half closed |
| `tier_N_blink_2.png` | eyes closed |
| `tier_N_blink_3.png` | eyes half open again |

Tier 1 is the tiny dot, Tier 8 the big boss.

Tier 6 (red three-eyed monster) and Tier 7 (lavender four-eyed monster) are vicky's approved art, used exactly as supplied ("Tire 6.png" and "Tire 7.png", 2026-11-14): `tier_6.png` is the supplied file byte for byte, and `tier_7.png` is the supplied file with only its fully transparent margin cropped off (every remaining pixel is unchanged), so the sprite width matches the collider like the other tiers. They are larger than 768px, so their `.import` files set `process/size_limit=768` and Godot downsizes them on import. Do not recolour, outline or redraw them. They have no blink frames yet, so they don't blink; any blink frames made for them later must keep the art untouched apart from the eyelids.

Tier 8 (the orange boss) uses the final reference art. Its blink frames have no hand-made versions: `tier_8_blink_1..3.png` were generated from the eyes-open sprite by painting skin-coloured eyelids over each eye.

Tips:
- Transparent background, monster centred, cropped tight, resized to 768px max.
- All 4 files of a tier must be exactly the same pixel size, or the blink will jump.
- The game scales each tier so its width matches its collider, so swapping art never changes the in-game size.
- If a tier's blink frames are missing, that monster just doesn't blink.
- Sizes follow `docs/size_chart.png`; sizes and points per tier live in `scripts/tier_data.gd`.
- Blink speed and timing live in `scripts/blink_sprite.gd`.

Colours: Tier 1 was recoloured electric fuchsia (about #F241E3) so it stands out against the purple space background. Only the body colour changed: each pixel keeps its own shading, with slightly stronger gloss and shadow and a soft rim light on the top-left edges. Its blink frames got exactly the same treatment. Tier 8 is the final reference art, unchanged.
