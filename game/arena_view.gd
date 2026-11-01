class_name ArenaView
extends Node3D
## The local-fight-night view (docs/13): a low-poly octagon seen through a
## three-quarter perspective camera, the two fighters (FighterFigure), the range or
## position tag on the canvas between them, and the camera moving in for the clinch
## and the ground. Presentation only: it reads the fight through the FightDriver.
##
## Sim spots are metres on the canvas: sim (x, y) is 3D (x, 0, y), the cage's centre
## is the origin, and the fence panels face the axes and diagonals (Octagon.NORMALS).
## The debug overlay (F3) adds what the old top-down cage view (D106) showed: the
## near-the-fence and pinned lines and the distance each fighter is walking toward.

const FIGHTER_COLOURS: Array[Color] = [Color("#e8484a"), Color("#3d8bff")]
## Vertical metres of view at the focus point, standing, in the clinch, and on the ground.
const ZOOM_STANDING: float = 5.8
const ZOOM_CLINCH: float = 4.8
const ZOOM_GROUND: float = 4.6
## How fast the camera follows and zooms (per second).
const CAMERA_SPEED: float = 2.5
## The camera follows this share of the way from the cage's centre to the fighters.
const FOLLOW_SHARE: float = 0.85
## Lower three-quarter view, about 28° down; enough elevation to read grappling.
const CAMERA_FROM := Vector3(1.0, 0.76, 1.0)
## The skinned body the fighters are drawn with (D285); "" draws today's faceted pieces.
const BODY := SkinnedBody.TRIPO_BODY
const TAG_COLOURS := {
	"out": Color("#adb5bd"), "long": Color("#69db7c"), "mid": Color("#ffd43b"),
	"pocket": Color("#ffa94d"), "clinch": Color("#da77f2"),
}
const TAG_NAMES := { "out": "Out of range", "long": "Long range", "mid": "Mid range", "pocket": "Pocket", "clinch": "Clinch" }
## Where the top fighter is against the man underneath in each ground position (D210), in the bottom man's
## own frame: `at` is (metres from his hips toward his feet, metres to his side; negative along is toward
## his head; positive across is his side away from the camera) and `face` the way the top man faces
## (Vector2(1, 0) faces the same way as him, toward his feet). He lies across the screen, or with
## `facing_camera` sits facing it.
## The sim only knows the two are tangled up; the view lays them out. A position not here (and leg locks)
## keeps them face to face, as the sim has them.
const GROUND_LAYOUTS := {
	"full_guard": { "at": Vector2(0.55, 0.0), "face": Vector2(-1.0, 0.0) },
	"half_guard": { "at": Vector2(0.2, 0.25), "face": Vector2(-1.0, -0.45) },
	"side_control": { "at": Vector2(-0.35, 0.55), "face": Vector2(0.0, -1.0) },
	"mount": { "at": Vector2(-0.2, 0.0), "face": Vector2(-1.0, 0.0) },
	"back_control": { "at": Vector2(-0.5, 0.0), "face": Vector2(1.0, 0.0), "facing_camera": true },
	"crucifix": { "at": Vector2(-0.55, 0.45), "face": Vector2(0.4, -1.0) },  # Across him from the head side (D264).
}
## The man underneath lies across the screen, feet turned this far (radians) away from the camera (D210).
const LIE_TURN: float = 0.45
## How fast a fighter slides and turns to his spot in a new position (per second).
const LAYOUT_SPEED: float = 6.0
## Space for the two leaning torsos in the clinch; affects only their drawn positions. Chest to chest, close
## enough for an underhook to reach round his back (D282, was 0.82).
const CLINCH_BODY_GAP: float = 0.68
## The clinch from the rig (D286): with skinned bodies, a clinch where both men are holding or fighting for
## grips is posed by ClinchPair on two hidden rigs, and the bodies follow those. The fence's moves are posed
## there too (D287): the drive, being held flat on it and working off it, the break, and the turns (played
## over TURN_SECONDS). The clinch takedowns play from the rig too (D288, _pose_takedown); any other move is
## drawn from today's figures; a strike (CLINCH_STRIKES) keeps the pose with only the striking limb from today's
## figure. The change either way, and from one grip to the next, eases over CLINCH_EASE seconds.
const CLINCH_POSE_MOVES: Array[String] = ["pummel", "strip_grip", "collar_tie", "fence_drive", "turn_him", "spin_off",
	"clinch_break"]
## Strikes in the clinch thrown from the rig's pose: only the striking arm or leg follows today's figure.
const CLINCH_STRIKES: Array[String] = ["knee", "short_hook", "short_uppercut", "elbow"]
const CLINCH_EASE: float = 0.25
## A turn on the fence or a spin-off (D287): the two go round each other over this many seconds.
const TURN_SECONDS: float = 0.45
## The fence giving where a man is held on it (D287): it bows PRESS_DEPTH metres while he is pressed there; a
## slam into it (a drive or a turn ending with him pinned) bows it up to SLAM_DEPTH more (times how hard),
## springing back at SLAM_HZ with SLAM_DAMPING (0 rings for ever, 1 no bounce). He sinks in with it.
const PRESS_DEPTH: float = 0.03
const SLAM_DEPTH: float = 0.09
const SLAM_HZ: float = 6.0
const SLAM_DAMPING: float = 0.3
## How hard a slam is: a drive's from DRIVE_SLAM_MIN (barely moved) to 1 (driven SLAM_FULL_AFTER metres or
## more), a turn's TURN_SLAM.
const DRIVE_SLAM_MIN: float = 0.5
const SLAM_FULL_AFTER: float = 1.0
const TURN_SLAM: float = 0.7
## Clinch takedowns from the rig (D288): a double leg, trip, hip throw or guard pull in the clinch plays
## TakedownPair's path, falling through the attempt and landing when it works; the bodies ease into it over
## TAKEDOWN_EASE, back to the clinch over STUFF_EASE when it is stopped, down into the sprawl over SPRAWL_SECONDS,
## and from the landing to today's figures over LAND_EASE. Near the fence each pose along the way is moved in
## to keep FENCE_SPOTS on both men FENCE_GAP metres inside it.
const TAKEDOWN_EASE: float = 0.15
const STUFF_EASE: float = 0.3
const SPRAWL_SECONDS: float = 0.3
const LAND_EASE: float = 0.45
const FENCE_GAP: float = 0.06
const FENCE_SPOTS: Array[String] = ["head", "back_of_head", "chin", "back", "lower_back", "seat", "chest", "belly"]
const TAKEDOWN_ENDED := "takedown ended"
## The ground positions from the rig (D289): full guard, half guard, side control, mount, the back and the
## crucifix are posed by GroundPair on the hidden rigs, laid out as today's figures lay them out (lay_out), with
## the grips held and ground and pound thrown from the pose. A new position eases in over GROUND_EASE, a grip
## over CLINCH_EASE. Standing up, getting up and a submission locked in go back to today's figures.
const GROUND_EASE: float = 0.4
## Moves on the ground the rig doesn't pose: today's figures draw them.
const GROUND_UNPOSED: Array[String] = ["stand_up", "get_up"]
## A sweep, a bridge or getting out from under the back (GroundPair.ROLLS) rolls them over in this many seconds.
const ROLL_SECONDS: float = 0.6
## A ground strike is cocked over this share of its telegraph and wind-up and thrown over the rest (D289).
const COCK_SHARE: float = 0.65
## The tag grows this much when the range or position changes, then settles (docs/06 §2).
const TAG_BUMP: float = 1.7
## Standing, the sim's ranges are wider than a person's reach (pocket up to 1.5 m, long range 3 m apart), so
## the view draws the gap at human scale (D281): a gap of DRAWN_FROM metres or less is drawn as it is, each
## metre more out to DRAWN_UNTIL is drawn as DRAWN_SHARE of a metre, and beyond that a metre is a metre again.
const DRAWN_FROM: float = 0.9
const DRAWN_SHARE: float = 0.45
const DRAWN_UNTIL: float = 3.0
## A strike thrown out of range (the sim says "out of range") steps in this much less than it would need.
const SHORT_BY: float = 0.3
## The most a strike steps in (metres), and the closest two stepping strikers get (D281); one man stepping in
## alone gets as close as his strike's contact if that is closer (D360).
const LUNGE_MAX: float = 0.75
const LUNGE_CLOSEST: float = 0.85

