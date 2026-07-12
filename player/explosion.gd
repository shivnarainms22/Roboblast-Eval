extends Node3D

## A brief, self-contained fiery blast effect. Spawn it, set its
## global_position to the detonation point, and it animates itself and frees
## when finished. Leaves nothing behind.

const DURATION := 0.35
const MAX_RADIUS := 2.6


func _ready() -> void:
	var flash_material := _spawn_flash()
	_spawn_sparks()

	var tween := create_tween()
	tween.set_parallel(true)
	# Flare outward from a point and quickly expand.
	tween.tween_property(self, "scale", Vector3.ONE * MAX_RADIUS, DURATION) \
		.from(Vector3.ONE * 0.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Fade the hot core out as it grows, so it dies away to nothing.
	tween.tween_property(flash_material, "albedo_color:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Keep the node alive a touch longer so trailing sparks finish, then remove.
	await get_tree().create_timer(0.7).timeout
	queue_free()


func _spawn_flash() -> StandardMaterial3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.55, 0.12, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.42, 0.06)
	material.emission_energy_multiplier = 6.0
	mesh_instance.material_override = material

	add_child(mesh_instance)
	return material


func _spawn_sparks() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 28
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.3
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = 4.0
	process_material.initial_velocity_max = 9.0
	process_material.gravity = Vector3(0.0, -12.0, 0.0)
	process_material.scale_min = 0.15
	process_material.scale_max = 0.4
	process_material.color = Color(1.0, 0.5, 0.1)
	particles.process_material = process_material

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.08
	spark_mesh.height = 0.16
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3

	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.albedo_color = Color(1.0, 0.55, 0.12)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.42, 0.06)
	spark_material.emission_energy_multiplier = 4.0
	spark_mesh.material = spark_material

	particles.draw_pass_1 = spark_mesh
	add_child(particles)
	particles.emitting = true
