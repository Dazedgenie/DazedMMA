extends GutTest
## Grips on the ground (D263, docs/01 §40.11): from underneath the tie-up (the collar tie) and wrist
## control, held until the man on top postures up; in half guard the underhook, dug from underneath
## or taken on top with the crossface; what each does to the ground strikes, the pass, getting up
## and the sweep, and the AI fighting for them.

const SEED: int = 20261031
const SEEDS: int = 30

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _statue(fighter_name: String, p_stats: Dictionary = {}) -> FighterState:
	return FighterState.new(fighter_name, p_stats, [], 0.0)


## Red on top of Blue (no rolls): in full guard, passed half-way into half guard, or on to side
## control, the mount, his back or the crucifix.
func _red_on_top(where: String = "full_guard", red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [_statue("Red", red_stats), _statue("Blue", blue_stats)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_true(sim.apply_transition(0, "double_leg"))
	if where == "half_guard":
		assert_true(sim.apply_transition(0, "guard_pass", PositionLibrary.PARTIAL))
	elif where != "full_guard":
		assert_true(sim.apply_transition(0, "guard_pass"))
		if where == "mount":
			assert_true(sim.apply_transition(0, "take_mount"))
		elif where == "back_control":
			assert_true(sim.apply_transition(0, "take_back"))
		elif where == "crucifix":
			assert_true(sim.apply_transition(0, "take_crucifix"))
	assert_eq(sim.situation.position, where)
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)), action_id)


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = -2) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == -2 or e.actor == actor):
			out.append(e)
	return out


func _bonus(sim: FightSim, i: int, id: String, name: String) -> float:
	for bonus: Dictionary in sim.odds_breakdown(i, id).to_dict().get("bonuses", []):
		if bonus.name == name:
			return float(bonus.value)
	return 0.0


# --- Wrists and the collar tie ---------------------------------------------------

func test_wrist_control_holds_one_wrist_then_both() -> void:
	var held: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("full_guard", { "top_control": 0 }, { "guard": 100, "strength": 100 }, SEED + n)
		_queue(sim, 0, 1, "wrist_control")
		_ticks(sim, 8)
		if sim.ground_grips().wrists == 0:
			continue
		held += 1
		assert_has(sim.active_flags(0), FightSim.WRIST_HELD)
		assert_does_not_have(sim.active_flags(0), FightSim.WRISTS_HELD, "one hand still free")
		assert_false(sim.hands_tied(0), "he can still punch with the other")
		_queue(sim, sim.now, 1, "wrist_control")
		_ticks(sim, 8)
		if sim.ground_grips().wrists == 2:
			assert_has(sim.active_flags(0), FightSim.WRISTS_HELD)
			assert_true(sim.hands_tied(0), "both held: no punches")
	assert_gt(held, SEEDS / 2, "most wrist grabs work at the best odds (%d of %d)" % [held, SEEDS])


func test_one_wrist_held_makes_his_ground_strikes_harder_and_both_stop_them() -> void:
	var sim: FightSim = _red_on_top()
	sim.set_ground_grips(1, false)
	assert_almost_eq(_bonus(sim, 0, "ground_punch", "own " + FightSim.WRIST_HELD), -0.10, 0.001)
	assert_almost_eq(_bonus(sim, 0, "hammerfist", "own " + FightSim.WRIST_HELD), -0.05, 0.001, "the hammerfist comes round the grip")
	sim.set_ground_grips(2, false)
	_queue(sim, 0, 0, "ground_punch")
	_ticks(sim, 10)
	var missed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_MISSED, 0)
	assert_eq(missed.size(), 1)
	assert_eq(missed[0].data.reason, "tied up")


func test_with_his_head_tied_the_man_on_top_cant_strike_and_his_pass_is_harder() -> void:
	var sim: FightSim = _red_on_top()
	sim.set_ground_grips(0, true)
	assert_true(sim.hands_tied(0))
	assert_has(sim.active_flags(0), "POSTURE_BROKEN")
	assert_almost_eq(_bonus(sim, 0, "guard_pass", "own POSTURE_BROKEN"), -0.10, 0.001)
	assert_almost_eq(_bonus(sim, 1, "triangle", "POSTURE_BROKEN"), 0.15, 0.001, "and the triangle is on")


