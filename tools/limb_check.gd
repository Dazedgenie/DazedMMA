extends SceneTree
## Plays real seeded fights through the fight screen without drawing them and checks the skinned bodies every frame
## (D395; docs/13 "Limbs that stay put"): an elbow or knee swinging round to the other side of the limb from one frame
## to the next, a joint jumping further in a frame than a body can move, a knee bent backwards, a hand or foot through
## the canvas, a leg locked straight on its foot, a foot that can't reach where the pieces put it. Prints a count of
## each by what the fighter was doing, and the worst frames with the seconds to film them from
## (tools/motion_preview.gd --from=). Headless:
##   godot --headless --script res://tools/limb_check.gd -- --pairs=boxer:kicker,muay_thai:dirty_boxer --seconds=300
## --pairs= red:blue pairs, --seed= the first seed (each pair also plays seed+1 ... with --fights=n), --seconds= how
## much of each fight to play (0 the whole fight), --kind= lists only that kind's worst frames, --all counts the clinch,
## the ground and rig poses too (by default only frames with both men on their feet, drawn from the pieces).

const FPS: int = 24
## An elbow or knee whose bend turns further than this round the line from shoulder to wrist (hip to ankle) in one frame
## swung round the limb. Only counted when the limb is bent enough for its bend to show.
const FLIP_DEGREES: float = 75.0
const FLIP_BENT: float = 0.06  # metres from the middle of the shoulder-wrist line
## A joint that moves further than this in one frame (metres, at FPS) jumped.
const JUMP_METRES: float = 0.45
## A knee bent backwards: its bend points this far behind his hips' facing (cosine), with the leg bent.
const BACK_KNEE: float = -0.35
## A leg with its foot on the canvas this straight (hip to ankle over the leg's length) is being pulled off its foot:
## the foot left behind as he moves.
const STRETCHED: float = 0.995
## A foot or glove this far (metres) from where the pieces put it couldn't reach there.
const SHORT_BY: float = 0.04
const JOINTS := {"elbow_l": "LeftForeArm", "elbow_r": "RightForeArm", "wrist_l": "LeftHand", "wrist_r": "RightHand",
	"knee_l": "LeftLeg", "knee_r": "RightLeg", "ankle_l": "LeftFoot", "ankle_r": "RightFoot", "head": "Head"}
const LIMBS := [["arm_l", "LeftArm", "LeftForeArm", "LeftHand"], ["arm_r", "RightArm", "RightForeArm", "RightHand"],
	["leg_l", "LeftUpLeg", "LeftLeg", "LeftFoot"], ["leg_r", "RightUpLeg", "RightLeg", "RightFoot"]]

var _pairs: Array = [["boxer", "kicker"], ["muay_thai", "dirty_boxer"], ["karate", "counter_striker"], ["leg_kicker", "brawler"]]
var _seed: int = 35001
var _fights: int = 1
var _seconds: float = 300.0
var _standing: bool = true
var _counts := {}
var _worst: Array = []
var _frames: int = 0
## --kind= lists only the worst frames of that kind ("short_foot", "jump ankle", ...).
var _kind: String = ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pairs="):
			_pairs = []
			for pair: String in arg.trim_prefix("--pairs=").split(","):
				_pairs.append(pair.split(":"))
		if arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--fights="):
			_fights = int(arg.trim_prefix("--fights="))
		if arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--kind="):
			_kind = arg.trim_prefix("--kind=")
		if arg == "--all":
			_standing = false
	_run.call_deferred()


func _run() -> void:
	for pair: Array in _pairs:
		for n in _fights:
			await _check(String(pair[0]), String(pair[1]), _seed + n)
	print("\nLimb check: %d frames (%d s of fights at %d fps)" % [_frames, _frames / FPS, FPS])
	var totals := {}
	for key: String in _counts:
		var kind: String = key.left(14).strip_edges()
		totals[kind] = int(totals.get(kind, 0)) + int(_counts[key])
	for kind: String in totals:
		print("  total %-14s %6d  (%.2f%% of frames)" % [kind, totals[kind], 100.0 * float(totals[kind]) / maxf(_frames * 2, 1)])
	var kinds: Array = _counts.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return int(_counts[a]) > int(_counts[b]))
	for key: String in kinds.slice(0, 60):
		print("  %6d  %s" % [_counts[key], key])
	_worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.size) > float(b.size))
	print("\nWorst frames:")
	for w: Dictionary in _worst.filter(func(w: Dictionary) -> bool: return float(w.size) < 1.0 and String(w.kind).begins_with(_kind)).slice(0, 40):
		print("  %-22s %6.2f  %s v %s seed %d  --from=%.2f  %s" % [w.kind, w.size, w.red, w.blue, w.seed, w.at, w.what])
	quit()


