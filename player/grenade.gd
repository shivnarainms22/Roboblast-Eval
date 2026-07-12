extends CharacterBody3D

const EXPLOSION_SCENE := preload("res://player/explosion/explosion.tscn")

## Enemies within this many metres of the detonation are caught in the blast.
const BLAST_RADIUS := 4.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _velocity := Vector3.ZERO

@onready var _explosion_sound: AudioStreamPlayer3D = $ExplosionSound
@onready var _explosion_start_timer: Timer = $ExplosionStartTimer


func _ready() -> void:
	_explosion_start_timer.timeout.connect(_explode)


func _physics_process(delta) -> void:
	_velocity += Vector3.DOWN * gravity * delta
	var collision := move_and_collide(_velocity * delta)
	if collision:
		_velocity = _velocity.bounce(collision.get_normal(0)) * 0.7
		if _explosion_start_timer.is_stopped():
			_explosion_start_timer.start()


func throw(throw_velocity: Vector3) -> void:
	_velocity = throw_velocity


func _explode() -> void:
	set_physics_process(false)

	# Spawn the fiery blast at the impact point. Parent it to the level so it
	# outlives the grenade node, which frees itself once the sound ends.
	var explosion := EXPLOSION_SCENE.instantiate()
	explosion.blast_radius = BLAST_RADIUS
	get_parent().add_child(explosion)
	explosion.global_position = global_position

	_damage_nearby()

	_explosion_sound.pitch_scale = randfn(2.0, 0.1)
	_explosion_sound.play()

	hide()
	await _explosion_sound.finished
	queue_free()


## Hit every damageable within the blast radius, knocking it back (and up) away
## from the detonation point. Distant targets are left untouched.
func _damage_nearby() -> void:
	for body in get_tree().get_nodes_in_group("damageables"):
		if not body is Node3D:
			continue

		var offset: Vector3 = body.global_position - global_position
		if offset.length() > BLAST_RADIUS:
			continue

		# Impulse points away from the blast, with an upward kick. It is applied
		# at the near side of the body; damage() clamps the magnitude itself.
		var direction := offset.normalized() if offset.length() > 0.001 else Vector3.UP
		var force := (direction + Vector3.UP * 0.5) * 20.0
		var impact_point := -offset
		body.damage(impact_point, force)