func test_a_held_wrist_sets_up_the_armbar_and_the_tie_up() -> void:
	var sim: FightSim = _red_on_top()
	sim.set_ground_grips(1, false)
	assert_almost_eq(_bonus(sim, 1, "armbar", FightSim.WRIST_HELD), 0.10, 0.001)
	assert_almost_eq(_bonus(sim, 1, "tie_up", FightSim.WRIST_HELD), 0.10, 0.001)


func test_he_cant_take_a_grip_he_already_has() -> void:
	var sim: FightSim = _red_on_top()
	sim.set_ground_grips(2, true)
	assert_eq(sim.odds_breakdown(1, "tie_up").missing, "already tied up")
	assert_eq(sim.odds_breakdown(1, "wrist_control").missing, "both wrists held")
	_queue(sim, 0, 1, "tie_up")
	_ticks(sim, 6)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 1)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "already tied up")
	assert_string_contains(FightLogFormatter.describe(stopped[0], sim), "has the tie-up already")


func test_posturing_up_frees_the_head_first_then_a_wrist() -> void:
	var freed: Array[String] = []
	for n in SEEDS:
		var sim: FightSim = _red_on_top("full_guard", { "top_control": 100, "strength": 100 }, { "guard": 0 }, SEED + n)
		sim.set_ground_grips(1, true)
		_queue(sim, 0, 0, "posture_up")
		_ticks(sim, 8)
		var won: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
		if won.is_empty():
			continue
		assert_eq(won[0].data.result, "freed head")
		assert_false(sim.ground_grips().collar)
		assert_eq(sim.ground_grips().wrists, 1, "the wrist is still held")
		assert_false(sim.hands_tied(0), "one hand free: he can punch again")
		_queue(sim, sim.now, 0, "posture_up")
		_ticks(sim, 8)
		won = _events(sim, FightEvent.GRAPPLE_WON, 0)
		freed.append(String(won[-1].data.result))
	assert_gt(freed.size(), SEEDS / 2)
	assert_has(freed, "freed wrist")


func test_posturing_up_with_nothing_held_is_refused() -> void:
	var sim: FightSim = _red_on_top()
	assert_eq(sim.odds_breakdown(0, "posture_up").missing, "nothing to strip")
	assert_eq(sim.odds_breakdown(0, "posture_up").chance, 0.0)


func test_posturing_up_opens_the_armbar_and_the_get_up() -> void:
	var sim: FightSim = _red_on_top()
	sim.set_ground_grips(0, true)
	_queue(sim, 0, 0, "posture_up")
	_ticks(sim, 2)  # In the wind-up.
	assert_has(sim.active_flags(0), "POSTURED_UP")
	assert_gt(_bonus(sim, 1, "armbar", "POSTURED_UP"), 0.0)
	assert_gt(_bonus(sim, 1, "get_up", "POSTURED_UP"), 0.0)


func test_the_grips_go_when_the_position_changes() -> void:
	var sim: FightSim = _red_on_top()
	sim.set_ground_grips(2, true)
	assert_true(sim.apply_transition(0, "guard_pass"))
	var grips: Dictionary = sim.ground_grips()
	assert_eq([grips.wrists, grips.collar, grips.half_inside], [0, false, FightSim.NO_GRIP])
	assert_false(sim.hands_tied(0))


# --- The half-guard underhook ----------------------------------------------------

func test_the_underhook_from_half_guard_helps_him_up_and_stops_the_pass() -> void:
	var sim: FightSim = _red_on_top("half_guard")
	sim.set_ground_grips(0, false, 1)
	assert_has(sim.active_flags(1), FightSim.UNDERHOOK)
	assert_almost_eq(_bonus(sim, 1, "get_up", "own " + FightSim.UNDERHOOK), 0.10, 0.001)
	assert_almost_eq(_bonus(sim, 1, "sweep", "own " + FightSim.UNDERHOOK), 0.15, 0.001)
	assert_almost_eq(_bonus(sim, 0, "guard_pass", FightSim.UNDERHOOK), -0.15, 0.001)


