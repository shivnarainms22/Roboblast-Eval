extends CharacterBody3D

const EXPLOSION_EFFECT := preload("res://player/explosion.gd")

## How far the blast reaches. Damageables within this distance are caught.
const BLAST_RADIUS := 4.0
## Base knock-back impulse applied at the blast's centre (falls off with distance).
const BLAST_IMPULSE := 12.0

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

	_explosion_sound.pitch_scale = randfn(2.0, 0.1)
	_explosion_sound.play()

	_spawn_blast_effect()
	_apply_blast_damage()

	hide()
	await _explosion_sound.finished
	queue_free()


## Spawns the fiery visual burst at the detonation point, parented to the level
## so it stays put (the grenade itself is about to be freed).
func _spawn_blast_effect() -> void:
	var explosion: Node3D = EXPLOSION_EFFECT.new()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position


## Damages and knocks back every damageable within the blast radius, pushing them
## up and away from the detonation point. Strength falls off toward the edge.
func _apply_blast_damage() -> void:
	for body in get_tree().get_nodes_in_group("damageables"):
		if body is Player or not body is Node3D:
			continue

		var offset: Vector3 = body.global_position - global_position
		var distance := offset.length()
		if distance > BLAST_RADIUS:
			continue

		var direction := offset.normalized() if distance > 0.01 else Vector3.UP
		var falloff := 1.0 - distance / BLAST_RADIUS
		var force := (direction + Vector3.UP).normalized() * BLAST_IMPULSE * falloff
		# Match the bullet's convention: impact point is relative to the body,
		# pointing from the body toward the blast.
		body.damage(-offset, force)