## A man was slammed into the fence (D287), `strength` 0–1: the fence rattles (StrikeSounds.play_rattle).
signal fence_slammed(strength: float)
## A takedown landed on the canvas (D288), `strength` 0–1: a thud (StrikeSounds.play_thud).
signal takedown_landed(strength: float)

var driver: FightDriver
var camera: Camera3D
var figures: Array[FighterFigure] = []
## The two hidden rigs that pose the clinch for the bodies (D286), and the clinch pose shown ("" none).
var _clinch_rigs: Array[FighterRig] = []
var _clinch_shown: String = ""
## The fence (D287): the last clinch pose shown ([pair, frame] from ClinchPair.effective, or empty); a turn under
## way ({from, left, slam}); who was held on the fence last frame; a drive under way last frame and how far it
## has gone; the fence's bow {at, depth, speed}.
var _clinch_last: Array = []
var _turn: Dictionary = {}
var _held_was: int = -1
var _drive_was: bool = false
var _drive_travel: float = 0.0
var _drive_from := Vector2.ZERO
var _bow := {"at": Vector3.ZERO, "depth": 0.0, "speed": 0.0}
## A clinch takedown under way (D288): {by, action, path (TakedownPair keys), x (how far along it), state
## "attempt", "landing" or "sprawl", left (seconds of the landing or the sprawl), from (x it started from)}.
var _takedown: Dictionary = {}
## Where the view draws the ground position away from the sim's spots after a takedown landed somewhere else
## (D288: a hip throw puts him on the far side), until they are back on their feet.
var _ground_shift := Vector2.ZERO
## The ground from the rig (D289): the position it is posing ("" none: where + who is on top), its frame and
## the side of him the top man is on, kept while the position lasts so the pose doesn't swing round when the sim
## nudges their spots.
var _ground_key: String = ""
var _ground_frame := Transform3D.IDENTITY
var _ground_far: float = -1.0
## The last ground pose shown, [pair, frame, the man on top], and a roll under way ({from: that, left}).
var _ground_last: Array = []
var _roll: Dictionary = {}
## Light up scouted tells (D51): a toggle so the playtest can compare cue on and off.
var tell_cues: bool = true
var debug_marks: bool = false:
	set(value):
		debug_marks = value
		if _debug != null:
			_debug.visible = value

var _tag: Label3D
var _tag_text: String = ""
var _tag_scale: float = 1.0
var _focus := Vector3.ZERO
var _zoom: float = ZOOM_STANDING
var _debug: Node3D
var _want_rings: Array[MeshInstance3D] = []
## Per fighter: the tell's limb and how many fight ticks it stays lit.
var _tell_limb: Array[String] = ["", ""]
var _tell_until: Array[int] = [-1, -1]
## Per fighter, smoothed: how far the view moves him off his sim spot, and the way he faces (radians).
var _offset: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _facing: Array[float] = [0.0, 0.0]
var _facing_set: bool = false
var _venue: LocalVenue


func _ready() -> void:
	_build_cage()
	_build_camera()
	_tag = FighterFigure._label(48)
	_tag.position = Vector3(0.0, 0.05, 0.0)
	add_child(_tag)
	_debug = Node3D.new()
	_debug.visible = debug_marks
	add_child(_debug)
	_build_debug_marks()


## Starts showing a fight (null clears the canvas).
func watch(p_driver: FightDriver) -> void:
	if driver != null and driver.sim.event_emitted.is_connected(_on_event):
		driver.sim.event_emitted.disconnect(_on_event)
	for f in figures:
		f.queue_free()
	figures.clear()
	for rig in _clinch_rigs:
		rig.queue_free()
	_clinch_rigs.clear()
	_clinch_shown = ""
	_clinch_last = []
	_turn = {}
	_held_was = -1
	_drive_was = false
	_bow = {"at": Vector3.ZERO, "depth": 0.0, "speed": 0.0}
	_takedown = {}
	_ground_shift = Vector2.ZERO
	_ground_key = ""
	_ground_last = []
	_roll = {}
	_tell_limb = ["", ""]
	_tell_until = [-1, -1]
	_offset = [Vector2.ZERO, Vector2.ZERO]
	_facing_set = false
	driver = p_driver
	_tag.visible = driver != null
	if driver == null:
		return
	for i in driver.sim.fighters.size():
		var southpaw: bool = driver.sim.fighters[i].profile.get("stance", "orthodox") == "southpaw"
		var figure := FighterFigure.new(FIGHTER_COLOURS[i], southpaw, i)
		add_child(figure)
		if BODY != "":
			figure.use_body(BODY)
		figures.append(figure)
	for i in figures.size():
		figures[i].opponent = figures[1 - i]  # Strikes aim at the other man (D281).
	if figures.size() == 2 and figures[0].body != null and figures[1].body != null:
		for figure in figures:
			var rig := FighterRig.new(figure.colour)
			add_child(rig)
			rig.visible = false  # Only the bodies show it.
			rig.fit(figure.body.measure())
			_clinch_rigs.append(rig)
	driver.sim.event_emitted.connect(_on_event)
	_focus = Vector3.ZERO
	_zoom = ZOOM_STANDING
	_tag_text = ""


