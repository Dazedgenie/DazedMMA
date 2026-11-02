extends GutTest
## Scrambles, getting up and standing up from the rig on the fight screen (D368), and the shots from range and
## following him down (D369): the scramble on their knees, a takedown that half works carrying on into it, the
## scramble for the top landing in the guard, the technical stand-up and the fence walk, a stopped get-up back in
## the guard, standing up from the top leaving him down, the double leg dropping its level out at range, the
## catch-kick single holding the leg he kicked with, and diving on a man who's down. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched fight with the two in `where` (red on top when `top` is 0 on the ground), at `red` and `blue`: [sim, view].
func _watched(where: String, top: int = 0, red := Vector2(0.3, 0.6), blue := Vector2(-0.1, 0.4)) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "bjj"), _actions)
	_put(sim, where, top)
	sim.fighters[0].pos = red
	sim.fighters[1].pos = blue
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	_frames(view, 3, 1.0)
	return [sim, view]


func _put(sim: FightSim, where: String, top: int) -> void:
	var roles: Array[String] = [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL]
	if GroundPair.POSITIONS.has(where):
		roles = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
		if top == 1:
			roles = [PositionLibrary.BOTTOM, PositionLibrary.TOP]
	sim.situation.set_to(sim.positions.get_position(where), roles)
	for f: FighterState in sim.fighters:
		f.clear_action()


func _frames(view: ArenaView, count: int, delta: float = 1.0 / 30.0) -> void:
	for n in count:
		view._process(delta)


## Fighter `i` is `phase` of `action`, `share` (0–1) of the way through it.
func _doing(sim: FightSim, i: int, action: String, phase: String, share: float) -> void:
	var f: FighterState = sim.fighters[i]
	f.action_id = action
	f.phase = phase
	var total: int = sim.phase_ticks(f, action, phase)
	f.phase_ticks_left = maxi(1, int(round(total * (1.0 - share))))


func _won(view: ArenaView, sim: FightSim, i: int, action: String, result: String) -> void:
	view._on_event(FightEvent.new(sim.now, i, FightEvent.GRAPPLE_WON, i, {"action_id": action, "result": result}))
	sim.apply_transition(i, action, result)
	sim.fighters[i].phase = "recovery"
	view.driver._snap()


func _stopped(view: ArenaView, sim: FightSim, i: int, action: String, reason: String) -> void:
	view._on_event(FightEvent.new(sim.now, i, FightEvent.GRAPPLE_STOPPED, i, {"action_id": action, "reason": reason}))
	sim.fighters[i].phase = "recovery"
	sim.fighters[i].phase_ticks_left = 10


func _pelvis(view: ArenaView, i: int) -> Vector3:
	return view._clinch_rigs[i].bones.pelvis.global_position


func _head(view: ArenaView, i: int) -> Vector3:
	return view._clinch_rigs[i].point("head")


func test_a_scramble_is_both_men_on_their_knees_fighting_for_it() -> void:
	var setup: Array = _watched("scramble")
	var view: ArenaView = setup[1]
	assert_false(view._scramble_last.is_empty(), "posed from the rig")
	for i in 2:
		assert_between(_pelvis(view, i).y, 0.35, 0.6, "on his knees")
		assert_gt(_head(view, i).y, 0.9, "up on them")


func test_a_takedown_that_half_works_carries_on_into_the_scramble_where_it_left_them() -> void:
	var setup: Array = _watched("standing", 0, Vector2(0.4, 0.6), Vector2(-0.4, 0.6))
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 0, "double_leg", "active", 0.5)
	_frames(view, 1)
	assert_eq(String(view._takedown.get("move", "")), "double_leg", "the shot from range")
	_won(view, sim, 0, "double_leg", PositionLibrary.PARTIAL)
	_frames(view, 20)
	assert_true(view._takedown.is_empty())
	assert_eq(sim.situation.position, "scramble")
	var hips: Array[Vector3] = [_pelvis(view, 0), _pelvis(view, 1)]
	_frames(view, 30)
	for i in 2:
		assert_lt(_pelvis(view, i).distance_to(hips[i]), 0.05, "still where it left them")
		assert_between(_pelvis(view, i).y, 0.35, 0.6, "on his knees")


