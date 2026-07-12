extends Node3D

## Self-contained fiery blast VFX. Spawn it at the detonation point; it flares
## and expands outward, then quickly dies away and frees itself, leaving nothing
## behind. Purely cosmetic — damage is dealt by whatever spawns this.

## Roughly how far the fireball expands (metres). Kept in sync with the
## grenade's damage radius so the visual matches what gets hit.
@export var blast_radius: float = 4.0

const _LIFETIME := 0.5


func _ready() -> void:
	_spawn_fireball()
	_spawn_flash_light()
	_spawn_sparks()

	# Everything is gone shortly after the burst; free the whole effect then.
	await get_tree().create_timer(_LIFETIME + 0.3).timeout
	queue_free()


## Bright orange sphere that snaps outward from the impact point and fades.
func _spawn_fireball() -> void:
	var fireball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	fireball.mesh = sphere
	fireball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.55, 0.12, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 4.0
	fireball.material_override = mat

	fireball.scale = Vector3.ONE * 0.25
	add_child(fireball)

	var tween := create_tween()
	tween.set_parallel(true)
	# Flare open fast, then ease to the full blast size.
	tween.tween_property(fireball, "scale", Vector3.ONE * blast_radius, _LIFETIME * 0.55) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Hot at first, then cool and fade to nothing.
	tween.tween_property(mat, "albedo_color:a", 0.0, _LIFETIME).set_ease(Tween.EASE_IN)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, _LIFETIME).set_ease(Tween.EASE_IN)


## A momentary point light so the blast lights up its surroundings.
func _spawn_flash_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 8.0
	light.omni_range = blast_radius * 2.5
	add_child(light)

	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, _LIFETIME * 0.6).set_ease(Tween.EASE_IN)


## A one-shot burst of fiery embers flung outward from the centre.
func _spawn_sparks() -> void:
	var sparks := GPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 48
	sparks.lifetime = _LIFETIME
	sparks.local_coords = false

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = blast_radius * 2.5
	pm.initial_velocity_max = blast_radius * 5.0
	pm.gravity = Vector3(0.0, -12.0, 0.0)
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.scale_min = 0.15
	pm.scale_max = 0.4

	# Shrink each ember over its life.
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	pm.scale_curve = scale_tex

	# Yellow-hot to red, fading to transparent.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.25, 1.0))
	gradient.set_color(1, Color(0.8, 0.15, 0.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	pm.color_ramp = gradient_tex

	sparks.process_material = pm

	var ember := SphereMesh.new()
	ember.radius = 0.06
	ember.height = 0.12
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.vertex_color_use_as_albedo = true
	ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.5, 0.1)
	ember_mat.emission_energy_multiplier = 3.0
	ember.material = ember_mat
	sparks.draw_pass_1 = ember

	add_child(sparks)
	sparks.emitting = true