func _process(delta: float) -> void:
	if driver == null:
		_place_camera(delta)
		return
	var sim: FightSim = driver.sim
	var spots: Array[Vector2] = [driver.shown_pos(0), driver.shown_pos(1)]
	var placed: Array[Dictionary] = ground_spots(sim, spots)
	if sim.situation.phase != PositionLibrary.PHASE_GROUND:
		_ground_shift = Vector2.ZERO
	if sim.situation.is_standing():
		var drawn: Array[Vector2] = standing_spots(spots)
		for i in placed.size():
			placed[i].at = drawn[i]
	else:
		for i in placed.size():
			placed[i].at += _ground_shift
	var k: float = 1.0 - exp(-LAYOUT_SPEED * delta)
	var shown: Array[Vector2] = []
	for i in figures.size():
		var want: float = placed[i].facing
		_offset[i] = _offset[i].lerp(placed[i].at - spots[i], k if _facing_set else 1.0)
		_facing[i] = lerp_angle(_facing[i], want, k) if _facing_set else want
		shown.append(spots[i] + _offset[i])
	if sim.situation.is_standing() and figures.size() == 2:
		shown = strike_spots(sim, shown, [figures[0].knock, figures[1].knock], driver.alpha())
	_side_labels()
	for i in figures.size():
		var at: Vector2 = shown[i]
		figures[i].label_scale = zoom_share()
		figures[i].show_state(sim, i, at, at + Vector2.from_angle(_facing[i]), delta, delta * driver.rate())
		figures[i].show_tell(_tell_limb[i] if tell_cues and sim.now <= _tell_until[i] else "")
	_pose_clinch(sim, delta)
	_facing_set = true
	var middle: Vector2 = (spots[0] + spots[1]) / 2.0 + _ground_shift
	if _venue != null:
		_venue.show_near_fence(shown, delta)
	_show_tag(sim, middle, delta)
	_place_camera(delta, middle, sim)
	if debug_marks:
		for i in _want_rings.size():
			var want: float = sim.last_wanted_distance(i)
			_want_rings[i].visible = want > 0.0 and sim.situation.is_standing()
			var o: Vector2 = spots[1 - i]
			_want_rings[i].position = Vector3(o.x, 0.03, o.y)
			_want_rings[i].scale = Vector3(want, 1.0, want)


## Poses the bodies from the rig in the clinch (D286, D287; CLINCH_POSE_MOVES), easing in and out, playing the
## turns on the fence and bowing the fence where a man is held on it.
func _pose_clinch(sim: FightSim, delta: float) -> void:
	if _clinch_rigs.is_empty():
		return
	var held: int = held_now(sim)
	_track_drive(sim, held)
	if _pose_takedown(sim, delta):
		for figure in figures:
			figure.body.settle(delta)
		_bow_fence(-1, delta)  # Off the fence: it springs back.
		return
	if _pose_ground(sim, delta):
		for figure in figures:
			figure.body.settle(delta)
		_bow_fence(-1, delta)
		return
	var built: Dictionary = {}
	var frame := Transform3D.IDENTITY
	if rig_clinch(sim):
		var collar: int = -1
		for i in 2:
			if sim.fighters[1 - i].tied_up_ticks > 0:
				collar = i
		built = ClinchPair.build(sim.grips(), [figures[0].arm_letter(0), figures[0].arm_letter(1)], collar, held,
			clinch_motion(sim, held))
		frame = fence_frame(held) if built.kind == "fence" else clinch_frame()
	if not _turn.is_empty():
		_pose_turn(sim, built, frame, delta)
	else:
		_pose_built(sim, built, frame)
	for figure in figures:
		figure.body.settle(delta)
	_bow_fence(held, delta)


## Poses `built` (empty: today's figures) in `frame`, with any strike's limb from today's figure.
func _pose_built(sim: FightSim, built: Dictionary, frame: Transform3D) -> void:
	var strikes: Array = [[], []]  # The limbs thrown from the pose, each man's, as follow_joints names them.
	if not built.is_empty():
		for i in 2:
			var action: String = sim.fighters[i].action_id
			if CLINCH_STRIKES.has(action):
				var limb: String = FighterFigure.limb_for(action)
				var letter: String = figures[i].arm_letter(0 if limb.begins_with("lead") else 1)
				strikes[i] = [("leg_" if limb.ends_with("leg") else "arm_") + letter]
	var shown: String = "" if built.is_empty() else str(built.pair) + str(strikes)
	if shown != _clinch_shown:  # Into or out of the rig's clinch, or a new grip: ease to it.
		if _clinch_shown != TAKEDOWN_ENDED:  # Out of a takedown it eases at its own pace (_end_takedown).
			for figure in figures:
				figure.body.ease_over(CLINCH_EASE)
		_clinch_shown = shown
	_clinch_last = []
	if built.is_empty():
		return
	ClinchPair.pose(_clinch_rigs[0], _clinch_rigs[1], built, frame)
	_clinch_last = ClinchPair.effective(built, frame)
	for i in 2:
		figures[i].body.follow(_clinch_rigs[i])
		if not (strikes[i] as Array).is_empty():
			var only: Array[String] = []
			only.assign(strikes[i])
			figures[i].body.follow_joints(figures[i].body_pose(), only)


## The ground positions from the rig (D289): poses the position the two are in (GroundPair) with its grips and
## any ground strike thrown from it. Returns false when the rig doesn't pose the ground now (rig_ground).
func _pose_ground(sim: FightSim, delta: float) -> bool:
	if not rig_ground(sim):
		_ground_key = ""
		_ground_last = []
		_roll = {}
		return false
	var where: String = sim.situation.position
	var top: int = sim.situation.roles.find(PositionLibrary.TOP)
	var key: String = "%s %d" % [where, top]
	var new_position: bool = key != _ground_key
	if new_position:
		var laid: Array = ground_frame(sim, top)
		_ground_frame = laid[0]
		_ground_far = laid[1]
		_ground_key = key
	var f: FighterState = sim.fighters[top]
	var posture: bool = f.action_id == "posture_up" or (f.action_id == "posture_bomb" and f.phase in ["telegraph", "windup"])
	var built: Dictionary = GroundPair.build(where, ground_grips_now(sim, top), posture, _ground_far)
	var shown: String = str(built.pair)
	if not _roll.is_empty() and new_position:
		_roll.top = top
	if not _roll.is_empty() and _roll.has("top"):
		if _pose_roll(built.pair, top, delta):
			_clinch_shown = shown
			return true
	if shown != _clinch_shown:
		if _clinch_shown != TAKEDOWN_ENDED:  # Landing from a takedown eases at its own pace (_end_takedown).
			for figure in figures:
				figure.body.ease_over(GROUND_EASE if new_position else CLINCH_EASE)
		_clinch_shown = shown
	_clinch_last = []
	var pair: Dictionary = built.pair
	var to: Dictionary = {}
	var t: float = 0.0
	if GroundPair.STRIKES.has(f.action_id) and not posture:
		var letter: String = figures[top].arm_letter(0 if FighterFigure.limb_for(f.action_id).begins_with("lead") else 1)
		var keys: Array = GroundPair.strike(pair, f.action_id, letter)
		var thrown: Array = strike_blend(sim, f, driver.alpha())
		if not thrown.is_empty():
			var stage: Array = [pair, keys[0], keys[1], pair]
			pair = stage[int(thrown[0])]
			to = stage[int(thrown[0]) + 1]
			t = float(thrown[1])
	FighterRig.pose_pair(_clinch_rigs[top], _clinch_rigs[1 - top], pair, _ground_frame, to, t)
	for i in 2:
		figures[i].body.follow(_clinch_rigs[i])
	_ground_last = [built.pair, _ground_frame, top]
	return true