func test_the_crossface_takes_the_underhook_back_and_helps_the_pass() -> void:
	var taken: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("half_guard", { "top_control": 100, "strength": 100 }, { "guard": 0, "strength": 0 }, SEED + n)
		sim.set_ground_grips(0, false, 1)
		_queue(sim, 0, 0, "crossface")
		_ticks(sim, 8)
		if sim.ground_grips().half_inside != 0:
			continue
		taken += 1
		assert_does_not_have(sim.active_flags(1), FightSim.UNDERHOOK)
		assert_almost_eq(_bonus(sim, 0, "guard_pass", "own " + FightSim.UNDERHOOK), 0.15, 0.001)
		assert_almost_eq(_bonus(sim, 1, "get_up", FightSim.UNDERHOOK), -0.10, 0.001)
		assert_string_contains(FightLogFormatter.describe(_events(sim, FightEvent.GRAPPLE_WON, 0)[0], sim), "CROSSFACES")
	assert_gt(taken, SEEDS / 2)
	var sim2: FightSim = _red_on_top("half_guard")
	sim2.set_ground_grips(0, false, 0)
	assert_eq(sim2.odds_breakdown(0, "crossface").missing, "has the underhook")


func test_the_half_guard_moves_only_work_in_half_guard() -> void:
	var sim: FightSim = _red_on_top()
	assert_ne(sim.why_not(1, "dig_underhook"), "")
	assert_ne(sim.why_not(0, "crossface"), "")


# --- The AI --------------------------------------------------------------------

func test_underneath_the_ai_ties_up_and_controls_wrists_and_on_top_it_postures_up() -> void:
	var roster := FighterLibrary.load_dir()
	var tried: Dictionary = {}
	for n in 10:
		var sim := FightSim.new(SEED + n, roster.make_pair("wrestler", "boxer"), _actions, 1, 300)
		sim.apply_transition(0, "double_leg")
		_ticks(sim, 400)
		for e in _events(sim, FightEvent.ACTION_PHASE):
			if e.data.phase == "windup":
				tried[e.data.action_id] = tried.get(e.data.action_id, 0) + 1
	assert_gt(tried.get("tie_up", 0), 0, "the Boxer ties him up")
	assert_gt(tried.get("wrist_control", 0), 0, "and grabs wrists")
	assert_gt(tried.get("posture_up", 0), 0, "the Wrestler postures up out of them")


func test_in_half_guard_both_fight_for_the_underhook() -> void:
	var roster := FighterLibrary.load_dir()
	var tried: Dictionary = {}
	for n in 10:
		var sim := FightSim.new(SEED + n, roster.make_pair("wrestler", "bjj"), _actions, 1, 300)
		sim.apply_transition(0, "double_leg")
		sim.apply_transition(0, "guard_pass", PositionLibrary.PARTIAL)
		_ticks(sim, 300)
		for e in _events(sim, FightEvent.ACTION_PHASE):
			if e.data.phase == "windup":
				tried[e.data.action_id] = tried.get(e.data.action_id, 0) + 1
	assert_gt(tried.get("dig_underhook", 0), 0, "underneath he digs for it")
	assert_gt(tried.get("crossface", 0), 0, "on top he crossfaces")


# --- The rest of the ground (D264) ------------------------------------------------

func test_a_frame_helps_him_out_from_under_and_makes_the_mount_harder() -> void:
	var sim: FightSim = _red_on_top("side_control")
	sim.set_ground_grips(0, false, FightSim.NO_GRIP, true)
	assert_has(sim.active_flags(1), FightSim.FRAMED)
	assert_almost_eq(_bonus(sim, 1, "recover_guard", "own " + FightSim.FRAMED), 0.15, 0.001)
	assert_almost_eq(_bonus(sim, 0, "take_mount", FightSim.FRAMED), -0.10, 0.001)
	var mounted: FightSim = _red_on_top("mount")
	mounted.set_ground_grips(0, false, FightSim.NO_GRIP, true)
	assert_almost_eq(_bonus(mounted, 1, "bridge", "own " + FightSim.FRAMED), 0.10, 0.001)


