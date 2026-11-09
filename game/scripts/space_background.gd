class_name SpaceBackground
extends Node2D
## The space backdrop behind everything: the background painting plus the
## planets and stars, placed exactly as in vicky's UI reference.
##
## LAYOUT (720 x 1280 screen, positions measured from the reference)
## - Pink planet: hugging the left edge just above the jar, half off-screen.
## - Blue ringed planet: hugging the right edge beside the ship.
## - Purple planet: peeking in from the right edge behind the top of the jar.
## - Six small stars: top right, either side of the ship, and two each down
##   the left and right glass walls of the jar.
## To move one, edit its entry in PLANETS or STARS below.
##
## PURELY DECORATIVE: nothing here has a collision shape, and everything is
## drawn behind every other node (z_index -100).

## The background painting. It is scaled to cover the whole 720 x 1280 screen.
@export var background_texture: Texture2D = preload("res://assets/ui/background.jpg")
@export_range(0.0, 1.0) var planet_opacity := 1.0
@export_range(0.0, 1.0) var star_opacity := 0.95
## Planets bob up and down gently; stars twinkle.
@export var animate := true

const SCREEN := Vector2(720, 1280)

## texture, centre, width in pixels, tilt in degrees.
const PLANETS := [
	["res://assets/ui/planet_2.png", Vector2(6, 452), 156.0, 0.0],     # pink
	["res://assets/ui/planet_3.png", Vector2(694, 392), 200.0, -4.0],  # blue ringed
	["res://assets/ui/planet_1.png", Vector2(716, 578), 138.0, 0.0],   # purple
]

## texture, centre, width in pixels.
const STARS := [
	["res://assets/ui/star_1.png", Vector2(668, 170), 30.0],
	["res://assets/ui/star_2.png", Vector2(137, 356), 46.0],
	["res://assets/ui/star_1.png", Vector2(528, 422), 24.0],
	["res://assets/ui/star_2.png", Vector2(38, 646), 34.0],
	["res://assets/ui/star_1.png", Vector2(670, 745), 32.0],
	["res://assets/ui/star_2.png", Vector2(48, 930), 30.0],
]


func _ready() -> void:
	z_index = -100
	z_as_relative = false
	for planet in PLANETS:
		_add_sprite(load(planet[0]), planet[1], planet[2], deg_to_rad(planet[3]), planet_opacity, true)
	for star in STARS:
		_add_sprite(load(star[0]), star[1], star[2], 0.0, star_opacity, false)


func _draw() -> void:
	if background_texture == null:
		return
	# Cover the screen without stretching: scale to the larger ratio and centre.
	var tex := background_texture.get_size()
	var s := maxf(SCREEN.x / tex.x, SCREEN.y / tex.y)
	var size := tex * s
	draw_texture_rect(background_texture, Rect2((SCREEN - size) / 2.0, size), false)


func _add_sprite(tex: Texture2D, center: Vector2, width: float, tilt: float, opacity: float, is_planet: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2.ONE * (width / maxf(tex.get_size().x, tex.get_size().y))
	sprite.position = center
	sprite.rotation = tilt
	sprite.modulate.a = opacity
	add_child(sprite)
	if animate:
		_animate(sprite, is_planet)


func _animate(sprite: Sprite2D, is_planet: bool) -> void:
	var tween := sprite.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_planet:
		var y := sprite.position.y
		var period := randf_range(3.0, 5.0)
		tween.tween_property(sprite, "position:y", y - 5.0, period)
		tween.tween_property(sprite, "position:y", y + 5.0, period)
	else:
		var base := sprite.scale
		var period := randf_range(0.8, 1.6)
		tween.tween_interval(randf_range(0.0, 1.5))
		tween.tween_property(sprite, "scale", base * 0.8, period)
		tween.tween_property(sprite, "scale", base, period)
