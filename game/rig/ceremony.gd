class_name Ceremony
extends Node3D
## Before, between and after the rounds (D390-D394; docs/13 "Before, between and after the fight"): the fight screen's
## moments outside the fighting, played on the skinned bodies while the fight is held.
## - Before the first bell (D390): the referee calls them to the centre from their corners, they touch gloves and
##   back off to their marks.
## - Between rounds (D391): they walk to their corners and sit on stools while a coach crouches in front talking and
##   the cutman works on his face; the cutman closes a cut here (BodyMarks.cornered). Then they stand and walk out.
## - At the end (D392, D393): after a finish the winner celebrates while the beaten man sits up and gets to his feet;
##   then (and after a decision) the referee stands between them at the centre holding a wrist each and raises the
##   winner's hand (both for a draw).
## Each walks on a Walker: the fighters' own bodies are lent to one for the moment, the corner team and stools are
## this node's. Presentation only: the fight is held while a moment plays and none of it changes the fight.

signal moment_done(kind: String)

const INTRO := "intro"
const CORNERS := "corners"
const OUT := "out"
const VERDICT := "verdict"

## The corner posts the fighters' stools are in (radians round the cage from +X; red's far from the camera, blue's
## across from it), and the post the referee waits by between rounds.
const POST_ANGLES: Array[float] = [PI * 1.125, PI * 0.125]
const NEUTRAL_ANGLE: float = PI * 1.625
## The cage's corner posts are this far from the middle: Octagon.APOTHEM / cos(22.5°).
const POST_RADIUS: float = 4.871
## How far in from his post a man's stool is, where his corner team come in at, and where the referee waits.
const STOOL_IN: float = 0.8
const TEAM_IN: float = 0.35
const REFEREE_IN: float = 1.0
## The stool: seat height and size (m).
const SEAT_HEIGHT: float = 0.5
const SEAT_RADIUS: float = 0.19
const STOOL_COLOUR := Color(0.1, 0.1, 0.11)
## Where the coach crouches (in front of the stool, a little to one side so the camera sees past him) and the cutman
## stands (at the fighter's side): metres toward the middle and to the side.
const COACH_AT := Vector2(0.55, 0.5)
const CUTMAN_AT := Vector2(-0.02, -0.52)
## The corner team's height (shoulders, m).
const TEAM_SHOULDERS: float = 1.42
## Touching gloves: how far apart they stand and for how long (s).
const TOUCH_GAP: float = 1.05
const TOUCH_SECONDS: float = 1.0
## Standing on their marks a moment before the bell (s).
const READY_SECONDS: float = 0.4
## Walking speeds (m/s): the fighters, the winner strolling with his arms up, and the corner team.
const WALK: float = 1.4
const STROLL: float = 0.7
const TEAM_WALK: float = 1.8
## A walk never takes longer than this (s); then everyone is put where they were going.
const WALK_MAX: float = 5.0
## Sitting down and standing up (s), and how long seated before the cutman has closed his cut.
const SIT_SECONDS: float = 0.6
const STAND_SECONDS: float = 0.5
const CUTMAN_SECONDS: float = 1.5
## After a finish: the winner's celebration, the beaten man sitting up and getting up (s; he sits up only if he was down).
const CELEBRATE_SECONDS: float = 2.5
const GET_UP_SECONDS: float = 1.2
## The hand raised: standing either side of the referee (m), how long he holds their wrists before it, and how long
## the raise takes to go up and is held before the result (s).
const RAISE_GAP: float = 0.78
const HOLD_SECONDS: float = 0.8
const RAISE_UP_SECONDS: float = 0.45
const RAISE_SECONDS: float = 1.8
## His breathing by how tired he is (BodyMarks.strain 0 to 1): breaths a second and how far his chest heaves (deg).
const BREATHE_HZ := Vector2(0.28, 0.75)
const BREATHE_DEG := Vector2(1.5, 7.0)
## Tired past this, he stands with his hands on his hips.
const HANDS_ON_HIPS: float = 0.6
## The camera in each moment: how close (ArenaView zoom), and between rounds how far right of his stool it looks
## (a share of the zoom) so the stool sits left of the round panel.
const CORNER_ZOOM: float = 3.8
const CORNER_SHIFT: float = 0.24
const CORNER_RISE: float = 0.25
const VERDICT_ZOOM: float = 3.6
const CLOSE_ZOOM: float = 4.4