## A roll under way (D289): from the pose before it over onto their sides to `now` (the new position, fighter
## `top` on top). False once it is over.
func _pose_roll(now: Dictionary, top: int, delta: float) -> bool:
	var from: Array = _roll.from
	var was_top: int = int(from[2])
	if not _roll.has("path"):
		var to: Dictionary = ClinchPair.swap(now) if top != was_top else now
		_roll.path = GroundPair.roll_path(from[0], from[1], to, _ground_frame)
	_roll.left = float(_roll.left) - delta
	var t: float = clampf(1.0 - float(_roll.left) / ROLL_SECONDS, 0.0, 1.0)
	TakedownPair.pose_along(_clinch_rigs[was_top], _clinch_rigs[1 - was_top], _roll.path, smoothstep(0.0, 1.0, t) * 2.0)
	for i in 2:
		figures[i].body.follow(_clinch_rigs[i])
	if t >= 1.0:
		_roll = {}
		_ground_last = [now, _ground_frame, top]
	return true


## How far a ground strike is (D289), [stage, share]: stage 0 cocking it (the first COCK_SHARE of its telegraph and
## wind-up), 1 throwing it (the rest of the wind-up; landed through its active part, which can be a tick long),
## 2 bringing it back (recovery); empty when he isn't striking.
static func strike_blend(sim: FightSim, f: FighterState, fraction: float = 0.0) -> Array:
	var total: float = maxf(1.0, sim.phase_ticks(f, f.action_id, f.phase))
	var done: float = clampf((total - f.phase_ticks_left + fraction) / total, 0.0, 1.0)
	match f.phase:
		"telegraph", "windup":
			var telegraph: float = sim.phase_ticks(f, f.action_id, "telegraph")
			var windup: float = sim.phase_ticks(f, f.action_id, "windup")
			var so_far: float = done * total + (telegraph if f.phase == "windup" else 0.0)
			var p: float = clampf(so_far / maxf(1.0, telegraph + windup), 0.0, 1.0)
			if p < COCK_SHARE:
				return [0, smoothstep(0.0, 1.0, p / COCK_SHARE)]
			return [1, smoothstep(0.0, 1.0, (p - COCK_SHARE) / (1.0 - COCK_SHARE))]
		"active":
			return [1, 1.0]
		"recovery":
			return [2, smoothstep(0.0, 1.0, done)]
	return []


## True when the ground is drawn from the rig (D289): in a GroundPair position, no submission locked in, no
## one standing up or getting up.
func rig_ground(sim: FightSim) -> bool:
	if _clinch_rigs.is_empty() or not GroundPair.POSITIONS.has(sim.situation.position) or not sim.hold().is_empty():
		return false
	if sim.situation.roles.find(PositionLibrary.TOP) < 0:
		return false
	for f: FighterState in sim.fighters:
		if GROUND_UNPOSED.has(f.action_id):
			return false
	return true


## The ground grips as GroundPair.build takes them (D263, D264), with fighter `top` on top.
static func ground_grips_now(sim: FightSim, top: int) -> Dictionary:
	var g: Dictionary = sim.ground_grips()
	var bottom: int = 1 - top
	return {"wrists": int(g.wrists), "collar": bool(g.collar), "underhook": int(g.half_inside) == bottom,
		"crossface": int(g.half_inside) == top, "frame": bool(g.frame), "two_on_one": bool(g.two_on_one),
		"cover": sim.active_flags(bottom).has(FightSim.COVERED) or sim.fighters[bottom].action_id == FightSim.GROUND_COVER}


## The ground frame for the position the two are in with fighter `top` on top, laid out as today's figures lay
## it out (lay_out): [its origin under the bottom man's hips and its +Z toward his feet, the side of him the top man
## is on along its +X, +1 (the side away from the camera, where lay_out puts him) or -1].
func ground_frame(sim: FightSim, top: int) -> Array:
	var spots: Array[Vector2] = [driver.shown_pos(0), driver.shown_pos(1)]
	var laid: Array[Dictionary] = lay_out(sim.situation.position, top, spots)
	var bottom: int = 1 - top
	var feet: Vector2 = Vector2.from_angle(float(laid[bottom].facing))
	var z := Vector3(feet.x, 0.0, feet.y)
	var basis := Basis(Vector3.UP.cross(z), Vector3.UP, z)
	var at: Vector2 = Vector2(laid[bottom].at) + _ground_shift
	var away := -Vector3(CAMERA_FROM.x, 0.0, CAMERA_FROM.z)
	return [Transform3D(basis, Vector3(at.x, 0.0, at.y)), 1.0 if away.dot(basis.x) > 0.0 else -1.0]


## A turn under way (D287): the two go round each other from the pose before it to the one now (`built` in
## `frame`; after a spin-off, standing apart), then the fence rattles if it put a man on it.
func _pose_turn(sim: FightSim, built: Dictionary, frame: Transform3D, delta: float) -> void:
	var to: Array = []
	if built.is_empty():  # Spun off: standing apart where they were, the other way round.
		to = [ClinchPair.apart(), Transform3D(_turn.from[1]) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)]
	else:
		to = ClinchPair.effective(built, frame)
	_turn.left = float(_turn.left) - delta
	var t: float = clampf(1.0 - float(_turn.left) / TURN_SECONDS, 0.0, 1.0)
	ClinchPair.turning(_clinch_rigs[0], _clinch_rigs[1], _turn.from, to, t)
	for i in 2:
		figures[i].body.follow(_clinch_rigs[i])
	if t >= 1.0:
		if bool(_turn.slam) and held_now(sim) >= 0:
			_slam(TURN_SLAM)
		_turn = {}
		_clinch_last = to
		_clinch_shown = "turned"  # Whatever comes next eases from here.


## A clinch takedown (D288): starts one when a man begins a TakedownPair move in the rig's clinch, and poses it
## while it lasts (the attempt, falling as it goes; the landing once it works; the sprawl that stopped it).
## Returns false when there is none to pose.
func _pose_takedown(sim: FightSim, delta: float) -> bool:
	if _takedown.is_empty() and not _start_takedown(sim):
		return false
	var by: int = int(_takedown.by)
	var f: FighterState = sim.fighters[by]
	var last: float = float((_takedown.path as Array).size() - 1)
	match String(_takedown.state):
		"attempt":
			if f.action_id != String(_takedown.action) or f.phase == "recovery" \
					or sim.situation.position != PositionLibrary.CLINCH:
				_end_takedown(STUFF_EASE)  # Stopped some other way (a knee that drops him, the round ending).
				return false
			_takedown.x = attempt_x(sim, f, last, float(TakedownPair.TIMING[_takedown.action].fall), driver.alpha())
		"landing":
			_takedown.left = float(_takedown.left) - delta
			var t: float = clampf(1.0 - float(_takedown.left) / float(_takedown.seconds), 0.0, 1.0)
			_takedown.x = lerpf(float(_takedown.from), last, pow(t, 1.5))  # Quicker as he comes down.
		"sprawl":
			if f.action_id != String(_takedown.action) or sim.situation.position != PositionLibrary.CLINCH:
				_end_takedown(STUFF_EASE)  # Back up out of the sprawl.
				return false
			_takedown.left = float(_takedown.left) - delta
			_takedown.x = smoothstep(0.0, 1.0, 1.0 - float(_takedown.left) / SPRAWL_SECONDS)
	TakedownPair.pose_along(_clinch_rigs[by], _clinch_rigs[1 - by], _takedown.path, float(_takedown.x))
	for i in 2:
		figures[i].body.follow(_clinch_rigs[i])
	if String(_takedown.state) == "landing" and float(_takedown.x) >= last:
		takedown_landed.emit(float(_takedown.thud))
		_end_takedown(LAND_EASE)
	return true


