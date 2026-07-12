extends CharacterBody3D

const EXPLOSION_SCENE := preload("res://player/explosion.gd")

## How far the blast reaches — a local blast of a few metres.
const BLAST_RADIUS := 4.0
## Base knockback impulse strength applied to caught targets.
const BLAST_KNOCKBACK := 14.0

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

	var detonation_point := global_position
	_spawn_blast_effect(detonation_point)
	_damage_nearby(detonation_point)

	_explosion_sound.pitch_scale = randfn(2.0, 0.1)
	_explosion_sound.play()

	hide()
	await _explosion_sound.finished
	queue_free()


func _spawn_blast_effect(detonation_point: Vector3) -> void:
	var explosion := EXPLOSION_SCENE.new()
	get_parent().add_child(explosion)
	explosion.global_position = detonation_point


func _damage_nearby(detonation_point: Vector3) -> void:
	for target in get_tree().get_nodes_in_group("targeteables"):
		if not target is Node3D or not target.has_method("damage"):
			continue

		var offset: Vector3 = target.global_position - detonation_point
		var distance := offset.length()
		if distance > BLAST_RADIUS:
			continue

		# Push outward from the blast (and a little upward), stronger up close.
		var direction := offset.normalized() if distance > 0.01 else Vector3.UP
		var falloff := 1.0 - distance / BLAST_RADIUS
		var force := (direction + Vector3.UP * 0.5).normalized() * BLAST_KNOCKBACK * falloff
		# damage() expects the impact point relative to the target's origin.
		target.damage(-offset, force)