var arena: ArenaView
## The moment playing ("" none), the beat in it and how long it has run (s).
var kind: String = ""
var beat: String = ""
var time: float = 0.0
## The moment got to its end: between rounds they're sat down, at the end the hand is up. It's held there.
var done: bool = false
## The fighters, each on a Walker with his own body lent for the moment.
var men: Array[Walker] = []
## Each corner's coach and cutman ([red coach, red cutman, blue coach, blue cutman]), made at the first break.
var team: Array[Walker] = []
var stools: Array[Node3D] = []
## At the end: {winner (-1 a draw), finished (a knockout or tap), low (the beaten man was down)}.
var verdict: Dictionary = {}
var _beats: Array[String] = []
var _cut_closed: bool = false
## Each man's standing pelvis height (m) and breath's phase.
var _stand: Array[float] = [0.92, 0.92]
var _breath: Array[float] = [0.0, 0.0]
## The hand raise: the referee's spot, which way the camera looks from, and each man's spot by him.
var _centre := Vector2.ZERO
var _toward := Vector2.ONE
var _sides: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]


## Set up for `p_arena` (its figures have bodies and hidden rigs, and it has a referee).
func setup(p_arena: ArenaView) -> void:
	arena = p_arena
	for i in 2:
		var walker := Walker.new()
		add_child(walker)
		walker.borrow(arena.figures[i].body, arena._clinch_rigs[i])
		men.append(walker)
		var rig: FighterRig = arena._clinch_rigs[i]
		_stand[i] = (rig.thigh + rig.shin + rig.ankle_up) * 0.97
		var stool: Node3D = _build_stool()
		stool.position = Vector3(stool_spot(i).x, 0.0, stool_spot(i).y)
		stool.visible = false
		add_child(stool)
		stools.append(stool)


## True while a moment draws the bodies (the fight's own drawing waits).
func active() -> bool:
	return kind != ""


## True while a moment is still moving (a key or click skips it), not held at its end.
func playing() -> bool:
	return kind != "" and not done


## Starts a moment: INTRO, CORNERS, OUT or VERDICT (with {winner, finished}). moment_done says when it's got to its
## end; CORNERS and VERDICT then hold there until the next moment or the next fight.
func play(p_kind: String, data: Dictionary = {}) -> void:
	kind = p_kind
	done = false
	time = 0.0
	match kind:
		INTRO:
			_beats = ["to_centre", "touch", "to_marks", "ready"]
			for i in 2:
				men[i].place(stool_spot(i), Vector2.ZERO)
			arena.referee.place(_referee_by(Vector2.ZERO, 1.3), Vector2.ZERO)
		CORNERS:
			_beats = ["walk", "sit", "seated"]
			_cut_closed = false
			_take_bodies()
			_make_team()
			for i in 2:
				stools[i].visible = true
			for n in team.size():
				team[n].visible = true
				team[n].place(team_door(n >> 1, n & 1), stool_spot(n >> 1))
		OUT:
			_beats = ["stand", "to_marks", "ready"]
			arena.close_cuts()  # Called out before the cutman had his moment: he did it anyway.
		VERDICT:
			verdict = {"winner": int(data.get("winner", -1)), "finished": bool(data.get("finished", false))}
			_take_bodies()
			var winner: int = int(verdict.winner)
			verdict["low"] = winner in [0, 1] and arena.figures[1 - winner].body.hips_at().y < 0.6
			_beats = []
			if bool(verdict.finished):
				_beats.append("celebrate")
			if bool(verdict.low):
				_beats.append("get_up")
			_beats.append_array(["to_centre", "hold", "raise", "raised"])
	for figure in arena.figures:
		figure.hide_overhead()
	_enter(_beats[0])