func test_scrambling_for_the_top_drives_over_him_and_lands_in_his_guard() -> void:
	var setup: Array = _watched("scramble")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	var knees: float = _pelvis(view, 1).y
	_doing(sim, 1, "scramble", "active", 0.9)
	_frames(view, 1)
	assert_eq(String(view._takedown.get("move", "")), "scramble")
	assert_eq(int(view._takedown.a), 1, "blue makes the move")
	assert_lt(_pelvis(view, 0).y, knees, "red knocked back off his knees")
	_won(view, sim, 1, "scramble", PositionLibrary.SUCCESS)
	_frames(view, 30)
	assert_signal_emitted_with_parameters(view, "takedown_landed", [ScramblePair.TIMING.scramble.thud])
	assert_true(view._takedown.is_empty())
	assert_eq(sim.situation.position, "full_guard")
	assert_true(view.rig_ground(sim), "the guard from the rig")
	assert_gt(_pelvis(view, 1).y, _pelvis(view, 0).y + 0.15, "blue on top")


func test_getting_up_from_underneath_sits_out_and_stands_up() -> void:
	var setup: Array = _watched("full_guard")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	var lying: float = _pelvis(view, 1).y
	_doing(sim, 1, "get_up", "windup", 0.99)
	_frames(view, 1)
	assert_eq(String(view._takedown.get("move", "")), "get_up", "the technical stand-up")
	assert_gt(_head(view, 1).y, 0.5, "sat up")
	_doing(sim, 1, "get_up", "active", 0.99)
	_frames(view, 1)
	assert_gt(_pelvis(view, 1).y, lying + 0.05, "hips coming up")
	_won(view, sim, 1, "get_up", PositionLibrary.SUCCESS)
	var highest: float = 0.0
	for n in 20:
		_frames(view, 1)
		if not view._takedown.is_empty():
			highest = maxf(highest, _head(view, 1).y)
	assert_gt(highest, 1.4, "on his feet")
	assert_true(view._takedown.is_empty(), "done: today's figures carry on")
	assert_signal_not_emitted(view, "takedown_landed", "getting up is quiet")


func test_with_his_back_on_the_fence_he_walks_up_it() -> void:
	var fence: float = Octagon.APOTHEM
	var setup: Array = _watched("full_guard", 0, Vector2(fence - 1.0, 0.0), Vector2(fence - 0.4, 0.0))
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	assert_eq(sim.cage_proximity(1), Octagon.CAGE_PINNED)
	_doing(sim, 1, "get_up", "active", 0.99)
	_frames(view, 1)
	assert_eq(String(view._takedown.get("move", "")), "get_up_fence")
	_won(view, sim, 1, "get_up", PositionLibrary.SUCCESS)
	var leaning: bool = false
	for n in 20:
		_frames(view, 1)
		if view._takedown.is_empty():
			break
		var back: Vector3 = view._clinch_rigs[1].point("back")
		var out: float = Vector2(back.x, back.z).dot(Vector2.RIGHT)
		assert_lt(out, fence + 0.02, "not through the fence")
		if out > fence - 0.2 and back.y > 0.6:
			leaning = true
	assert_true(leaning, "his back up the fence")


func test_a_stopped_get_up_goes_back_into_the_guard() -> void:
	var setup: Array = _watched("full_guard")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 1, "get_up", "active", 0.5)
	_frames(view, 1)
	assert_false(view._takedown.is_empty())
	_stopped(view, sim, 1, "get_up", "defended")
	_frames(view, 1)
	assert_true(view._takedown.is_empty())
	assert_true(view.rig_ground(sim), "the guard from the rig while he gets over it")


func test_standing_up_from_the_top_leaves_him_down() -> void:
	var setup: Array = _watched("full_guard")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 0, "stand_up", "active", 0.99)
	_frames(view, 1)
	assert_eq(String(view._takedown.get("move", "")), "stand_up")
	assert_false(view.rig_ground(sim), "the move, not the position")
	_won(view, sim, 0, "stand_up", PositionLibrary.SUCCESS)
	var last: Array = []
	for n in 20:
		_frames(view, 1)
		if not view._takedown.is_empty():
			last = [_head(view, 0).y, _head(view, 1).y]
	assert_gt(float(last[0]), 1.4, "red on his feet")
	assert_lt(float(last[1]), 0.4, "blue still down")


