class_name Monster
extends RigidBody2D
## One monster in the jar. Call setup(tier) before adding it to the scene.
## When it touches another monster of the same tier it emits touched_same_tier;
## the game (main.gd) then does the actual merge.

signal touched_same_tier(a: Monster, b: Monster)

## Surface feel of every monster.
const FRICTION := 0.4
const BOUNCE := 0.1

var tier := 1
## Set once this monster is being merged away, so it can't merge twice.
var is_merging := false

var _sprite: BlinkSprite


func setup(new_tier: int) -> void:
	tier = new_tier


func _ready() -> void:
	add_to_group("monsters")

	# Needed so body_entered fires when monsters touch.
	contact_monitor = true
	max_contacts_reported = 8

	var radius := TierData.get_radius(tier)
	# Bigger monsters are heavier, so they push small ones aside.
	mass = radius / 20.0

	var surface := PhysicsMaterial.new()
	surface.friction = FRICTION
	surface.bounce = BOUNCE
	physics_material_override = surface

	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

	_sprite = BlinkSprite.new()
	_sprite.set_tier(tier)
	add_child(_sprite)

	body_entered.connect(_on_body_entered)


## Small "pop" when a merged monster appears.
func pop_in() -> void:
	var full_scale := _sprite.scale
	_sprite.scale = full_scale * 0.6
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", full_scale, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node) -> void:
	if is_merging:
		return
	var other := body as Monster
	if other == null or other.is_merging or other.tier != tier:
		return
	# Both monsters get this callback; only the one with the lower id reports,
	# so each pair is merged exactly once.
	if get_instance_id() < other.get_instance_id():
		touched_same_tier.emit(self, other)