## Starts a takedown when a man in the clinch the rig posed last frame begins one: its path from that pose.
func _start_takedown(sim: FightSim) -> bool:
	if _clinch_last.is_empty() or sim.situation.position != PositionLibrary.CLINCH or not sim.hold().is_empty():
		return false
	for by in 2:
		var f: FighterState = sim.fighters[by]
		if not TakedownPair.MOVES.has(f.action_id) or f.phase == "recovery":
			continue
		var start: Array = _clinch_last  # [pair, frame] with red as "a": turned round when blue takes him down.
		if by == 1:
			start = [ClinchPair.swap(_clinch_last[0]), Transform3D(_clinch_last[1]) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)]
		var lying: Array = landing_turn(sim, by, f.action_id)
		var path: Array = TakedownPair.path(f.action_id, start, lying[0], lying[1])
		_keep_off_fence(path, by)
		_takedown = {"by": by, "action": f.action_id, "path": path, "x": 0.0, "state": "attempt",
			"thud": TakedownPair.TIMING[f.action_id].thud}
		for figure in figures:
			figure.body.ease_over(TAKEDOWN_EASE)
		return true
	return false


## The landing frame's turn for fighter `by`'s takedown `action` from here, laid out as today's figures will
## draw the ground position it ends in (lay_out): [the turn (its +Z toward the bottom man's feet), the side of
## him the top man is on along its +X, +1 or -1].
func landing_turn(sim: FightSim, by: int, action: String) -> Array:
	var t: Dictionary = sim.transition_for(by, action, PositionLibrary.SUCCESS)
	var top: int = by if String(t.get("roles", {}).get("actor", PositionLibrary.TOP)) == PositionLibrary.TOP else 1 - by
	var spots: Array[Vector2] = [driver.shown_pos(0), driver.shown_pos(1)]
	var laid: Array[Dictionary] = lay_out(String(t.get("to", "full_guard")), top, spots)
	var feet: Vector2 = Vector2.from_angle(float(laid[1 - top].facing))
	var z := Vector3(feet.x, 0.0, feet.y)
	var basis := Basis(Vector3.UP.cross(z), Vector3.UP, z)
	var side: Vector2 = Vector2(laid[top].at) - Vector2(laid[1 - top].at)
	return [basis, 1.0 if Vector3(side.x, 0.0, side.y).dot(basis.x) > 0.0 else -1.0]


## Moves each key of a takedown's path after the first in from the fence as far as it takes to keep both men's
## heads, backs and hips FENCE_GAP inside it (a double leg off the fence drives him along it, not through it).
func _keep_off_fence(path: Array, by: int) -> void:
	for k in range(1, path.size()):
		TakedownPair.pose_along(_clinch_rigs[by], _clinch_rigs[1 - by], path, float(k))
		var push := Vector2.ZERO
		for rig in _clinch_rigs:
			for spot: String in FENCE_SPOTS:
				var p: Vector3 = rig.point(spot)
				for normal: Vector2 in Octagon.NORMALS:
					var over: float = (Vector2(p.x, p.z) + push).dot(normal) - (Octagon.APOTHEM - FENCE_GAP)
					if over > 0.0:
						push -= normal * over
		var frame: Transform3D = path[k][1]
		path[k][1] = Transform3D(frame.basis, frame.origin + Vector3(push.x, 0.0, push.y))


## How far along its path a takedown attempt is (TakedownPair.path, `last` its last key): the entry through its
## telegraph and wind-up, then `fall` of the way from there to the landing through its active part.
static func attempt_x(sim: FightSim, f: FighterState, last: float, fall: float, fraction: float = 0.0) -> float:
	var telegraph: float = sim.phase_ticks(f, f.action_id, "telegraph")
	var windup: float = sim.phase_ticks(f, f.action_id, "windup")
	var total: float = maxf(1.0, sim.phase_ticks(f, f.action_id, f.phase))
	var done: float = clampf(total - f.phase_ticks_left + fraction, 0.0, total)
	match f.phase:
		"telegraph":
			return smoothstep(0.0, 1.0, done / maxf(1.0, telegraph + windup))
		"windup":
			return smoothstep(0.0, 1.0, (telegraph + done) / maxf(1.0, telegraph + windup))
		"active":
			return 1.0 + (last - 1.0) * fall * done / total
	return 0.0


## The takedown worked (`result` success) or half worked (a scramble): down to the canvas from where it is.
func _land(result: String) -> void:
	var td: Dictionary = _takedown
	var timing: Dictionary = TakedownPair.TIMING[td.action]
	if result == PositionLibrary.PARTIAL:
		td.path = TakedownPair.to_scramble(td.path)
		td.thud = TakedownPair.SCRAMBLE_THUD
	else:
		var landed: Vector3 = Transform3D(td.path[(td.path as Array).size() - 1][1]).origin
		var bottom: int = int(td.by) if TakedownPair.PULLS.has(td.action) else 1 - int(td.by)
		var spot: Vector2 = driver.shown_pos(bottom)
		_ground_shift = Vector2(landed.x, landed.z) - spot  # Today's figures carry on where he landed.
	td.state = "landing"
	td.from = td.x
	td.seconds = float(timing.land)
	td.left = td.seconds


## The double leg sprawled on: down onto his knees under the sprawl, held there until his move is over.
func _sprawled() -> void:
	_takedown.path = TakedownPair.to_sprawl(_takedown.path, float(_takedown.x))
	_takedown.state = "sprawl"
	_takedown.x = 0.0
	_takedown.left = SPRAWL_SECONDS


## The takedown is over: the bodies ease from where it left them to whatever comes next over `seconds`.
func _end_takedown(seconds: float) -> void:
	_takedown = {}
	_clinch_last = []
	_clinch_shown = TAKEDOWN_ENDED
	for figure in figures:
		figure.body.ease_over(seconds)


## Who is held on the fence in the clinch (D220), or -1.
func held_now(sim: FightSim) -> int:
	if sim.situation.position != PositionLibrary.CLINCH or not sim.hold().is_empty():
		return -1
	for i in 2:
		if sim.held_on_fence(i):
			return i
	return -1


## What the fence's moves are doing to the clinch pose (D287, ClinchPair.build's motion): a drive under way or
## being set up, the held man working off the fence, or a man breaking away.
func clinch_motion(sim: FightSim, held: int) -> Dictionary:
	var drive: Dictionary = sim.drive()
	if not drive.is_empty():
		return {"move": "drive", "by": int(drive.by), "step": _drive_travel}
	for i in 2:
		var f: FighterState = sim.fighters[i]
		if f.action_id == FightSim.FENCE_DRIVE and f.phase == "windup" and held != 1 - i:
			return {"move": "drive", "by": i, "step": 0.0}
		if i == held and ClinchPair.WORK_MOVES.has(f.action_id):
			return {"move": "work", "by": i, "action": f.action_id}
		if f.action_id == "clinch_break" and held < 0:
			return {"move": "break", "by": i}
	return {}