func test_flattening_him_takes_the_frame_away() -> void:
	var gone: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("side_control", { "top_control": 100, "strength": 100 }, { "guard": 0, "strength": 0 }, SEED + n)
		sim.set_ground_grips(0, false, FightSim.NO_GRIP, true)
		_queue(sim, 0, 0, "flatten")
		_ticks(sim, 8)
		if not sim.ground_grips().frame:
			gone += 1
			assert_string_contains(FightLogFormatter.describe(_events(sim, FightEvent.GRAPPLE_WON, 0)[0], sim), "FLATTENS")
	assert_gt(gone, SEEDS / 2)
	var sim2: FightSim = _red_on_top("side_control")
	assert_eq(sim2.odds_breakdown(0, "flatten").missing, "no frame")


func test_the_crucifix_traps_his_arms_and_opens_his_face() -> void:
	var sim: FightSim = _red_on_top("crucifix")
	assert_has(sim.active_flags(1), FightSim.ARM_PINNED)
	assert_almost_eq(_bonus(sim, 0, "ground_punch", FightSim.ARM_PINNED), 0.10, 0.001)
	assert_almost_eq(_bonus(sim, 0, "ground_elbow", FightSim.ARM_PINNED), 0.10, 0.001)
	assert_ne(sim.why_not(1, "frame"), "", "no frame with both arms trapped")
	assert_ne(sim.why_not(1, "recover_guard"), "", "no guard to recover: he has to free the arm first")
	assert_eq(sim.why_not(1, "escape_crucifix"), "")
	assert_eq(sim.why_not(0, "take_back"), "", "the back is a step away")


func test_taking_the_crucifix_from_side_control() -> void:
	var taken: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("side_control", { "top_control": 100, "scrambles": 100 }, { "guard": 0, "scrambles": 0 }, SEED + n)
		_queue(sim, 0, 0, "take_crucifix")
		_ticks(sim, 10)
		if sim.situation.position == FightSim.CRUCIFIX:
			taken += 1
			assert_eq(sim.situation.role(0), PositionLibrary.TOP)
			assert_eq(sim.fighters[0].crucifixes_won, 1)
		assert_eq(sim.fighters[0].crucifixes_tried, 1)
	assert_gt(taken, SEEDS / 3)
	var framed: FightSim = _red_on_top("side_control")
	framed.set_ground_grips(0, false, FightSim.NO_GRIP, true)
	assert_almost_eq(_bonus(framed, 0, "take_crucifix", FightSim.FRAMED), -0.10, 0.001, "a frame keeps the arm out of reach")


func test_freeing_the_arm_gets_him_back_to_side_control() -> void:
	var out: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("crucifix", { "top_control": 0 }, { "scrambles": 100, "strength": 100 }, SEED + n)
		_queue(sim, 0, 1, "escape_crucifix")
		_ticks(sim, 10)
		if sim.situation.position != FightSim.CRUCIFIX:
			out += 1
			assert_true(sim.situation.position in ["side_control", PositionLibrary.SCRAMBLE], sim.situation.position)
	assert_gt(out, SEEDS / 2)


func test_in_the_crucifix_his_cover_up_barely_helps() -> void:
	var through: Dictionary = {}
	for where: String in ["side_control", "crucifix"]:
		var dealt: Array[int] = []
		for covered: bool in [false, true]:
			var sim: FightSim = _red_on_top(where, { "top_control": 100, "boxing": 100 }, { "guard": 0 })
			if covered:
				_queue(sim, 0, 1, "ground_cover")
				_ticks(sim, 2)
			_queue(sim, sim.now, 0, "ground_punch")
			_ticks(sim, 10)
			var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
			assert_eq(landed.size(), 1, "%s covered %s" % [where, covered])
			dealt.append(int(landed[0].data.damage))
		through[where] = float(dealt[1]) / float(dealt[0])
	assert_gt(through.crucifix, through.side_control, "more gets through the cover-up with his arms trapped")
	assert_gte(through.crucifix, FightSim.PINNED_COVER_SHARE - 0.15)