## Jumps the moment to its end (a key or click, D394).
func skip() -> void:
	if not playing():
		return
	match kind:
		INTRO, OUT:
			for i in 2:
				men[i].place(FightSim.START_POSITIONS[i], FightSim.START_POSITIONS[1 - i])
				men[i].pose = _stand_pose(i)
			arena.referee.place(_watch_spot(), Vector2.ZERO)
			for member in team:
				member.visible = false
			for stool in stools:
				stool.visible = false
			_finish()
			return
		CORNERS:
			for i in 2:
				men[i].place(stool_spot(i), Vector2.ZERO)
				men[i].plant()
			for n in team.size():
				team[n].place(team_spot(n >> 1, n & 1), stool_spot(n >> 1))
			arena.referee.place(neutral_spot(), Vector2.ZERO)
			_ease_all(0.2)
			_enter("seated")
		VERDICT:
			_line_up()
			for i in 2:
				men[i].place(_sides[i], _centre + _toward * 4.0)
			arena.referee.place(_centre, _centre + _toward * 4.0)
			arena.referee.go(_centre, _centre + _toward * 4.0, Referee.WALK_SPEED)
			arena.referee.posed = true
			_ease_all(0.2)
			time = RAISE_UP_SECONDS
			_enter("raised")


## Plays `delta` seconds: walks and poses everyone, moves on through the beats.
func advance(delta: float) -> void:
	if kind == "":
		return
	time += delta
	for i in 2:
		_breath[i] += delta * lerpf(BREATHE_HZ.x, BREATHE_HZ.y, _strain(i))
	_hold(beat, delta)
	for walker in men:
		walker.advance(delta)
		walker.body.settle(delta)
	if team.size() == 4:
		_pose_team()
		for member in team:
			if member.visible:
				member.advance(delta)
				member.body.settle(delta)
	arena.referee.advance(delta)
	arena.referee.body.settle(delta)
	if _beat_over(beat):
		var next: int = _beats.find(beat) + 1
		if next >= _beats.size():
			_finish()
		else:
			_enter(_beats[next])


## Where the camera looks in this moment: {focus (canvas), zoom, swing, rise}.
func view() -> Dictionary:
	var a: Vector2 = men[0].spot
	var b: Vector2 = men[1].spot
	var wide: float = maxf(CLOSE_ZOOM, a.distance_to(b) * 0.92 + 2.8)
	match kind:
		CORNERS:
			var corner: int = arena.driver.player if arena.driver != null else 0
			var stool: Vector2 = stool_spot(corner)
			var from: Vector2 = -stool.normalized()  # From the middle of the cage.
			var right := Vector2(from.y, -from.x)
			return {"focus": stool + right * CORNER_ZOOM * CORNER_SHIFT, "zoom": CORNER_ZOOM,
				"swing": swing_from(from), "rise": CORNER_RISE, "height": 0.75}
		VERDICT:
			if beat in ["celebrate", "get_up"]:
				return {"focus": (a + b) / 2.0, "zoom": wide, "swing": 0.0, "rise": 0.0, "height": 0.7}
			return {"focus": _centre, "zoom": VERDICT_ZOOM, "swing": 0.0, "rise": 0.0, "height": 1.1}
	return {"focus": (a + b) / 2.0, "zoom": wide, "swing": ArenaView.side_on_swing(a, b), "rise": 0.0, "height": 0.7}


## Fighter i's stool, in from his corner post.
static func stool_spot(i: int) -> Vector2:
	return Vector2.from_angle(POST_ANGLES[i]) * (POST_RADIUS - STOOL_IN)