## How far a drive has gone (for the steps), and the slam when it pins him on the fence.
func _track_drive(sim: FightSim, held: int) -> void:
	var driving: bool = not sim.drive().is_empty()
	var middle: Vector2 = (driver.shown_pos(0) + driver.shown_pos(1)) / 2.0
	if driving and not _drive_was:
		_drive_travel = 0.0
	elif driving:
		_drive_travel += middle.distance_to(_drive_from)
	_drive_from = middle
	if held >= 0 and held != _held_was and _drive_was:
		_slam(lerpf(DRIVE_SLAM_MIN, 1.0, clampf(_drive_travel / SLAM_FULL_AFTER, 0.0, 1.0)))
	_drive_was = driving
	_held_was = held


## A man slammed into the fence: it bows out and rattles.
func _slam(strength: float) -> void:
	_bow.speed = float(_bow.speed) + SLAM_DEPTH * strength * TAU * SLAM_HZ
	fence_slammed.emit(strength)


## The fence bowing where the held man's back is on it, springing back once he is off it.
func _bow_fence(held: int, delta: float) -> void:
	if held >= 0 and not _clinch_last.is_empty():
		_bow.at = _clinch_rigs[held].point("back")
	var want: float = PRESS_DEPTH if held >= 0 and not _clinch_last.is_empty() else 0.0
	var w: float = TAU * SLAM_HZ
	var left: float = delta
	while left > 0.0:  # Small steps, so a long frame doesn't throw the spring.
		var dt: float = minf(left, 1.0 / 120.0)
		_bow.speed = float(_bow.speed) + (-w * w * (float(_bow.depth) - want) - 2.0 * SLAM_DAMPING * w * float(_bow.speed)) * dt
		_bow.depth = float(_bow.depth) + float(_bow.speed) * dt
		left -= dt
	if _venue != null:
		_venue.bow_fence(_bow.at, maxf(float(_bow.depth), 0.0))


## How far the fence is bowed out where he is held now (metres).
func fence_bow() -> float:
	return maxf(float(_bow.depth), 0.0)


## True when the clinch is drawn from the rig (D286): both tied up in the clinch (not in a hold), each holding
## or fighting for grips, on the fence or getting off it (D287), or striking from there.
func rig_clinch(sim: FightSim) -> bool:
	if _clinch_rigs.is_empty() or sim.situation.position != PositionLibrary.CLINCH or not sim.hold().is_empty():
		return false
	for f: FighterState in sim.fighters:
		var getting_over: bool = f.phase == "recovery" and (TakedownPair.MOVES.has(f.action_id) or f.action_id == "sprawl")
		if f.action_id != "" and not CLINCH_POSE_MOVES.has(f.action_id) and not CLINCH_STRIKES.has(f.action_id) \
				and not getting_over:  # A takedown stopped (D288): back in the clinch while he gets over it.
			return false
	return true


## The clinch pair's frame (D286): on the canvas between the two men, its +Z toward red.
func clinch_frame() -> Transform3D:
	var red: Vector3 = figures[0].global_position
	var blue: Vector3 = figures[1].global_position
	var z := Vector3(red.x - blue.x, 0.0, red.z - blue.z).normalized()
	return Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), Vector3((red.x + blue.x) / 2.0, 0.0, (red.z + blue.z) / 2.0))


## The clinch pair's frame with fighter `held` on the fence (D287): squared to the fence panel behind him, its
## origin ClinchPair.FENCE_Z in from the fence's face (out by as far as it is bowed), +Z toward red.
func fence_frame(held: int) -> Transform3D:
	var spot: Vector2 = driver.shown_pos(held)
	var n: Vector2 = Octagon.NORMALS[0]
	for normal: Vector2 in Octagon.NORMALS:
		if spot.dot(normal) > spot.dot(n):
			n = normal
	var middle: Vector2 = (driver.shown_pos(0) + driver.shown_pos(1)) / 2.0
	var at: Vector2 = middle - n * middle.dot(n) + n * (Octagon.APOTHEM + fence_bow() - ClinchPair.FENCE_Z)
	var toward_red: Vector2 = n if held == 0 else -n
	var z := Vector3(toward_red.x, 0.0, toward_red.y)
	return Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), Vector3(at.x, 0.0, at.y))


## The camera's zoom against standing (1 standing, under 1 moved in), for sizing labels.
func zoom_share() -> float:
	return _zoom / ZOOM_STANDING


## The words under the fighters: the range standing, the position when tied up.
static func tag_text(sim: FightSim) -> String:
	if sim.situation.is_standing():
		return String(TAG_NAMES.get(sim.band(), sim.band()))
	var text: String = String(sim.positions.get_position(sim.situation.position).name)
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		return "%s · %s's %s" % [text, sim.fighters[int(hold.attacker)].name, String(sim.actions.get_action(hold.action_id).name).to_lower()]
	var top: int = sim.situation.roles.find(PositionLibrary.TOP)
	if top >= 0:
		text += " · %s %s" % [sim.fighters[top].name, sim.positions.top_label(sim.situation.position)]
	return text


## Standing, where the two are drawn (D281): the same line between them, the gap shrunk to a person's reach
## (drawn_gap), moving whoever has more room off the fence, so a man on the fence stays on it.
static func standing_spots(spots: Array[Vector2]) -> Array[Vector2]:
	var gap: float = spots[0].distance_to(spots[1])
	var cut: float = gap - drawn_gap(gap)
	if cut <= 0.0 or gap < 0.001:
		return spots.duplicate()
	var toward: Vector2 = (spots[1] - spots[0]) / gap
	var room: Array[float] = []
	for p: Vector2 in spots:
		room.append(clampf((Octagon.distance_to_fence(p) - Octagon.BODY_MARGIN) / Octagon.NEAR_WITHIN, 0.0, 1.0))
	var share: float = 0.5 if room[0] + room[1] < 0.001 else room[0] / (room[0] + room[1])
	return [spots[0] + toward * cut * share, spots[1] - toward * cut * (1.0 - share)]


## The drawn gap for a sim gap (D281): see DRAWN_FROM, DRAWN_SHARE and DRAWN_UNTIL.
static func drawn_gap(gap: float) -> float:
	if gap <= DRAWN_FROM:
		return gap
	var squeezed: float = DRAWN_FROM + (minf(gap, DRAWN_UNTIL) - DRAWN_FROM) * DRAWN_SHARE
	return squeezed + maxf(0.0, gap - DRAWN_UNTIL)