func test_two_hands_on_the_choking_arm_stop_the_choke_and_help_him_out() -> void:
	var sim: FightSim = _red_on_top("back_control")
	sim.set_ground_grips(0, false, FightSim.NO_GRIP, false, true)
	assert_has(sim.active_flags(1), FightSim.TWO_ON_ONE_HELD)
	assert_almost_eq(_bonus(sim, 0, "rear_naked_choke", FightSim.TWO_ON_ONE_HELD), -0.20, 0.001)
	assert_almost_eq(_bonus(sim, 1, "escape_back", "own " + FightSim.TWO_ON_ONE_HELD), 0.10, 0.001)
	assert_eq(sim.odds_breakdown(1, "two_on_one").missing, "has the arm already")
	var stripped: int = 0
	for n in SEEDS:
		var s2: FightSim = _red_on_top("back_control", { "submissions": 100, "strength": 100 }, { "submission_defense": 0, "strength": 0 }, SEED + n)
		s2.set_ground_grips(0, false, FightSim.NO_GRIP, false, true)
		_queue(s2, 0, 0, "strip_hands")
		_ticks(s2, 8)
		if not s2.ground_grips().two_on_one:
			stripped += 1
	assert_gt(stripped, SEEDS / 2)
	var s3: FightSim = _red_on_top("back_control")
	assert_eq(s3.odds_breakdown(0, "strip_hands").missing, "no hands on the arm")


func test_a_frame_or_two_hands_on_the_arm_answer_the_referee_but_freeing_nothing_doesnt() -> void:
	for setup: Array in [["side_control", "frame"], ["back_control", "two_on_one"]]:
		var answered: int = 0
		for n in SEEDS:
			var sim: FightSim = _red_on_top(setup[0], {}, { "guard": 100, "strength": 100, "submission_defense": 100 }, SEED + n)
			sim.fighters[1].unanswered = 5
			_queue(sim, 0, 1, setup[1])
			_ticks(sim, 6)
			if _events(sim, FightEvent.GRAPPLE_WON, 1).is_empty():
				assert_eq(sim.fighters[1].unanswered, 5, "%s: missing it answers nothing" % setup[1])
			else:
				answered += 1
				assert_eq(sim.fighters[1].unanswered, 0, "%s: he's defending" % setup[1])
		assert_gt(answered, SEEDS / 2, setup[1])


func test_underneath_in_side_control_the_ai_frames_and_on_top_it_flattens_or_takes_the_crucifix() -> void:
	var roster := FighterLibrary.load_dir()
	var tried: Dictionary = {}
	for n in 10:
		var sim := FightSim.new(SEED + n, roster.make_pair("wrestler", "boxer"), _actions, 1, 300)
		sim.apply_transition(0, "double_leg")
		sim.apply_transition(0, "guard_pass")
		_ticks(sim, 300)
		for e in _events(sim, FightEvent.ACTION_PHASE):
			if e.data.phase == "windup":
				tried[e.data.action_id] = tried.get(e.data.action_id, 0) + 1
	assert_gt(tried.get("frame", 0), 0, "the Boxer frames")
	assert_gt(tried.get("flatten", 0) + tried.get("take_crucifix", 0), 0, "the Wrestler flattens him or goes for the crucifix")


func test_with_his_back_taken_the_ai_fights_the_hands() -> void:
	var roster := FighterLibrary.load_dir()
	var tried: Dictionary = {}
	for n in 10:
		var sim := FightSim.new(SEED + n, roster.make_pair("bjj", "boxer"), _actions, 1, 300)
		sim.apply_transition(0, "double_leg")
		sim.apply_transition(0, "guard_pass")
		sim.apply_transition(0, "take_back")
		_ticks(sim, 200)
		for e in _events(sim, FightEvent.ACTION_PHASE):
			if e.data.phase == "windup":
				tried[e.data.action_id] = tried.get(e.data.action_id, 0) + 1
	assert_gt(tried.get("two_on_one", 0), 0, "the Boxer gets two hands on the arm")
	assert_gt(tried.get("strip_hands", 0), 0, "the BJJ fighter strips them")
