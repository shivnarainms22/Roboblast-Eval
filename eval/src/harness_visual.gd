extends Node3D

## Visual dimension of the verifier — graded in the GAME'S real rendering
## environment (sky, glow/bloom, filmic tonemap, lit ground) rather than a
## sterile black screen, so the blast is judged as it actually looks in game.
##
## Robust + deterministic despite the busy environment via:
##  - a FIXED camera and a deterministic OFF-CENTRE detonation point,
##  - FRAME-DIFFERENCING against a pre-detonation baseline, so only pixels the
##    blast actually changes are measured (the static background cancels out),
##  - a WORLD-SPACE localization check: the blast must appear at the projected
##    screen position of the detonation's WORLD point (a screen-space overlay
##    drawn at frame-centre fails this).
##
## Sub-scores (sum 65), the last ones gated on a localized blast having appeared:
##   appears (10), localized-at-impact (15), warm hue (8), heat/brightness (7),
##   expands (10), fades (10), fully-gone (5).

const GRENADE := preload("res://player/grenade.tscn")
const PLAYGROUND := preload("res://playground.tscn")
const OUT_DIR := "res://verifier/out"
const FRAMES_OUT := OUT_DIR + "/frames"
const MAX_POINTS := 65.0

const FRAMES := 180
const STRIDE := 2
const DET_POS := Vector3(2.0, 0.6, 0.0)   # off-centre detonation (world space)
const BASELINE_FRAME := 8                  # captured before the grenade detonates
# A "blast" pixel is one whose COLOUR changed materially from the pre-detonation
# baseline (sum of per-channel deltas). Colour-change (not mere brightening) is
# robust against the level's bright/coloured background: a full-screen orange
# flash changes the whole frame (so it fails the compactness gate), while a
# localized blast changes only its region.
const CHANGE_THRESH := 0.28
const EDGE_MARGIN := 0.10
const SAVE_EVERY := 4
# Fixed seed for the global RNG and every particle system, so repeated grades of
# the same project are pixel-identical. Must be paired with --fixed-fps (see
# run_verifier.ps1): the seed pins WHAT the particles do, --fixed-fps pins WHEN.
const RNG_SEED := 12345

var _cam: Camera3D
var _series: Array = []
var _baseline: Image = null
var _target := Vector2.ZERO   # detonation world point projected into image space


func _ready() -> void:
	_make_deterministic()
	_build_scene()

	var g: Node3D = GRENADE.instantiate()
	add_child(g)
	g.global_position = DET_POS + Vector3(0.0, 0.3, 0.0)
	if g.has_method("throw"):
		g.throw(Vector3.ZERO)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES_OUT))

	for i in FRAMES:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if i == BASELINE_FRAME:
			_baseline = img.duplicate()
			_target = _project(DET_POS, img)
		var m: Dictionary
		if _baseline != null and i > BASELINE_FRAME:
			m = _measure_diff(img)
		else:
			m = {"bright_frac": 0.0, "warm_frac": 0.0, "hot_frac": 0.0,
				"centroid": Vector2.ZERO, "edge_bright_frac": 0.0,
				"bright_n": 0, "warm_n": 0}
		m["i"] = i
		_series.append(m)
		if i % SAVE_EVERY == 0:
			img.save_png("%s/f_%03d.png" % [FRAMES_OUT, i])

	_score()
	get_tree().quit()


## Particle systems re-seed themselves every run by default, so the same effect
## renders different spark directions, lifetimes and colours each time — which
## moves the measured peak frame and warm/hot fractions, and hence the grade.
## Pin the global RNG and force a fixed seed on every particle node, including
## ones the solution spawns later at detonation (hence the node_added hook, and
## restart() so the seed applies even if the node emits the moment it enters).
func _make_deterministic() -> void:
	seed(RNG_SEED)
	get_tree().node_added.connect(_pin_rng)


func _pin_rng(n: Node) -> void:
	if n is GPUParticles3D or n is CPUParticles3D:
		n.set("use_fixed_seed", true)
		n.set("seed", RNG_SEED)
		if n.get("emitting"):
			n.call("restart")


func _build_scene() -> void:
	# Grade the blast inside a REAL shipped level (playground.tscn): its own
	# WorldEnvironment (sky, glow, filmic tonemap), its directional lighting,
	# and its CSG floor. Only the dynamic actors (player, boxes, enemies) are
	# removed so the backdrop is static and the grade is reproducible — the
	# rendering context is the game's own, not a stand-in.
	var level: Node3D = PLAYGROUND.instantiate()
	add_child(level)
	for n in ["CharacterBody3d", "Box", "Box2", "Box3", "Box4", "Box5", "Box6",
			"FlyingEnemy", "FlyingEnemy2", "FlyingEnemy3", "JumpingPad"]:
		if level.has_node(n):
			level.get_node(n).queue_free()

	# Fixed camera, looking well to the LEFT of the detonation so the blast
	# lands clearly right-of-centre — a world-anchored effect appears there, a
	# frame-centre overlay does not (world-space localization check).
	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, 3.0, 10.0)
	add_child(_cam)
	_cam.look_at(Vector3(-2.5, 0.6, 0.0), Vector3.UP)
	_cam.make_current()


