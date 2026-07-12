extends Node3D

## Damage dimension of the verifier (headless, pure physics).
## Drops a real grenade over a floor, surrounds it with real enemies at known
## distances (some inside the blast radius, some outside), lets it detonate,
## and checks the OBSERVABLE outcome: which enemies were damaged.
##
## Scoring is multiplicative so it cannot be gamed:
##   score = MAX * coverage * precision
##   coverage  = in-radius enemies damaged / total in-radius   (must hit them)
##   precision = out-of-radius enemies spared / total out       (must spare them)
## Original -> 35, ablated (nothing damaged) -> 0, damage-all cheat -> 0.

const GRENADE := preload("res://player/grenade.tscn")
const ENEMY := preload("res://enemies/beetle_bot.tscn")
## Destroyed-box debris. It is in the `damageables` group but is a plain Node3D
## with NO damage() method — a trap the real game contains (box.gd spawns one
## whenever a crate breaks). The shipped explosion never trips it because it
## queries the physics area, which cannot return a non-physics node. A solution
## that instead iterates the group must guard with has_method("damage").
## Including it here makes the harness reflect the real scene. See DECISION_LOG.
const DEBRIS := preload("res://box/destroyed_box.tscn")
## The Player is ALSO in `damageables`, and has a damage() that launches them and
## costs them coins. The shipped grenade explicitly skips it; some solutions do not.
## Our SPEC only ever asked for "damages nearby enemies" and says nothing about the
## player — so this is measured and REPORTED, but deliberately **not scored**.
## Grading a requirement the spec never stated would be a false negative, which the
## brief warns against hardest. See DECISION_LOG §5.5.
const PLAYER := preload("res://player/player.tscn")
const OUT_DIR := "res://verifier/out"
const MAX_POINTS := 35.0
const PLAYER_COINS := 5   # so the player has something for lose_coins() to take

# The original blast radius is 3.0m, but the agent chooses its own. We leave an
# untested gap (2.2m..5.0m) between the bands so any sensible radius passes:
# "inside" enemies are close enough to be caught by any reasonable blast, and
# "outside" enemies are far enough to be spared by any reasonable blast.
# Exact distances are randomised per run (seeded) so a hardcoded hit-list fails.
const INSIDE_MIN := 0.8
const INSIDE_MAX := 2.2
const OUTSIDE_MIN := 5.0
const OUTSIDE_MAX := 7.0
const N_INSIDE := 3
const N_OUTSIDE := 3

var _probes: Array = []
var _player: Node3D = null


func _ready() -> void:
	var seed_arg := _get_seed()
	seed(seed_arg)

	_build_floor()
	_build_probes()

	# Let bodies settle for a few physics frames, then record baselines.
	await _wait_physics(4)
	for p in _probes:
		p["p0"] = (p["node"] as Node3D).global_position

	# Drop a real grenade at the origin; it hits the floor and detonates
	# via the game's own timer -> _explode() path (that trigger is not ablated).
	var g: Node3D = GRENADE.instantiate()
	add_child(g)
	g.global_position = Vector3(0.0, 0.2, 0.0)
	if g.has_method("throw"):
		g.throw(Vector3.ZERO)

	# Wait past the 0.35s fuse + impulse settle, but before enemy death cleanup (~2.5s).
	await _wait_physics(120)

	_evaluate(seed_arg)
	get_tree().quit()


func _build_floor() -> void:
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	cs.shape = box
	floor.add_child(cs)
	floor.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor)


