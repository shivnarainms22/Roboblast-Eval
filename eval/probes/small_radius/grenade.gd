extends CharacterBody3D

## PARTIAL-CREDIT PROBE: "blast radius far too small".
##
## Not a cheat — an under-built but honest attempt. It damages correctly, just
## with a 1.0m radius instead of a sensible few metres, so it only reaches the
## nearest of the in-radius enemies (which sit at 0.8-2.2m) and produces no
## visual at all.
##
## Purpose: demonstrate that the damage dimension awards GRADED PARTIAL CREDIT
## (score = 35 * coverage * precision), not just all-or-nothing. Every other
## subject scores a clean 35 or 0, so without this probe the partial-credit
## claim on this axis would be untested.
##   expected: precision 1.0 (far enemies spared), coverage ~1/3 -> damage ~11.7

const BLAST_RADIUS := 1.0

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

	for body in get_tree().get_nodes_in_group("damageables"):
		if body is Player:
			continue
		var offset: Vector3 = body.global_position - global_position
		if offset.length() > BLAST_RADIUS:
			continue
		if body.has_method("damage"):
			body.damage(-offset, offset.normalized() * 3.0 + Vector3.UP * 3.0)

	hide()
	await _explosion_sound.finished
	queue_free()