## Where his corner team (k: 0 the coach, 1 the cutman) come in at, by his post, and where they work.
static func team_door(i: int, k: int) -> Vector2:
	var post: Vector2 = Vector2.from_angle(POST_ANGLES[i])
	return post * (POST_RADIUS - TEAM_IN) + Vector2(-post.y, post.x) * (0.35 if k == 0 else -0.35)


static func team_spot(i: int, k: int) -> Vector2:
	var inward: Vector2 = -Vector2.from_angle(POST_ANGLES[i])
	var side := Vector2(-inward.y, inward.x)
	var at: Vector2 = COACH_AT if k == 0 else CUTMAN_AT
	return stool_spot(i) + inward * at.x + side * at.y


## Where the referee waits between rounds, by a corner neither man is in.
static func neutral_spot() -> Vector2:
	return Vector2.from_angle(NEUTRAL_ANGLE) * (POST_RADIUS - REFEREE_IN)


## The camera's swing (ArenaView.camera_from) that looks along `from` (the way from the camera to what it sees,
## flat on the canvas, reversed: the camera sits that way off it).
static func swing_from(from: Vector2) -> float:
	var base := Vector2(ArenaView.CAMERA_FROM.x, ArenaView.CAMERA_FROM.z)
	return wrapf(base.angle() - from.angle(), -PI, PI)


func _enter(p_beat: String) -> void:
	beat = p_beat
	time = 0.0 if p_beat != "raised" else time
	var r: Referee = arena.referee
	match p_beat:
		"to_centre":
			if kind == INTRO:
				for i in 2:
					var mark := Vector2((-1.0 if i == 0 else 1.0) * TOUCH_GAP / 2.0, 0.0)
					men[i].go(mark, Vector2.ZERO, WALK)
					men[i].pose = _stand_pose(i)
				r.want(_referee_by(Vector2.ZERO, 1.3), Vector2.ZERO, "watch")
			else:
				_line_up()
				for i in 2:
					men[i].go(_sides[i], _centre + _toward * 4.0, WALK)
					men[i].pose = _stand_pose(i)
				r.want(_centre, _centre + _toward * 4.0, "watch")
			_ease_all(0.4)
		"touch":
			_ease_all(0.3)
		"to_marks":
			for i in 2:
				men[i].go(FightSim.START_POSITIONS[i], FightSim.START_POSITIONS[1 - i], WALK)
			r.want(_watch_spot(), Vector2.ZERO, "watch")
			for n in team.size():
				team[n].go(team_door(n >> 1, n & 1), stool_spot(n >> 1), TEAM_WALK)
			_ease_all(0.3)
		"ready":
			pass
		"walk":
			for i in 2:
				men[i].go(stool_spot(i), stool_spot(i), WALK)
				men[i].pose = _stand_pose(i)
			for n in team.size():
				team[n].go(team_spot(n >> 1, n & 1), stool_spot(n >> 1), TEAM_WALK)
			r.want(neutral_spot(), Vector2.ZERO, "watch")
			_ease_all(0.4)
		"sit":
			for i in 2:
				men[i].plant()
			_ease_all(SIT_SECONDS)
		"seated":
			done = true
			moment_done.emit(kind)
		"stand":
			_ease_all(STAND_SECONDS)
		"celebrate":
			var winner: int = int(verdict.winner)
			var loser: int = 1 - winner
			var home: Vector2 = stool_spot(winner)
			var off: Vector2 = home - men[winner].spot
			men[winner].go(men[winner].spot + off.limit_length(1.2), home, STROLL)
			men[loser].go(men[loser].spot, men[winner].spot, WALK)
			if bool(verdict.low):
				men[loser].plant()
				r.want(_referee_by(men[loser].spot, 0.8), men[loser].spot, "down")
			else:
				r.want(_referee_by(men[loser].spot, 1.0), men[loser].spot, "watch")
			_ease_all(0.8)
		"get_up":
			var loser: int = 1 - int(verdict.winner)
			men[loser].body.ease_over(GET_UP_SECONDS)
		"hold":
			r.go(_centre, _centre + _toward * 4.0, Referee.WALK_SPEED)
			r.posed = true
			_ease_all(0.4)
		"raise":
			pass
		"raised":
			done = true
			moment_done.emit(kind)