func _build_probes() -> void:
	for i in N_INSIDE:
		_add_probe("in_%d" % i, randf_range(INSIDE_MIN, INSIDE_MAX), true)
	for i in N_OUTSIDE:
		_add_probe("out_%d" % i, randf_range(OUTSIDE_MIN, OUTSIDE_MAX), false)

	# Added AFTER the enemies so it does not consume RNG draws and shift their
	# seeded distances. Sits well inside any sensible blast, so every solution's
	# damage loop encounters it. Not scored, and its position in the group's
	# iteration order does not matter: an unguarded loop errors whenever it
	# reaches the debris, and the runner forfeits the dimension on any runtime
	# error rather than counting how many enemies it happened to reach first.
	# Diagnostic only — see PLAYER above. Made inert (no collision, no physics) so it
	# cannot perturb the enemies and change the graded outcome; it exists purely as a
	# damageables-group member for the solution's loop to encounter.
	#
	# Added BEFORE the debris deliberately. Group iteration follows insertion order,
	# so an unguarded loop reaches the player FIRST and only then errors on the
	# debris. If the debris came first, the crash would abort the loop early and mask
	# whether the solution would have hit the player — the measurement would be an
	# artifact of ordering rather than a fact about the solution.
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector3(1.5, 0.5, 1.5)   # ~2.1 m — inside any sensible blast
	_player.set("collision_layer", 0)
	_player.set("collision_mask", 0)
	_player.set_physics_process(false)
	_player.set("_coins", PLAYER_COINS)

	var debris: Node3D = DEBRIS.instantiate()
	add_child(debris)
	debris.global_position = Vector3(1.2, 0.0, 0.0)


func _add_probe(pname: String, dist: float, inside: bool) -> void:
	var ang := randf() * TAU
	var pos := Vector3(cos(ang) * dist, 0.5, sin(ang) * dist)
	var e: Node3D = ENEMY.instantiate()
	add_child(e)
	e.global_position = pos
	_probes.append({"name": pname, "dist": dist, "inside": inside, "node": e})


func _evaluate(seed_arg: int) -> void:
	var inside_total := 0
	var inside_hit := 0
	var outside_total := 0
	var outside_hit := 0
	var results: Array = []

	for p in _probes:
		var e: Node3D = p["node"]
		var alive := true
		var moved := 0.0
		if is_instance_valid(e):
			var a = e.get("_alive")
			alive = (a == null) or bool(a)
			moved = e.global_position.distance_to(p["p0"])
		else:
			alive = false  # freed => definitely damaged
		# Authoritative signal: an enemy's `_alive` only flips when its real
		# damage() was invoked by the blast. Movement is diagnostic only
		# (physics settling can nudge undamaged bodies a few cm).
		var damaged := not alive

		if p["inside"]:
			inside_total += 1
			if damaged:
				inside_hit += 1
		else:
			outside_total += 1
			if damaged:
				outside_hit += 1

		results.append({
			"name": p["name"],
			"dist": snappedf(p["dist"], 0.01),
			"inside": p["inside"],
			"damaged": damaged,
			"alive": alive,
			"moved": snappedf(moved, 0.01),
		})

	var coverage := 0.0 if inside_total == 0 else float(inside_hit) / float(inside_total)
	var precision := 1.0 if outside_total == 0 else float(outside_total - outside_hit) / float(outside_total)
	var score := MAX_POINTS * coverage * precision

	# DIAGNOSTIC, NOT SCORED: did the blast also damage the player? The shipped
	# grenade spares them; our spec never required it, so this does not affect the
	# score. Reported so the divergence is visible in the data.
	var player_damaged := false
	if _player != null and is_instance_valid(_player):
		player_damaged = int(_player.get("_coins")) < PLAYER_COINS

	var report := {
		"dimension": "damage",
		"max": MAX_POINTS,
		"score": snappedf(score, 0.01),
		"player_damaged_DIAGNOSTIC_NOT_SCORED": player_damaged,
		"coverage": snappedf(coverage, 0.001),
		"precision": snappedf(precision, 0.001),
		"seed": seed_arg,
		"inside_hit": inside_hit,
		"inside_total": inside_total,
		"outside_hit": outside_hit,
		"outside_total": outside_total,
		"results": results,
	}
	_write("damage.json", report)
	print("VERIFIER_DAMAGE_SCORE=", report["score"], "/", MAX_POINTS,
		"  coverage=", report["coverage"], " precision=", report["precision"])


func _wait_physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _get_seed() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			return int(a.substr(5))
	return 12345


func _write(fname: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(OUT_DIR + "/" + fname, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