func _check(red: String, blue: String, fight_seed: int) -> void:
	var main: Node3D = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	main.record_dir = ""
	main.start_fight({"red": red, "blue": blue, "seed": fight_seed, "sound_volume": 0.0, "easy": true, "moments": false})
	main.set_process(false)
	main.arena.set_process(false)
	main.driver.normal_rate = 1.0
	main.driver.auto_slow = false
	main.driver.flourishes = false
	var last: Array = [{}, {}]
	var frame: int = 0
	var sim: FightSim = main.driver.sim
	while not sim.is_over() and (_seconds <= 0.0 or frame < _seconds * FPS):
		main.driver.held = false
		main.driver.advance(1.0 / FPS)
		main.arena._process(1.0 / FPS)
		frame += 1
		# On the feet and drawn from the pieces (not a rig pose: the clinch, a takedown, a man down).
		var arena: ArenaView = main.arena
		var standing: bool = sim.situation.is_standing() and sim.situation.position != PositionLibrary.CLINCH \
			and arena._takedown.is_empty() and arena._clinch_shown == "" and not sim.fighters[0].is_down() \
			and not sim.fighters[1].is_down()
		for i in 2:
			var figure: FighterFigure = main.arena.figures[i]
			if figure.body == null:
				continue
			var now: Dictionary = _read(figure.body)
			var pose: Dictionary = figure.body_pose()
			for side: String in ["l", "r"]:
				var want: Vector3 = Vector3(pose["ankle_" + side]) + Basis(pose["foot_" + side]).y * (figure.body._at("RightFoot").y - float(pose.ankle_up))
				var hand: Vector3 = pose["wrist_" + side]
				now["short_foot_" + side] = figure.body._world_at("LeftFoot" if side == "l" else "RightFoot").distance_to(want)
				now["short_hand_" + side] = figure.body._world_at("LeftHand" if side == "l" else "RightHand").distance_to(hand)
			if (standing or not _standing) and not Dictionary(last[i]).is_empty():
				_frames += 1 if i == 0 else 0
				_judge(now, last[i], sim, i, {"red": red, "blue": blue, "seed": fight_seed, "at": float(frame) / FPS})
			last[i] = now
	root.remove_child(main)
	main.free()
	await process_frame


## The body's joints in the world, the bends of its limbs and its hips' facing.
func _read(body: SkinnedBody) -> Dictionary:
	var out := {}
	for key: String in JOINTS:
		out[key] = body._world_at(JOINTS[key])
	for limb: Array in LIMBS:
		var root: Vector3 = body._world_at(limb[1])
		var middle: Vector3 = body._world_at(limb[2])
		var end: Vector3 = body._world_at(limb[3])
		var along: Vector3 = (end - root).normalized()
		var off: Vector3 = middle - root.lerp(end, 0.5)
		off -= off.project(along)
		var length: float = root.distance_to(middle) + middle.distance_to(end)
		out[limb[0]] = {"bend": off, "along": along, "straight": root.distance_to(end) / maxf(length, 0.001), "low": end.y < 0.2}
	var hips: Transform3D = body.skeleton.global_transform * body.skeleton.get_bone_global_pose(body._ids.Hips)
	var turn: Basis = hips.basis.orthonormalized() * Transform3D(body._rest_world.Hips).basis.orthonormalized().inverse()
	out.forward = turn * Vector3.FORWARD  # The body stands facing -Z at rest.
	out.hips = hips.origin
	return out


func _judge(now: Dictionary, was: Dictionary, sim: FightSim, i: int, where: Dictionary) -> void:
	var f: FighterState = sim.fighters[i]
	var doing: String = "%s %s" % [f.action_id if f.action_id != "" else "-", f.phase]
	if not sim.situation.is_standing():
		doing = "%s %s" % [sim.situation.position, doing]
	for limb: Array in LIMBS:
		var a: Dictionary = now[limb[0]]
		var b: Dictionary = was[limb[0]]
		var bend: Vector3 = a.bend
		var before: Vector3 = b.bend
		if bend.length() > FLIP_BENT and before.length() > FLIP_BENT:
			var turned: float = rad_to_deg(bend.angle_to(before))
			if turned > FLIP_DEGREES:
				_note("flip " + String(limb[0]).left(3), doing, turned / 90.0, where, i)
		if String(limb[0]).begins_with("leg") and a.low and float(a.straight) > STRETCHED:
			_note("stretched leg", doing, float(a.straight), where, i)
		if String(limb[0]).begins_with("leg") and bend.length() > FLIP_BENT:
			var facing: float = bend.normalized().dot(now.forward)
			if facing < BACK_KNEE:
				_note("back knee", doing, -facing, where, i)
	for key: String in ["short_foot_l", "short_foot_r"]:
		if float(now[key]) > SHORT_BY:
			_note(key.left(10), doing, float(now[key]), where, i)
	var carried: Vector3 = Vector3(now.hips) - Vector3(was.hips)
	if carried.length() > 1.0:
		return  # Put somewhere else at once (a new round from the corners), not a limb.
	for key: String in JOINTS:
		var moved: float = (Vector3(now[key]) - Vector3(was[key]) - carried).length()
		if moved > JUMP_METRES:
			_note("jump " + key.left(key.find("_")) if key.contains("_") else "jump " + key, doing, moved, where, i)
		if Vector3(now[key]).y < -0.04 and key != "head":
			_note("under canvas", doing, -Vector3(now[key]).y * 10.0, where, i)


func _note(kind: String, doing: String, size: float, where: Dictionary, i: int) -> void:
	var key: String = "%-14s %s" % [kind, doing]
	_counts[key] = int(_counts.get(key, 0)) + 1
	var w: Dictionary = where.duplicate()
	w.kind = kind + (" (red)" if i == 0 else " (blue)")
	w.size = size
	w.what = doing
	_worst.append(w)
	if _worst.size() > 4000:
		_worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.size) > float(b.size))
		_worst.resize(400)