func _project(world_pos: Vector3, img: Image) -> Vector2:
	var sp := _cam.unproject_position(world_pos)
	var vp := get_viewport().get_visible_rect().size
	var scale := float(img.get_width()) / vp.x
	return sp * scale


func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _measure_diff(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var margin_x := int(w * EDGE_MARGIN)
	var margin_y := int(h * EDGE_MARGIN)
	var samples := 0
	var bright := 0     # "blast" pixels: brightened vs baseline and lit now
	var warm := 0
	var hot := 0
	var sum_x := 0.0
	var sum_y := 0.0
	var edge_samples := 0
	var edge_bright := 0

	var y := 0
	while y < h:
		var x := 0
		while x < w:
			samples += 1
			var is_edge := x < margin_x or x >= w - margin_x or y < margin_y or y >= h - margin_y
			if is_edge:
				edge_samples += 1
			var c := img.get_pixel(x, y)
			var b := _baseline.get_pixel(x, y)
			var lum := _lum(c)
			var change := absf(c.r - b.r) + absf(c.g - b.g) + absf(c.b - b.b)
			if change > CHANGE_THRESH:
				bright += 1
				sum_x += x
				sum_y += y
				if is_edge:
					edge_bright += 1
				# warm-hued (orange/red), tolerant of dim tones like brown
				if c.r > 0.22 and c.r > c.b + 0.10 and c.g <= c.r + 0.08:
					warm += 1
				# genuinely bright, hot core pixel (a real flare) — bright & not blue
				if lum > 0.62 and c.b <= c.r:
					hot += 1
			x += STRIDE
		y += STRIDE

	var frac := 0.0 if samples == 0 else float(bright) / float(samples)
	var cx := 0.0
	var cy := 0.0
	if bright > 0:
		cx = sum_x / bright
		cy = sum_y / bright
	return {
		"bright_frac": frac,
		"warm_frac": (0.0 if bright == 0 else float(warm) / float(bright)),
		"hot_frac": (0.0 if bright == 0 else float(hot) / float(bright)),
		"centroid": Vector2(cx, cy),
		"edge_bright_frac": (0.0 if edge_samples == 0 else float(edge_bright) / float(edge_samples)),
		# raw counts, so hue can be pooled over the blast's lifetime (see _score)
		"bright_n": bright,
		"warm_n": warm,
	}


func _score() -> void:
	var peak_i := 0
	var peak_frac := 0.0
	for m in _series:
		if m["bright_frac"] > peak_frac:
			peak_frac = m["bright_frac"]
			peak_i = m["i"]
	var peak = _series[peak_i]

	# Onset = first frame the blast is visible; rise = frames from onset to peak.
	var onset_i := peak_i
	for m in _series:
		if m["bright_frac"] > 0.006:
			onset_i = m["i"]
			break
	var rise := peak_i - onset_i

	var img_size := get_viewport().get_texture().get_image().get_size()
	var diag := Vector2(img_size).length()
	# WORLD-SPACE localization: compare the blast centroid to the detonation
	# point projected into the image, NOT to frame-centre.
	var centroid_err := (peak["centroid"] as Vector2).distance_to(_target) / diag
	var max_edge_frac := 0.0
	for m in _series:
		max_edge_frac = max(max_edge_frac, m["edge_bright_frac"])
	var edge_ok := max_edge_frac < 0.10

	var appeared := peak_frac > 0.008
	var centered := centroid_err < 0.12
	# A localized blast occupies a bounded region at the impact point. A screen-
	# filling flash forfeits the whole visual score.
	var compact := peak_frac < 0.35
	var localized_blast := appeared and compact

	var s_appear := 10.0 if localized_blast else 0.0

	var s_local := 0.0
	if localized_blast:
		if centered and edge_ok:
			s_local = 15.0
		elif centered:
			s_local = 10.0

	# --- warm/fiery hue (8) ---
	# Judge the blast's colour WHILE THERE IS A BLAST TO JUDGE: pool the raw
	# pixel counts over the frames where it is at least half its peak size.
	#   - A single frame (the peak) is an arbitrary sample — a small colour shift
	#     there swings the score.
	#   - The full lifetime is worse: the long, dim tail is a handful of stray
	#     ember pixels blending into the background, so a small effect with a slow
	#     fade gets marked down for an implementation detail, not for its colour.
	# Pooling raw counts (not averaging per-frame fractions) weights each frame by
	# how much blast it actually contains. An effect that is blue while it burns
	# still scores 0.
	var warm_total := 0.0
	var bright_total := 0.0
	for m in _series:
		if m["bright_frac"] >= 0.5 * peak_frac:
			warm_total += float(m["warm_n"])
			bright_total += float(m["bright_n"])
	var life_warm_frac := 0.0 if bright_total == 0.0 else warm_total / bright_total

	# Thresholds placed in the GAP between the two measured populations, not by eye.
	# Fiery effects (the original, all three agent runs, and the orange probes)
	# measure 0.57–0.96; the one genuinely non-fiery effect (a blue blast) measures
	# 0.00. The separating region is empty, so the boundary sits at 0.35 — >=60%
	# clear of every fiery effect AND of the blue one. An earlier 0.6 gate sat
	# INSIDE the fiery cluster, which made the score of the smallest blast (whose
	# warm fraction is diluted by background-blended edge pixels) a coin-flip.
	# Grading colour, not blast size.
	var s_hue := 0.0
	if localized_blast:
		if life_warm_frac > 0.35:
			s_hue = 8.0
		elif life_warm_frac > 0.15:
			s_hue = 4.0

	# --- heat (7): a genuinely bright hot core at some point in the effect ---
	var s_heat := 0.0
	if localized_blast:
		var hf := 0.0
		for m in _series:
			hf = max(hf, m["hot_frac"])
		if hf > 0.12:
			s_heat = 7.0
		elif hf > 0.04:
			s_heat = 4.0
		elif hf > 0.01:
			s_heat = 2.0

	# --- flash (10): an explosion FLARES — it peaks almost immediately at
	# detonation and then decays. A slow swell (peak many frames after onset,
	# like an inflating sphere) is not a flash. ---
	var s_flash := 0.0
	if localized_blast:
		if rise <= 4:
			s_flash = 10.0
		elif rise <= 8:
			s_flash = 5.0

	# --- fades (10): after the peak, the blast collapses ---
	var s_fade := 0.0
	var post_min := peak_frac
	for m in _series:
		if m["i"] > peak_i:
			post_min = min(post_min, m["bright_frac"])
	if localized_blast and post_min < 0.20 * peak_frac:
		s_fade = 10.0

	# --- fully gone (5): last frame ~ back to baseline ---
	var s_gone := 0.0
	var last_frac: float = _series[_series.size() - 1]["bright_frac"]
	if localized_blast and last_frac < max(0.004, 0.12 * peak_frac):
		s_gone = 5.0

	var total := s_appear + s_local + s_hue + s_heat + s_flash + s_fade + s_gone

	var series: Array = []
	for m in _series:
		series.append([m["i"], snappedf(m["bright_frac"], 0.0001), snappedf(m["hot_frac"], 0.0001)])

	var report := {
		"dimension": "visual",
		"max": MAX_POINTS,
		"score": snappedf(total, 0.01),
		"subscores": {
			"appears": s_appear,
			"localized": s_local,
			"fiery_hue": s_hue,
			"heat": s_heat,
			"flash": s_flash,
			"fades": s_fade,
			"fully_gone": s_gone,
		},
		"metrics": {
			"peak_frame": peak_i,
			"onset_frame": onset_i,
			"rise_frames": rise,
			"peak_bright_frac": snappedf(peak_frac, 0.0001),
			"peak_warm_frac": snappedf(peak["warm_frac"], 0.0001),
			"life_warm_frac": snappedf(life_warm_frac, 0.0001),
			"peak_hot_frac": snappedf(peak["hot_frac"], 0.0001),
			"centroid_err": snappedf(centroid_err, 0.0001),
			"edge_ok": edge_ok,
			"max_edge_frac": snappedf(max_edge_frac, 0.0001),
			"compact": compact,
			"localized_blast": localized_blast,
			"post_min_frac": snappedf(post_min, 0.0001),
			"last_frac": snappedf(last_frac, 0.0001),
			"target_px": [snappedf(_target.x, 0.1), snappedf(_target.y, 0.1)],
			"centroid_px": [snappedf(peak["centroid"].x, 0.1), snappedf(peak["centroid"].y, 0.1)],
			"series": series,
		},
	}
	_write("visual.json", report)
	print("VERIFIER_VISUAL_SCORE=", report["score"], "/", MAX_POINTS,
		"  ", JSON.stringify(report["subscores"]))


func _write(fname: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(OUT_DIR + "/" + fname, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
