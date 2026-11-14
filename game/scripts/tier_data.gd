extends Node
## Monster tier settings. This is the one file to edit when tuning monsters.
## It is loaded automatically as "TierData", so any script can use it.
##
## For each tier:
##   name     - a label, used only in messages
##   texture  - the PNG in assets/monsters
##   radius   - collision circle size in pixels. The sprite is scaled so its
##              width matches the circle (see get_sprite_scale).
##   points   - score for creating this tier by merging
##   bonus    - extra points on top, for the big tiers (4 to 8)
##
## Radii follow the art size chart (docs/size_chart.png). Each monster's width
## in the chart, relative to the Tier 8 boss:
##   T1 0.119  T2 0.195  T3 0.289  T4 0.412  T5 0.471  T6 0.658  T7 0.826  T8 1.000
## BOSS_RADIUS sets the overall scale; every other tier keeps its chart ratio.
## To make everything bigger or smaller, change BOSS_RADIUS only.
## It was 130; it is 10% bigger (143) so the jar fills a little faster and
## placement matters more. The jar still fits a Tier 8 boss with room to spare.

const BOSS_RADIUS := 143.0

const SIZE_CHART_RATIO: Array[float] = [0.119, 0.195, 0.289, 0.412, 0.471, 0.658, 0.826, 1.0]

## Readability boost for the smallest tiers. At their pure chart size Tier 1
## (about 15 px) and Tier 2 (about 25 px) are too small to read their faces,
## and they are the monsters players see most. 1.0 = exact chart size.
## Result: T1 25, T2 32, T3 41, T4 59, T5 67, T6 94, T7 118, T8 143 px radius.
const READABILITY_BOOST: Array[float] = [1.45, 1.15, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

const TIERS: Array[Dictionary] = [
	{"name": "Tier 1 - Tiny Dot",  "texture": "res://assets/monsters/tier_1.png", "points": 1,  "bonus": 0},
	{"name": "Tier 2",             "texture": "res://assets/monsters/tier_2.png", "points": 3,  "bonus": 0},
	{"name": "Tier 3",             "texture": "res://assets/monsters/tier_3.png", "points": 6,  "bonus": 0},
	{"name": "Tier 4",             "texture": "res://assets/monsters/tier_4.png", "points": 10, "bonus": 10},
	{"name": "Tier 5",             "texture": "res://assets/monsters/tier_5.png", "points": 15, "bonus": 20},
	{"name": "Tier 6 - Three Eyes", "texture": "res://assets/monsters/tier_6.png", "points": 21, "bonus": 30},
	{"name": "Tier 7 - Four Eyes",  "texture": "res://assets/monsters/tier_7.png", "points": 28, "bonus": 40},
	{"name": "Tier 8 - Big Boss",  "texture": "res://assets/monsters/tier_8.png", "points": 36, "bonus": 50},
]

## Drops: the first drop is always Tier 1, then a controlled-random pick from
## Tier 1 to this tier (see dropper.gd for the weights and fairness rules).
## Tiers above it (5 to 8) are only made by merging.
const MAX_DROP_TIER := 4

## Bonus for merging two Tier 8 bosses (they vanish).
const BOSS_MERGE_BONUS := 100


func tier_count() -> int:
	return TIERS.size()


func is_valid(tier: int) -> bool:
	return tier >= 1 and tier <= TIERS.size()


func get_tier(tier: int) -> Dictionary:
	assert(is_valid(tier), "Tier %d does not exist" % tier)
	return TIERS[tier - 1]


func get_radius(tier: int) -> float:
	assert(is_valid(tier), "Tier %d does not exist" % tier)
	return BOSS_RADIUS * SIZE_CHART_RATIO[tier - 1] * READABILITY_BOOST[tier - 1]


## Scale to apply to the tier's Sprite2D so the art is as wide as its collider.
func get_sprite_scale(tier: int) -> Vector2:
	var tex := get_texture(tier)
	if tex == null:
		return Vector2.ONE
	var s := (get_radius(tier) * 2.0) / tex.get_width()
	return Vector2(s, s)


func get_points(tier: int) -> int:
	return get_tier(tier)["points"]


func get_bonus(tier: int) -> int:
	return get_tier(tier)["bonus"]


## Tier size compared to the Tier 8 boss (0.119 for Tier 1 ... 1.0 for Tier 8).
func get_size_ratio(tier: int) -> float:
	return get_radius(tier) / get_radius(tier_count())


## Returns the tier's sprite, or null if the PNG is missing.
func get_texture(tier: int) -> Texture2D:
	var path: String = get_tier(tier)["texture"]
	if ResourceLoader.exists(path):
		return load(path)
	return null


## Blink frames shown after the eyes-open sprite: half-closed, closed,
## half-open. They sit next to the sprite as tier_N_blink_1.png .. _3.png and
## must be the same pixel size as tier_N.png. Missing frames = no blink.
const BLINK_FRAME_COUNT := 3

func get_blink_frames(tier: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var base: String = (get_tier(tier)["texture"] as String).get_basename()
	for i in range(1, BLINK_FRAME_COUNT + 1):
		var path := "%s_blink_%d.png" % [base, i]
		if not ResourceLoader.exists(path):
			return []
		frames.append(load(path))
	return frames

