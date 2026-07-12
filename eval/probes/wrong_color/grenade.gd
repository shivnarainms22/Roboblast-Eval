extends CharacterBody3D

## ANTI-CHEAT PROBE: "right shape, wrong colour".
## Correct radial damage + a well-placed blob that appears, expands and fades
## correctly but is BLUE instead of fiery. Should be caught by the FIERY-COLOUR
## guard (fiery_color -> 0): a blue puff is not an explosion.

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

	# CHEAT: correct-looking blast, but blue.
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.4, 0.97)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.4, 0.97)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	get_tree().current_scene.add_child(mesh)
	mesh.global_position = global_position
	mesh.scale = Vector3.ONE * 0.3
	var tw := mesh.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh, "scale", Vector3.ONE * 3.0, 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mesh.queue_free)

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
