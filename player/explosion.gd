extends Node3D

## A short-lived fiery blast played at a grenade's detonation point.
##
## Spawns a bright orange flash that flares outward and fades, a quick burst of
## sparks, and a hot light pop. Everything is driven procedurally so the effect
## leaves nothing behind: once every element has finished, the node frees itself.

const MAX_RADIUS := 3.5
const FLASH_DURATION := 0.35
const LIFETIME := 0.7


func _ready() -> void:
	_spawn_flash()
	_spawn_light()
	_spawn_sparks()

	# Free once the longest-lived element (the sparks) has finished.
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()


func _spawn_flash() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.55, 0.12, 1.0)

	var flash := MeshInstance3D.new()
	flash.mesh = sphere
	flash.material_override = material
	flash.scale = Vector3.ONE * 0.2
	add_child(flash)

	# Flare outward quickly, fading to nothing as it expands.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * MAX_RADIUS, FLASH_DURATION) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, FLASH_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _spawn_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 8.0
	light.omni_range = MAX_RADIUS * 2.5
	light.position = Vector3.UP * 0.5
	add_child(light)

	# A hot flash that dies away almost immediately.
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_sparks() -> void:
	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.06
	draw_mesh.height = 0.12
	draw_mesh.radial_segments = 6
	draw_mesh.rings = 3

	var mesh_material := StandardMaterial3D.new()
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.vertex_color_use_as_albedo = true
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mesh.material = mesh_material

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	gradient.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.3
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 4.0
	process.initial_velocity_max = 9.0
	process.gravity = Vector3(0.0, -12.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.5
	process.damping_min = 2.0
	process.damping_max = 4.0
	process.color_ramp = ramp

	var particles := GPUParticles3D.new()
	particles.amount = 32
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.draw_pass_1 = draw_mesh
	particles.process_material = process
	add_child(particles)
	particles.emitting = true