## The beat's poses this frame.
func _hold(p_beat: String, _delta: float) -> void:
	var r: Referee = arena.referee
	match p_beat:
		"to_centre", "to_marks", "ready", "walk", "stand":
			for i in 2:
				men[i].pose = _stand_pose(i)
				if p_beat == "walk" and men[i].spot.distance_to(stool_spot(i)) < 0.05:
					men[i].go(stool_spot(i), Vector2.ZERO, WALK)  # At his stool: turn to sit facing the middle.
		"touch":
			for i in 2:
				var middle := Vector3((-1.0 if i == 0 else 1.0) * 0.06, 0.0, 0.0)  # Glove to glove, not through.
				var height: float = _stand[i] + 0.2
				var p: Dictionary = _stand_pose(i)
				for side in 2:
					var across: float = (-1.0 if side == 0 else 1.0) * 0.07 * (1.0 if i == 0 else -1.0)
					p["hand_" + FighterRig.SIDES[side]] = {"world": middle + Vector3(0.0, height, across),
						"pole": [(-1.0 if side == 0 else 1.0), -0.6, 0.2]}
				men[i].pose = p
		"sit", "seated":
			for i in 2:
				men[i].pose = sit_pose(_breathing(i), _strain(i))
			if p_beat == "seated" and not _cut_closed and time >= CUTMAN_SECONDS:
				_cut_closed = true
				arena.close_cuts()  # The cutman has closed it (D376).
		"celebrate", "get_up":
			var winner: int = int(verdict.winner)
			var loser: int = 1 - winner
			men[winner].pose = celebrate_pose(_stand[winner], time)
			if p_beat == "celebrate" and bool(verdict.low):
				men[loser].pose = sit_up_pose(_breathing(loser))
			else:
				var hurt: Dictionary = _stand_pose(loser)
				hurt["head"] = [-18, 0]
				men[loser].pose = hurt
		"hold", "raise", "raised":
			var up: float = 0.0
			if p_beat != "hold":
				up = smoothstep(0.0, RAISE_UP_SECONDS, time)
			var raised: Array[bool] = [false, false]
			for i in 2:
				raised[i] = int(verdict.winner) == i or int(verdict.winner) < 0
			var grips: Array[Vector3] = []
			for i in 2:
				var low := Vector3(lerpf(_centre.x, _sides[i].x, 0.5), _stand[i] + 0.08, lerpf(_centre.y, _sides[i].y, 0.5))
				var high := Vector3(lerpf(_centre.x, _sides[i].x, 0.42), _stand[i] + 1.12, lerpf(_centre.y, _sides[i].y, 0.42))
				var grip: Vector3 = low.lerp(high, up) if raised[i] else low
				grips.append(grip)
				var p: Dictionary = _stand_pose(i)
				var near: String = _near_hand(men[i], _centre)
				p["hand_" + near] = {"world": grip, "pole": [(-1.0 if near == "l" else 1.0), -0.3, 0.5]}
				if not raised[i] and p_beat != "hold":
					p["head"] = [-16, 0]
				men[i].pose = p
			r.posed = true
			var ref_pose: Dictionary = Referee.pose_spec("watch", 0.0)
			for i in 2:
				ref_pose["hand_" + _near_hand(r, _sides[i])] = {"world": grips[i], "pole": [(-1.0 if _near_hand(r, _sides[i]) == "l" else 1.0), -0.5, 0.3]}
			r.pose = ref_pose


