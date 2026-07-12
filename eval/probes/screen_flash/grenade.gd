extends CharacterBody3D

## ANTI-CHEAT PROBE: "orange the whole screen".
## Correct radial damage (so damage=35) + a full-screen orange flash instead of
## a localized blast. Should be caught by the LOCALIZED guard (compactness):
## the bright mass fills the screen -> localized=0, so it cannot reach 100.

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
	_radial_damage(3.0)

	# CHEAT: flash the entire screen orange, then fade it out.
	var layer := CanvasLayer.new()
	var rect := ColorRect.new()
	rect.color = Color(0.97, 0.5, 0.0, 1.0)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	layer.add_child(rect)
	get_tree().current_scene.add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)

	hide()
	await _explosion_sound.finished
	queue_free()


func _radial_damage(radius: float) -> void:
	for body in get_tree().get_nodes_in_group("damageables"):
		if body is Player:
			continue
		if body.global_position.distance_to(global_position) <= radius and body.has_method("damage"):
			var dir: Vector3 = (body.global_position - global_position).normalized()
			body.damage(-dir, -dir * 3.0)
