extends GutTest
## Knockdowns from the rig on the fight screen (D370, D371): the fall by the shot that dropped him, down the fence
## with no room behind him, the liver shot and the leg giving out, getting up through a knee, a knockout leaving him
## down, following him down from where he lies, and the rocked wobble (D372). Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched standing fight, red at `red` and blue at `blue`: [sim, view].
func _watched(red := Vector2(0.6, 0.0), blue := Vector2(-0.6, 0.0)) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)
	sim.fighters[0].pos = red
	sim.fighters[1].pos = blue
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	view.driver._snap()
	_frames(view, 10, 1.0 / 10.0)
	return [sim, view]


func _frames(view: ArenaView, count: int, delta: float = 1.0 / 30.0) -> void:
	for n in count:
		view._process(delta)


## Blue knocked down by red now, the event's `data` (flash, liver, leg), for `ticks`.
func _dropped(view: ArenaView, sim: FightSim, data: Dictionary, ticks: int = FightSim.DOWN_TICKS) -> void:
	var f: FighterState = sim.fighters[1]
	f.clear_action()
	f.down_ticks = ticks
	f.rocked_ticks = FightSim.ROCKED_TICKS
	data.by = 0
	view._on_event(FightEvent.new(sim.now, 1, FightEvent.KNOCKDOWN, 1, data))


## On `seconds` of fight time, the view caught up.
func _after(view: ArenaView, sim: FightSim, seconds: float) -> void:
	var ticks: int = roundi(seconds * FightClock.TICKS_PER_SECOND)
	sim.now += ticks
	var f: FighterState = sim.fighters[1]
	f.down_ticks = maxi(0, f.down_ticks - ticks)
	_frames(view, 3)


func _head(view: ArenaView) -> Vector3:
	return view._clinch_rigs[1].point("head")


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func test_a_flash_knockdown_drops_him_on_his_back_away_from_the_man_who_dropped_him() -> void:
	var setup: Array = _watched()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_dropped(view, sim, {"flash": true})
	_frames(view, 1)
	assert_eq(String(view._downed[1].kind), "stiff")
	_after(view, sim, KnockdownPose.TIMING.stiff.fall)
	var head: Vector3 = _head(view)
	assert_lt(head.y, 0.35, "down")
	assert_lt(head.x, -1.2, "fallen back, away from red")


func test_dropped_while_rocked_he_crumples_and_a_hook_turns_the_fall() -> void:
	var setup: Array = _watched()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	view._last_hit_turn[1] = 1.0
	_dropped(view, sim, {})
	_after(view, sim, KnockdownPose.TIMING.crumple.fall)
	assert_eq(String(view._downed[1].kind), "crumple")
	var head: Vector3 = _head(view)
	assert_lt(head.y, 0.35, "down")
	assert_gt(absf(head.z), 0.4, "turned off straight back by the hook")


func test_with_no_room_behind_him_he_goes_down_the_fence() -> void:
	var setup: Array = _watched(Vector2(-2.9, 0.0), Vector2(-3.95, 0.0))
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_dropped(view, sim, {"flash": true})
	_after(view, sim, 1.0)
	assert_eq(String(view._downed[1].kind), "fence")
	for spot: String in ["back", "seat", "back_of_head"]:
		var p: Vector3 = view._clinch_rigs[1].point(spot)
		assert_gt(Octagon.distance_to_fence(_flat(p)), -0.02, "%s not through the fence" % spot)
	assert_lt(view._clinch_rigs[1].point("seat").y, 0.3, "sat down against it")


func test_a_liver_shot_folds_him_onto_his_knees() -> void:
	var setup: Array = _watched()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_dropped(view, sim, {"liver": true}, FightSim.LIVER_DOWN_TICKS)
	_after(view, sim, KnockdownPose.TIMING.liver.fall)
	assert_eq(String(view._downed[1].kind), "liver")
	var rig: FighterRig = view._clinch_rigs[1]
	assert_lt(rig.joints.knee_l.y, 0.15, "on his knees")
	assert_lt(rig.joints.knee_r.y, 0.15, "on his knees")
	assert_lt(_head(view).y, 0.6, "curled over it")