## True when the beat is over.
func _beat_over(p_beat: String) -> bool:
	match p_beat:
		"to_centre", "to_marks", "walk":
			var walking: Array[Walker] = []
			walking.append_array(men)
			walking.append(arena.referee)
			var all_there: bool = true
			for walker in walking:
				all_there = all_there and walker.arrived()
			if p_beat == "walk":
				for member in team:
					all_there = all_there and member.arrived()
			if p_beat == "to_marks":
				for member in team:  # Back out the door.
					if member.visible and member.arrived():
						member.visible = false
			if not all_there and time >= WALK_MAX:
				for walker in walking:
					walker.finish_walk()
				for member in team:
					member.finish_walk()
				return true
			return all_there
		"touch":
			return time >= TOUCH_SECONDS
		"ready":
			return time >= READY_SECONDS
		"sit":
			return time >= SIT_SECONDS
		"stand":
			return time >= STAND_SECONDS
		"celebrate":
			return time >= CELEBRATE_SECONDS
		"get_up":
			return time >= GET_UP_SECONDS
		"hold":
			return time >= HOLD_SECONDS
		"raise":
			return time >= RAISE_SECONDS
	return false  # "seated" and "raised" hold.


## The moment got to its end: those that go back to the fight hand the bodies back.
func _finish() -> void:
	var finished: String = kind
	if kind in [INTRO, OUT]:
		for member in team:
			member.visible = false
		for stool in stools:
			stool.visible = false
		for figure in arena.figures:
			figure.body.ease_over(0.25)  # Into his stance as the fight draws him again.
		kind = ""
		beat = ""
	else:
		done = true
	moment_done.emit(finished)


## The fighters' walkers start where their bodies are drawn now, the way they face.
func _take_bodies() -> void:
	for i in 2:
		var hips: Vector3 = arena.figures[i].body.hips_at()
		men[i].place(Vector2(hips.x, hips.z), Vector2.ZERO)
		men[i].facing = arena.figures[i].rotation.y
		men[i].pose = _stand_pose(i)


## The hand raise's line: the referee in the middle facing the camera, each man on the side he's nearer.
func _line_up() -> void:
	var from: Vector3 = ArenaView.camera_from(0.0)
	_toward = Vector2(from.x, from.z).normalized()
	_centre = Vector2.ZERO
	var side := Vector2(-_toward.y, _toward.x)
	var red_left: bool = men[0].spot.dot(side) >= men[1].spot.dot(side)
	_sides[0] = _centre + side * RAISE_GAP * (1.0 if red_left else -1.0)
	_sides[1] = _centre - side * RAISE_GAP * (1.0 if red_left else -1.0)


## The referee's spot `off` metres from `at`, on the far side from the camera.
func _referee_by(at: Vector2, off: float) -> Vector2:
	var eye := Vector2(arena.camera.global_position.x, arena.camera.global_position.z) if arena.camera != null else Vector2(8, 8)
	var away: Vector2 = (at - eye).normalized() if at.distance_to(eye) > 0.01 else Vector2.UP
	return Referee.inside(at + away * off)


func _watch_spot() -> Vector2:
	var eye := Vector2(arena.camera.global_position.x, arena.camera.global_position.z) if arena.camera != null else Vector2(8, 8)
	var marks: Array[Vector2] = [FightSim.START_POSITIONS[0], FightSim.START_POSITIONS[1]]
	return Referee.watch_spot(marks, Referee.STANDING_OFF, eye, arena.referee.spot)


## Which of `walker`'s hands is nearer `at` ("l" or "r").
static func _near_hand(walker: Walker, at: Vector2) -> String:
	var local: Vector3 = walker.frame().affine_inverse() * Vector3(at.x, 0.0, at.y)
	return "l" if local.x < 0.0 else "r"


func _strain(i: int) -> float:
	return arena.marks[i].strain if arena.marks.size() == 2 else 0.0