func test_a_double_leg_from_range_drops_his_level_before_he_gets_there() -> void:
	var setup: Array = _watched("standing", 0, Vector2(0.6, 0.6), Vector2(-0.6, 0.6))
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	_doing(sim, 0, "double_leg", "telegraph", 0.99)
	_frames(view, 1)
	assert_eq(String(view._takedown.get("move", "")), "double_leg")
	assert_almost_eq(float(view._takedown.x), ShotPair.TIMING.double_leg.entry / 2.0, 0.6, "the level change")
	assert_lt(_pelvis(view, 0).y, FighterRig.PELVIS_HEIGHT - 0.2, "dropped his level")
	assert_gt(_pelvis(view, 0).distance_to(_pelvis(view, 1)), 0.7, "still out at range")
	_doing(sim, 0, "double_leg", "active", 0.5)
	_frames(view, 1)
	assert_gt(float(view._takedown.x), float(ShotPair.TIMING.double_leg.entry), "in on his legs and driving")
	_won(view, sim, 0, "double_leg", PositionLibrary.SUCCESS)
	_frames(view, 30)
	assert_signal_emitted_with_parameters(view, "takedown_landed", [ShotPair.TIMING.double_leg.thud])
	assert_eq(sim.situation.position, "full_guard")
	assert_lt(_pelvis(view, 1).y, 0.35, "blue on his back")


func test_a_sprawl_on_a_shot_from_range_puts_him_on_his_knees() -> void:
	var setup: Array = _watched("standing", 0, Vector2(0.6, 0.6), Vector2(-0.6, 0.6))
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 0, "double_leg", "active", 0.3)
	_frames(view, 1)
	_stopped(view, sim, 0, "double_leg", "sprawled on")
	_frames(view, 15)
	assert_eq(String(view._takedown.state), "sprawl")
	assert_lt(_pelvis(view, 0).y, 0.5, "red down on his knees")
	sim.fighters[0].clear_action()
	_frames(view, 1)
	assert_true(view._takedown.is_empty(), "back up when his move is over")


func test_the_catch_kick_single_holds_the_leg_he_kicked_with() -> void:
	for kick: String in ["body_kick", "teep"]:
		var setup: Array = _watched("standing", 0, Vector2(0.6, 0.6), Vector2(-0.6, 0.6))
		var sim: FightSim = setup[0]
		var view: ArenaView = setup[1]
		_doing(sim, 1, kick, "active", 0.5)
		_doing(sim, 0, "catch_kick_single", "active", 0.1)
		_frames(view, 1)
		assert_eq(String(view._takedown.get("move", "")), "catch_kick_single", kick)
		var held: String = "ankle_" + view._kicking_leg(sim, 1)
		var other: String = "ankle_" + ("l" if held == "ankle_r" else "r")
		assert_gt(float(view._clinch_rigs[1].joints[held].y), 0.6, "%s: his kicking leg held up" % kick)
		assert_lt(float(view._clinch_rigs[1].joints[other].y), 0.3, "%s: hopping on the other" % kick)


func test_following_him_down_dives_on_top_and_lands_in_half_guard() -> void:
	var setup: Array = _watched("standing", 0, Vector2(0.6, 0.6), Vector2(-0.6, 0.6))
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	sim.fighters[1].down_ticks = 20
	_frames(view, 10)
	_doing(sim, 0, "follow_down", "active", 0.5)
	_frames(view, 1)
	assert_eq(String(view._takedown.get("move", "")), "follow_down")
	assert_lt(_pelvis(view, 1).y, 0.3, "blue down")
	assert_lt(_head(view, 0).y, 1.3, "red diving in low")
	_won(view, sim, 0, "follow_down", PositionLibrary.SUCCESS)
	_frames(view, 30)
	assert_signal_emitted_with_parameters(view, "takedown_landed", [ShotPair.TIMING.follow_down.thud])
	assert_eq(sim.situation.position, "half_guard")
	assert_true(view.rig_ground(sim), "half guard from the rig")