## How far fighter i steps in for the strike he's throwing (metres, D281), from the drawn gap: enough for it to
## land at its contact gap (FighterFigure.AIMS), less SHORT_BY when the sim has it out of range. Eased in over
## the telegraph and windup, held through the active part, and taken back over the recovery.
static func lunge_for(sim: FightSim, i: int, gap: float, fraction: float = 0.0) -> float:
	var f: FighterState = sim.fighters[i]
	if not FighterFigure.AIMS.has(f.action_id) or not sim.actions.has(f.action_id):
		return 0.0
	var action: Dictionary = sim.actions.get_action(f.action_id)
	var need: float = gap - float(FighterFigure.AIMS[f.action_id].contact)
	if not action.ranges.has(sim.band()):
		need -= SHORT_BY
	if need <= 0.0:
		return 0.0
	var total: float = maxf(1.0, sim.phase_ticks(f, f.action_id, f.phase))
	var progress: float = clampf((total - f.phase_ticks_left + fraction) / total, 0.0, 1.0)
	var ease: float = 0.0
	match f.phase:
		"telegraph": ease = 0.6 * smoothstep(0.0, 1.0, progress)
		"windup": ease = lerpf(0.6, 1.0, progress)
		"active": ease = 1.0
		"recovery": ease = 1.0 - smoothstep(0.0, 1.0, progress)
	return minf(need, LUNGE_MAX) * ease


## Standing, the drawn spots with each striker stepped in toward the other (lunge_for) and each man hit
## knocked back (`knock`, metres), kept inside the fence (D281).
static func strike_spots(sim: FightSim, spots: Array[Vector2], knock: Array[float], fraction: float = 0.0) -> Array[Vector2]:
	var gap: float = spots[0].distance_to(spots[1])
	if gap < 0.001:
		return spots.duplicate()
	var toward: Vector2 = (spots[1] - spots[0]) / gap
	var lunge: Array[float] = [lunge_for(sim, 0, gap, fraction), lunge_for(sim, 1, gap, fraction)]
	# Two men stepping in together share the step: they stop at the shorter strike's contact gap.
	var closest: float = LUNGE_CLOSEST
	if lunge[0] > 0.0 and lunge[1] > 0.0:
		closest = maxf(closest, minf(_contact(sim, 0), _contact(sim, 1)))
	elif lunge[0] > 0.0 or lunge[1] > 0.0:  # One man in: a short shot (the uppercut, D360) gets in to its contact.
		closest = minf(closest, _contact(sim, 0 if lunge[0] > 0.0 else 1))
	var room: float = maxf(0.0, gap - closest)
	if lunge[0] + lunge[1] > room:
		var scale: float = room / (lunge[0] + lunge[1])
		lunge = [lunge[0] * scale, lunge[1] * scale]
	var a: Vector2 = spots[0] + toward * (lunge[0] - knock[0])
	var b: Vector2 = spots[1] - toward * (lunge[1] - knock[1])
	return [Octagon.keep_inside(a), Octagon.keep_inside(b)]


static func _contact(sim: FightSim, i: int) -> float:
	return float(FighterFigure.AIMS.get(sim.fighters[i].action_id, {}).get("contact", 0.0))


## The two move labels lean apart on screen when both are up, so they don't print over each other (D281).
func _side_labels() -> void:
	if figures.size() < 2 or camera == null or not camera.is_inside_tree():
		return
	var left: float = camera.unproject_position(figures[0]._head.global_position).x
	var right: float = camera.unproject_position(figures[1]._head.global_position).x
	var both: bool = figures[0]._move_label.visible and figures[1]._move_label.visible
	figures[0].label_side = (-1.0 if left <= right else 1.0) if both else 0.0
	figures[1].label_side = -figures[0].label_side


## Where each fighter is drawn and the way he faces (radians on the canvas), from their sim spots:
## face to face standing, laid out by GROUND_LAYOUTS on the ground (D210). Plain numbers, so it can be tested.
static func ground_spots(sim: FightSim, spots: Array[Vector2]) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	for i in spots.size():
		placed.append({ "at": spots[i], "facing": (spots[1 - i] - spots[i]).angle() })
	var where: String = sim.situation.position
	var roles: Array = sim.situation.roles
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		if ActionLibrary.is_leg_lock(sim.actions.get_action(hold.action_id)):
			return placed
		where = String(hold.from)  # Held where it was locked from (D126).
		roles = hold.from_roles
	if where == PositionLibrary.CLINCH:
		var direction: Vector2 = (spots[1] - spots[0]).normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		var middle: Vector2 = (spots[0] + spots[1]) / 2.0
		var a: Vector2 = middle - direction * CLINCH_BODY_GAP / 2.0
		var b: Vector2 = middle + direction * CLINCH_BODY_GAP / 2.0
		# Shift the pair together at the fence, preserving the physical room between bodies.
		for normal: Vector2 in Octagon.NORMALS:
			var over: float = maxf(a.dot(normal), b.dot(normal)) - (Octagon.APOTHEM - Octagon.BODY_MARGIN)
			if over > 0.0:
				a -= normal * over
				b -= normal * over
		return [{"at": a, "facing": direction.angle()}, {"at": b, "facing": (-direction).angle()}]
	var top: int = roles.find(PositionLibrary.TOP)
	if not GROUND_LAYOUTS.has(where) or top < 0:
		return placed
	return lay_out(where, top, spots)


## Where the two are drawn in the ground position `where` (GROUND_LAYOUTS) with fighter `top` on top, from
## their sim spots (ground_spots; the takedowns land in it, D288).
static func lay_out(where: String, top: int, spots: Array[Vector2]) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	for i in spots.size():
		placed.append({ "at": spots[i], "facing": (spots[1 - i] - spots[i]).angle() })
	if not GROUND_LAYOUTS.has(where):
		return placed
	var bottom: int = 1 - top
	var layout: Dictionary = GROUND_LAYOUTS[where]
	# He lies across the screen, so neither man hides the other from the camera: feet toward whichever
	# side of the screen the sim has the top man on. The top man's side (positive `at.y`) is the far one.
	var across: Vector2 = Vector2(CAMERA_FROM.z, -CAMERA_FROM.x).normalized()
	var away: Vector2 = -Vector2(CAMERA_FROM.x, CAMERA_FROM.z).normalized()
	var feet: Vector2 = across if (spots[top] - spots[bottom]).dot(across) >= 0.0 else -across
	if layout.get("facing_camera", false):  # Sat up facing you, so the man behind him is behind him on screen too.
		feet = (feet * tan(LIE_TURN) - away).normalized()
	else:
		feet = (feet + away * tan(LIE_TURN)).normalized()  # Turned a little, so a man across him isn't end-on.
	var side: Vector2 = feet.orthogonal()
	if side.dot(away) < 0.0:
		side = -side
	var at: Vector2 = layout.at
	var face: Vector2 = layout.face
	placed[bottom] = { "at": spots[bottom], "facing": feet.angle() }
	placed[top] = { "at": spots[bottom] + feet * at.x + side * at.y, "facing": (feet * face.x + side * face.y).angle() }
	return placed


