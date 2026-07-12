extends CharacterBody3D

## ANTI-CHEAT PROBE: "screen-space overlay at frame centre".
## Correct radial damage + a small orange dot drawn as a 2D CanvasLayer overlay
## at the CENTRE of the screen (never anchored to the 3D world). It appears,
## expands, fades, is orange and bright — but it is NOT at the detonation's
## world position. Should be caught by the WORLD-SPACE localization check:
## the blast centroid sits at frame-centre while the detonation projects
## off-centre -> localized = 0.

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

	# CHEAT: a bright orange dot pinned to the CENTRE of the screen.
	var layer := CanvasLayer.new()
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.82, 0.45, 1.0)  # bright, so it IS detected — the point is it's mislocated
	rect.anchor_left = 0.5
	rect.anchor_top = 0.5
	rect.anchor_right = 0.5
	rect.anchor_bottom = 0.5
	rect.offset_left = -45.0
	rect.offset_top = -45.0
	rect.offset_right = 45.0
	rect.offset_bottom = 45.0
	rect.pivot_offset = Vector2(45.0, 45.0)
	rect.scale = Vector2(0.3, 0.3)
	layer.add_child(rect)
	get_tree().current_scene.add_child(layer)
	var tw := rect.create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "scale", Vector2(1.4, 1.4), 0.4)
	tw.tween_property(rect, "color:a", 0.0, 0.4)
	tw.chain().tween_callback(layer.queue_free)

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