func test_a_leg_giving_out_drops_him_onto_that_knee() -> void:
	for leg: int in [FighterState.LEFT_LEG, FighterState.RIGHT_LEG]:
		var setup: Array = _watched()
		var sim: FightSim = setup[0]
		var view: ArenaView = setup[1]
		_dropped(view, sim, {"leg": leg}, FightSim.LEG_DOWN_TICKS)
		_after(view, sim, KnockdownPose.TIMING.leg.fall)
		var rig: FighterRig = view._clinch_rigs[1]
		var gone: String = "knee_l" if leg == FighterState.LEFT_LEG else "knee_r"
		var other: String = "knee_r" if leg == FighterState.LEFT_LEG else "knee_l"
		assert_lt(rig.joints[gone].y, 0.15, "down on the leg that went")
		assert_gt(rig.joints[other].y, 0.3, "the other foot planted")


func test_he_gets_up_through_a_knee_and_goes_back_to_his_figure_once_up() -> void:
	var setup: Array = _watched()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_dropped(view, sim, {})
	var rise: float = KnockdownPose.TIMING.crumple.rise
	var down: float = float(FightSim.DOWN_TICKS) / FightClock.TICKS_PER_SECOND
	_after(view, sim, down - rise * 0.4)
	var rig: FighterRig = view._clinch_rigs[1]
	var low_knee: float = minf(rig.joints.knee_l.y, rig.joints.knee_r.y)
	assert_lt(low_knee, 0.2, "a knee on the canvas")
	assert_between(rig.bones.pelvis.global_position.y, 0.4, 0.8, "half way up")
	_after(view, sim, rise)
	assert_false(sim.fighters[1].is_down())
	assert_true(view._downed[1].is_empty(), "today's figure again")


func test_a_knockout_leaves_him_down() -> void:
	var setup: Array = _watched()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_dropped(view, sim, {"flash": true})
	sim._fight_over = true
	_frames(view, 120)
	assert_lt(_head(view).y, 0.35, "still down after the fight")
	assert_false(view._downed[1].is_empty())


func test_following_him_down_starts_from_where_he_lies() -> void:
	var setup: Array = _watched()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_dropped(view, sim, {"flash": true})
	_after(view, sim, 0.8)
	var hips: Vector3 = view._clinch_rigs[1].bones.pelvis.global_position
	var red: FighterState = sim.fighters[0]
	red.action_id = "follow_down"
	red.phase = "telegraph"
	var move: Dictionary = view._move_for(sim, 0)
	assert_false(move.is_empty())
	var frame: Transform3D = move.path[0][1]
	assert_lt(_flat(frame.origin).distance_to(_flat(hips)), 0.05, "dives on him where he fell")


func test_a_rocked_man_drops_his_hands_and_sinks_on_his_legs() -> void:
	var setup: Array = _watched()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var fresh: Dictionary = view.figures[1].pose_for(sim, 1)
	sim.fighters[1].rocked_ticks = FightSim.ROCKED_TICKS
	var lowest: float = INF
	for n in 30:
		sim.now += 1
		var rocked: Dictionary = view.figures[1].pose_for(sim, 1)
		assert_lt(float(rocked.arm_lead), float(fresh.arm_lead) - 0.3, "hands down")
		lowest = minf(lowest, float(rocked.hip_y))
	assert_lt(lowest, float(fresh.hip_y) - FighterFigure.ROCKED_DIP - 0.02, "his knees give now and then")
	sim.fighters[1].rocked_ticks = 2
	var coming_round: Dictionary = view.figures[1].pose_for(sim, 1)
	assert_gt(float(coming_round.arm_lead), float(fresh.arm_lead) - FighterFigure.ROCKED_HANDS * 0.5, "less as he comes round")