func _show_tag(sim: FightSim, middle: Vector2, delta: float) -> void:
	var text: String = tag_text(sim)
	if text != _tag_text:
		_tag_text = text
		_tag_scale = TAG_BUMP
	_tag_scale = lerpf(_tag_scale, 1.0, 1.0 - exp(-3.0 * delta))
	_tag.text = text
	_tag.modulate = TAG_COLOURS.get(sim.band(), Color.WHITE)
	# Labels are sized in metres: shrink them as the camera moves in so they stay the same on screen.
	_tag.scale = Vector3.ONE * _tag_scale * zoom_share()
	# Just in front of the fighters as the camera sees them, on the canvas.
	_tag.position = Vector3(middle.x, 0.05, middle.y) + Vector3(0.9, 0.0, 0.9)


func _place_camera(delta: float, middle: Vector2 = Vector2.ZERO, sim: FightSim = null) -> void:
	var want_zoom: float = ZOOM_STANDING
	if sim != null and not sim.situation.is_standing():
		want_zoom = ZOOM_CLINCH if sim.situation.position == PositionLibrary.CLINCH else ZOOM_GROUND
	var k: float = 1.0 - exp(-CAMERA_SPEED * delta)
	var follow: float = FOLLOW_SHARE if sim == null or sim.situation.is_standing() else 1.0
	if sim != null and sim.situation.is_standing():
		# Wide separation needs the whole tactical space, including the retreating fighter.
		want_zoom = maxf(want_zoom, sim.fighters[0].pos.distance_to(sim.fighters[1].pos) * 0.92 + 2.8)
	_focus = _focus.lerp(Vector3(middle.x, 0.6, middle.y) * follow, k)
	_zoom = lerpf(_zoom, want_zoom, k)
	camera.size = _zoom
	var distance: float = _zoom / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
	camera.position = _focus + CAMERA_FROM.normalized() * distance
	camera.look_at(_focus, Vector3.UP)


func _on_event(event: FightEvent) -> void:
	# Tell cues (D51): the playtest's opponents are scouted, so their tells show.
	if event.type == FightEvent.ROUND_ENDED:
		_tell_until = [-1, -1]
		return
	if event.actor in [0, 1] and figures.size() == 2:
		_show_strike(event)
	if event.type == FightEvent.GRAPPLE_WON and event.data.get("result", "") == PositionLibrary.SUCCESS \
			and GroundPair.ROLLS.has(String(event.data.get("action_id", ""))) and not _ground_last.is_empty():
		_roll = {"from": _ground_last, "left": ROLL_SECONDS}  # Rolled over (D289): the pose plays the roll.
	if event.type == FightEvent.GRAPPLE_WON and event.data.get("result", "") == "turned" and not _clinch_last.is_empty():
		_turn = {"from": _clinch_last, "left": TURN_SECONDS, "slam": event.data.action_id == "turn_him"}
	if not _takedown.is_empty() and event.actor == int(_takedown.by) and String(_takedown.state) == "attempt" \
			and String(event.data.get("action_id", "")) == String(_takedown.action):
		var result: String = String(event.data.get("result", ""))
		if event.type == FightEvent.GRAPPLE_WON and result in [PositionLibrary.SUCCESS, PositionLibrary.PARTIAL]:
			_land(result)
		elif event.type == FightEvent.GRAPPLE_STOPPED and event.data.get("reason", "") == "sprawled on":
			_sprawled()
		elif event.type in [FightEvent.GRAPPLE_WON, FightEvent.GRAPPLE_STOPPED]:
			_end_takedown(STUFF_EASE)  # Stuffed, or pressed on the fence: back to the clinch.
	var sim: FightSim = driver.sim
	var triggers: TriggerLibrary = TriggerLibrary.shared()
	for i in sim.fighters.size():
		if i == driver.player:
			continue
		for tell: Dictionary in sim.fighters[i].tells:
			if triggers.has(tell.trigger) and triggers.matches(tell.trigger, event, i):
				_tell_limb[i] = FighterFigure.limb_for(String(tell.action))
				_tell_until[i] = event.tick + int(tell.get("within_ms", 1000)) / FightClock.TICK_MS
		# The tell's move is under way: the cue's job is done.
		if event.actor == i and event.type == FightEvent.ACTION_PHASE and event.data.phase == "active":
			_tell_until[i] = -1
	if event.type == FightEvent.CALL_ANSWERED and event.data.outcome == LiveCalls.IGNORED and event.actor < figures.size():
		figures[event.actor].show_ignored()


## A strike's outcome on both men (D281): the thrower's aim follows it, the man hit reacts.
func _show_strike(event: FightEvent) -> void:
	var a: int = event.actor
	var action: String = String(event.data.get("action_id", ""))
	match event.type:
		FightEvent.STRIKE_LANDED:
			var covered: bool = bool(event.data.get("covered", false))
			figures[a].show_outcome(action, "covered" if covered else "landed")
			var hook: bool = FighterFigure.AIMS.has(action) and String(FighterFigure.AIMS[action].bend) in ["out", "round"]
			var turn: float = 0.0
			if hook:  # A hook or round kick turns his head away from the side it came from.
				turn = 1.0 if String(FighterFigure.AIMS[action].limb).begins_with("lead") == (figures[a].lead < 0.0) else -1.0
			figures[1 - a].show_hit(String(event.data.target), float(event.data.damage), covered, turn)
		FightEvent.STRIKE_MISSED:
			var reason: String = String(event.data.get("reason", ""))
			var outcome: String = "missed"
			if reason == "out of range":
				outcome = "short"
			elif String(event.data.get("by_action", "")) == "check_kick":
				outcome = "checked"
			figures[a].show_outcome(action, outcome)


func _build_cage() -> void:
	_venue = LocalVenue.new()
	add_child(_venue)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	camera.size = ZOOM_STANDING
	camera.near = 0.1
	camera.far = 60.0
	add_child(camera)
	camera.current = true
	_place_camera(1.0)


func _build_debug_marks() -> void:
	for within: float in [Octagon.NEAR_WITHIN, Octagon.PINNED_WITHIN]:
		var line := MeshInstance3D.new()
		line.mesh = _octagon_outline(Octagon.APOTHEM - Octagon.BODY_MARGIN - within)
		var m: StandardMaterial3D = FighterFigure._material(Color(1.0, 1.0, 1.0, 0.45))
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = m
		line.position.y = 0.02
		_debug.add_child(line)
	for i in 2:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.985
		torus.outer_radius = 1.0
		torus.rings = 64
		ring.mesh = torus
		var m: StandardMaterial3D = FighterFigure._material(Color(FIGHTER_COLOURS[i], 0.6))
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = m
		ring.visible = false
		_debug.add_child(ring)
		_want_rings.append(ring)


## A flat octagon `height` thick, corners at `corner` metres. CylinderMesh puts a corner on
## the z axis, so turn it PI / 8 to line it up with the fence (Octagon.NORMALS).
static func _octagon_slab(corner: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = corner
	mesh.bottom_radius = corner
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


## An octagon outline on the canvas, `apothem` metres from the centre to each side.
static func _octagon_outline(apothem: float) -> ImmediateMesh:
	var corner: float = apothem / cos(PI / 8.0)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in 9:
		var p: Vector2 = Vector2.from_angle(PI / 8.0 + k * PI / 4.0) * corner
		mesh.surface_add_vertex(Vector3(p.x, 0.0, p.y))
	mesh.surface_end()
	return mesh