## His breathing now: how far his chest heaves this frame (deg).
func _breathing(i: int) -> float:
	return lerpf(BREATHE_DEG.x, BREATHE_DEG.y, _strain(i)) * (0.5 + 0.5 * sin(TAU * _breath[i]))


func _stand_pose(i: int) -> Dictionary:
	return stand_pose(_stand[i], _breathing(i), _strain(i))


func _ease_all(seconds: float) -> void:
	for walker in men:
		walker.body.ease_over(seconds)
	if arena.referee != null:
		arena.referee.body.ease_over(seconds)


## Standing between the rounds' fighting (FighterRig spec in his frame, -Z ahead): upright, fists loose by his sides,
## his chest heaving with `breathe` (deg), and tired (`tired` 0 to 1) a little bent with his hands on his hips.
static func stand_pose(pelvis: float, breathe: float, tired: float) -> Dictionary:
	var pose := {
		"root": [0, pelvis, 0.0], "lean": 3.0 + 6.0 * tired, "bend": [breathe * 0.6 + 4.0 * tired, 0, 0],
		"head": [-2.0 - 5.0 * tired + breathe * 0.5, 0],
		"hand_l": {"at": [-0.27, pelvis + 0.05, -0.1], "pole": [-1, -0.4, 0.5]},
		"hand_r": {"at": [0.27, pelvis + 0.05, -0.1], "pole": [1, -0.4, 0.5]},
	}
	if tired >= HANDS_ON_HIPS:
		pose["hand_l"] = {"to": "a.waist_l", "off": [-0.03, 0.0, 0.02], "pole": [-1, 0.2, 0.6]}
		pose["hand_r"] = {"to": "a.waist_r", "off": [0.03, 0.0, 0.02], "pole": [1, 0.2, 0.6]}
	return pose


## Sat on his stool facing the middle: forward on it, feet planted ahead, hands on his thighs, his chest heaving.
static func sit_pose(breathe: float, tired: float) -> Dictionary:
	return {
		"root": [0, SEAT_HEIGHT + 0.07, 0.04], "lean": -4.0 - 6.0 * tired, "bend": [breathe + 3.0, 0, 0],
		"head": [4.0 + 6.0 * tired + breathe * 0.6, 0],
		"foot_l": {"at": [-0.21, FighterRig.ANKLE_UP, -0.44], "pole": [-0.2, 0, -1]},
		"foot_r": {"at": [0.21, FighterRig.ANKLE_UP, -0.42], "pole": [0.2, 0, -1]},
		"hand_l": {"to": "a.thigh_l", "off": [-0.02, 0.07, -0.08], "pole": [-1, -0.3, 0.4]},
		"hand_r": {"to": "a.thigh_r", "off": [0.02, 0.07, -0.08], "pole": [1, -0.3, 0.4]},
	}


## The winner, `seconds` into it: arms up over his head, fists pumping, chin up.
static func celebrate_pose(pelvis: float, seconds: float) -> Dictionary:
	var pump: float = 0.05 * sin(TAU * 1.3 * seconds)
	return {
		"root": [0, pelvis, 0.0], "lean": -4, "bend": [-6, 0, 0], "head": [16, 0],
		"hand_l": {"at": [-0.34, pelvis + 1.12 + pump, -0.08], "pole": [-1, 0.3, 0.3]},
		"hand_r": {"at": [0.34, pelvis + 1.12 - pump, -0.08], "pole": [1, 0.3, 0.3]},
	}


## The beaten man sat up on the canvas: legs out ahead, leaning back on his hands, head down, breathing.
static func sit_up_pose(breathe: float) -> Dictionary:
	return {
		"root": [0, 0.16, 0.1], "lean": -32, "bend": [12 + breathe, 0, 0], "head": [-14, 0],
		"foot_l": {"at": [-0.22, FighterRig.ANKLE_UP, -0.8], "pole": [-0.3, 1, -0.4]},
		"foot_r": {"at": [0.24, FighterRig.ANKLE_UP, -0.68], "pole": [0.3, 1, -0.4]},
		"hand_l": {"at": [-0.3, 0.04, 0.42], "pole": [-1, 0, 0.8]},
		"hand_r": {"at": [0.3, 0.04, 0.42], "pole": [1, 0, 0.8]},
	}


## The corner team's poses this frame: the coach crouched in front talking with a hand on the fighter's knee, the
## cutman leaning in with his hands on the fighter's face (on a cut, over it; else a hand on the back of his neck).
func _pose_team() -> void:
	for i in 2:
		var coach: Walker = team[i * 2]
		var cutman: Walker = team[i * 2 + 1]
		var working: bool = beat in ["sit", "seated"] and coach.arrived()
		coach.pose = Referee.pose_spec("watch", 0.0)
		cutman.pose = Referee.pose_spec("watch", 0.0)
		if not working:
			continue
		var rig: FighterRig = arena._clinch_rigs[i]
		var talk: float = sin(TAU * 1.1 * time)
		coach.pose = {
			"root": [0, FighterRig.PELVIS_HEIGHT - 0.36, 0.1], "lean": 22, "bend": [8, 0, 0], "head": [10, 0],
			"hand_l": {"world": rig.point("knee_l"), "pole": [-1, -0.5, 0.3]},
			"hand_r": {"at": [0.24, 0.98 + 0.06 * talk, -0.34], "pole": [1, -0.6, 0.2]},
		}
		var cut: int = -1
		if arena.marks.size() == 2:
			for side in 2:
				if arena.marks[i].cut[side]:
					cut = side
		var brow: Vector3 = rig.point("head", Vector3((-0.06 if cut == 0 else 0.06), 0.05, -0.1))
		cutman.pose = {
			"root": [0, FighterRig.PELVIS_HEIGHT - 0.1, 0.05], "lean": 24, "bend": [10, 0, 0], "head": [-18, 0],
			"hand_l": {"world": brow if cut >= 0 else rig.point("nape"), "pole": [-1, -0.4, 0.2]},
			"hand_r": {"world": rig.point("back_of_head") if cut >= 0 else rig.point("shoulder_r"), "pole": [1, -0.4, 0.2]},
		}


## Makes each corner's coach and cutman the first time they're needed: corner-coloured shirts, looks from the fight.
func _make_team() -> void:
	if not team.is_empty():
		return
	for i in 2:
		for k in 2:
			var member := Walker.new()
			add_child(member)
			if not member.dress(TEAM_SHOULDERS):
				member.queue_free()
				for made in team:
					made.queue_free()
				team = []
				return
			var seed: int = (arena.driver.sim.fight_seed if arena.driver != null else 0) * 4 + i * 2 + k
			member.body.set_cornerman(FighterLook.roll(seed ^ 0xC0A, ""), ArenaView.FIGHTER_COLOURS[i])
			member.visible = false
			team.append(member)


## A corner stool: a round black seat on a short column and a round foot.
static func _build_stool() -> Node3D:
	var stool := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = STOOL_COLOUR
	paint.roughness = 0.6
	for part: Array in [[SEAT_RADIUS, SEAT_RADIUS, 0.05, SEAT_HEIGHT - 0.025], [0.03, 0.03, SEAT_HEIGHT - 0.05, (SEAT_HEIGHT - 0.05) / 2.0],
			[0.17, 0.19, 0.03, 0.015]]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(part[0])
		mesh.bottom_radius = float(part[1])
		mesh.height = float(part[2])
		mesh.radial_segments = 16
		var shown := MeshInstance3D.new()
		shown.mesh = mesh
		shown.material_override = paint
		shown.position.y = float(part[3])
		stool.add_child(shown)
	return stool
