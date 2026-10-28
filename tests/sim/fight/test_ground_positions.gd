extends GutTest
## Ground positions (docs/01 §28, D130): half guard, side control, mount and the back, the passes
## and escapes between them, the holds and strikes each one allows, the judges' points for a
## better position, and the fighter AI working from them.

const SEED: int = 20261028
## Enough seeds that a 95% move works on most of them and a rarer outcome turns up.
const SEEDS: int = 40
## Stats that win every contest on top, and lose every one underneath.
const TOP_BEST := { "top_control": 100, "strength": 100, "scrambles": 100, "submissions": 100 }
const BOTTOM_WORST := { "guard": 0, "scrambles": 0, "strength": 0, "submission_defense": 0 }

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, a step apart in the middle of the cage.
func _pair(red: FighterState, blue: FighterState, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [red, blue], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	return sim


func _statue(fighter_name: String, p_stats: Dictionary = {}) -> FighterState:
	return FighterState.new(fighter_name, p_stats, [], 0.0)


## Red on top of Blue in `where` (no rolls): taken down into full guard, then passed and so on.
func _red_on_top(where: String, red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	return _on_top(where, _statue("Red", red_stats), _statue("Blue", blue_stats), fight_seed)


func _on_top(where: String, red: FighterState, blue: FighterState, fight_seed: int = SEED) -> FightSim:
	var sim: FightSim = _pair(red, blue, fight_seed)
	var path := { "full_guard": [], "side_control": ["guard_pass"], "mount": ["guard_pass", "take_mount"],
		"back_control": ["guard_pass", "take_back"], "half_guard": [] }
	assert_true(sim.apply_transition(0, "double_leg"))
	for id: String in path[where]:
		assert_true(sim.apply_transition(0, id), "%s on the way to %s" % [id, where])
	if where == "half_guard":
		assert_true(sim.apply_transition(0, "guard_pass", PositionLibrary.PARTIAL))
	assert_eq(sim.situation.position, where)
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)), action_id)


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


func _starts(sim: FightSim, actor: int) -> Array[String]:
	var out: Array[String] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, actor):
		if e.data.phase == "telegraph":
			out.append(e.data.action_id)
	return out


# --- The positions --------------------------------------------------------------------

func test_every_new_position_has_a_way_out_from_underneath_that_everyone_knows() -> void:
	var positions := PositionLibrary.shared()
	for where: String in ["half_guard", "side_control", "mount", "back_control"]:
		var p: Dictionary = positions.get_position(where)
		assert_eq(p.phase, PositionLibrary.PHASE_GROUND, where)
		assert_eq(p.roles, [PositionLibrary.TOP, PositionLibrary.BOTTOM], where)
		var outs: Array[String] = []
		for t: Dictionary in p.transitions:
			if t.from_role == PositionLibrary.BOTTOM and bool(_actions.get_action(t.action).get("basic", false)):
				outs.append(t.action)
		assert_gt(outs.size(), 0, "nobody is ever stuck under %s" % where)
		assert_true(_actions.get_action("ground_punch").positions.has(where), "the top fighter can punch from %s" % where)


func test_the_better_the_position_the_more_the_judges_score_it_and_the_harder_the_strikes() -> void:
	var positions := PositionLibrary.shared()
	var control: Array[float] = []
	for where: String in ["full_guard", "half_guard", "side_control", "mount"]:
		control.append(float(positions.get_position(where).control_score.top))
	for k in range(1, control.size()):
		assert_gt(control[k], control[k - 1], "each step past the guard scores more")
	assert_gt(float(positions.get_position("mount").strike_damage_multiplier.top), 1.0, "punches from mount land hardest")
	assert_lt(float(positions.get_position("back_control").strike_damage_multiplier.top), 1.0, "punches from the back land softer")


func test_a_guard_pass_gets_to_side_control_or_half_works_into_half_guard() -> void:
	var ends := {}
	for n in SEEDS:
		var sim: FightSim = _red_on_top("full_guard", { "top_control": 70, "strength": 70 }, { "guard": 70 }, SEED + n)
		_queue(sim, sim.now, 0, "guard_pass")
		_ticks(sim, 12)  # Telegraph 0.2 s, wind-up 0.3 s, active 0.4 s.
		ends[sim.situation.position] = true
		if sim.situation.position != "full_guard":
			assert_eq(sim.situation.role(0), PositionLibrary.TOP, "the passer stays on top")
	assert_true(ends.has("side_control"), "passed")
	assert_true(ends.has("half_guard"), "half passed: half guard")
	assert_true(ends.has("full_guard"), "and sometimes the guard holds")


func test_a_better_position_scores_the_control_gained_and_nothing_for_the_one_underneath() -> void:
	var sim: FightSim = _red_on_top("full_guard")
	var before: Array[float] = sim.round_points()
	assert_true(sim.apply_transition(0, "guard_pass"))
	assert_almost_eq(sim.round_points()[0] - before[0], Judging.ADVANCE_POINTS_PER_CONTROL * 0.5, 0.001, "full guard 1.0 to side control 1.5")
	assert_eq(sim.round_points()[1], before[1])
	assert_eq(sim.fighters[0].advances, 1)
	assert_eq(sim.fighters[0].takedowns_landed, 1, "the pass isn't another takedown")
	var mounted: Array[float] = sim.round_points()
	assert_true(sim.apply_transition(0, "take_mount"))
	assert_almost_eq(sim.round_points()[0] - mounted[0], Judging.ADVANCE_POINTS_PER_CONTROL * 0.5, 0.001, "side control 1.5 to mount 2.0")
	var at_mount: Array[float] = sim.round_points()
	assert_true(sim.apply_transition(0, "take_back"))
	assert_eq(sim.round_points()[0], at_mount[0], "the back scores the same control as mount: no points for the move")


func test_the_armbar_works_from_the_top_of_mount_and_the_bottom_of_full_guard_only() -> void:
	var guard: FightSim = _red_on_top("full_guard")
	assert_ne(guard.why_not(0, "armbar"), "", "not from the top of full guard")
	assert_eq(guard.why_not(1, "armbar"), "", "from the bottom of full guard (D126)")
	var mount: FightSim = _red_on_top("mount")
	assert_eq(mount.why_not(0, "armbar"), "", "from the top of mount (D130)")
	assert_ne(mount.why_not(1, "armbar"), "", "not from underneath mount")
	assert_ne(mount.why_not(1, "get_up"), "", "nobody gets straight up from under mount")
	assert_eq(mount.why_not(1, "bridge"), "")


# --- Getting out ----------------------------------------------------------------------

func test_getting_out_from_under_side_control_mount_and_the_back() -> void:
	var side: FightSim = _red_on_top("side_control")
	assert_true(side.apply_transition(1, "recover_guard"))
	assert_eq(side.situation.position, "full_guard", "back to guard")
	assert_eq(side.situation.role(1), PositionLibrary.BOTTOM)
	assert_eq(side.fighters[1].escapes, 1)
	var mount: FightSim = _red_on_top("mount")
	var before: Array[float] = mount.round_points()
	assert_true(mount.apply_transition(1, "bridge"))
	assert_eq(mount.situation.position, "full_guard")
	assert_eq(mount.situation.role(1), PositionLibrary.TOP, "the bridge rolls him off: a reversal")
	assert_almost_eq(mount.round_points()[1] - before[1], Judging.TAKEDOWN_POINTS, 0.001, "ending up on top scores like a takedown")
	var half: FightSim = _red_on_top("mount")
	assert_true(half.apply_transition(1, "bridge", PositionLibrary.PARTIAL))
	assert_eq(half.situation.position, "half_guard", "a bridge that half works gets a leg back: half guard")
	assert_eq(half.situation.role(1), PositionLibrary.BOTTOM)
	var back: FightSim = _red_on_top("back_control")
	assert_true(back.apply_transition(1, "escape_back"))
	assert_eq(back.situation.position, "full_guard")
	assert_eq(back.situation.role(1), PositionLibrary.TOP, "turning out of the back ends up in his guard")


func test_escaping_shows_an_opening_the_top_fighter_can_take() -> void:
	var sim: FightSim = _red_on_top("side_control")
	_queue(sim, sim.now, 1, "recover_guard")
	_ticks(sim, 3)  # Through the 0.2 s telegraph into the wind-up.
	assert_has(sim.active_flags(1), "ESCAPING")
	var names: Array[String] = []
	for b: Dictionary in sim.odds_breakdown(0, "take_back").bonuses:
		names.append(b.name)
	assert_has(names, "ESCAPING", "turning away to escape shows the back")


func test_the_rear_naked_choke_locks_from_the_back_and_an_escape_goes_back_there() -> void:
	var locked: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("back_control", TOP_BEST, BOTTOM_WORST, SEED + n)
		_queue(sim, sim.now, 0, "rear_naked_choke")
		_ticks(sim, 8)  # Wind-up 0.3 s, active 0.4 s.
		if sim.situation.position == PositionLibrary.SUBMISSION:
			locked += 1
			assert_eq(String(sim.hold().from), "back_control")
	assert_gt(locked, SEEDS * 3 / 4, "with every stat for him it locks almost every time")
	var escaped: FightSim = _red_on_top("back_control", {}, { "submission_defense": 100, "scrambles": 100 })
	assert_true(escaped._lock_in(0, _actions.get_action("rear_naked_choke")))
	_ticks(escaped, 60)
	assert_false(escaped.is_over())
	assert_eq(escaped.situation.position, "back_control", "out of the choke, still on the back")


func test_punches_land_harder_from_mount_than_from_the_guard() -> void:
	var dealt := {}
	for where: String in ["full_guard", "mount"]:
		var total: int = 0
		for n in SEEDS:
			var sim: FightSim = _red_on_top(where, { "top_control": 100, "boxing": 100 }, { "guard": 0 }, SEED + n)
			_queue(sim, sim.now, 0, "ground_punch")
			_ticks(sim, 5)
			for e in _events(sim, FightEvent.STRIKE_LANDED, 0):
				total += int(e.data.damage)
		dealt[where] = total
	assert_gt(dealt.mount, dealt.full_guard)


# --- The fighter AI -------------------------------------------------------------------

func test_on_top_the_ai_passes_and_works_to_better_positions() -> void:
	var roster := FighterLibrary.load_dir()
	var reached := {}
	var starts := {}
	for n in 10:
		var sim: FightSim = _on_top("full_guard", roster.make("wrestler"), _statue("Statue"), SEED + n)
		_ticks(sim, 900)
		for id in _starts(sim, 0):
			starts[id] = true
		for e in _events(sim, FightEvent.POSITION_CHANGED, 0):
			reached[e.data.position] = true
	assert_true(starts.has("guard_pass"), "he passes")
	assert_true(starts.has("ground_punch"), "and still grounds and pounds")
	assert_true(reached.has("side_control"), "past the guard")
	assert_true(reached.has("mount") or reached.has("back_control"), "and on to the mount or the back")


func test_the_ai_takes_the_back_when_the_fighter_underneath_turns_to_escape() -> void:
	var roster := FighterLibrary.load_dir()
	var took: int = 0
	for n in SEEDS:
		var sim: FightSim = _on_top("side_control", roster.make("wrestler"), _statue("Bottom"), SEED + n)
		_queue(sim, sim.now, 1, "recover_guard")
		_ticks(sim, 12)
		if _starts(sim, 0).has("take_back"):
			took += 1
	assert_gt(took, 0, "the escape gives the back away now and then")
	assert_lt(took, SEEDS, "but not every time")


func test_on_the_back_the_ai_goes_for_the_choke_without_waiting_for_an_opening() -> void:
	var tried: int = 0
	for n in 10:
		var sim: FightSim = _on_top("back_control", FighterState.new("Top", { "submissions": 80 }, ["jab"], 0.03), _statue("Bottom"), SEED + n)
		_ticks(sim, 600)
		if _starts(sim, 0).has("rear_naked_choke"):
			tried += 1
	assert_gt(tried, 5, "everyone knows the choke, and the back is the opening")


func test_underneath_the_ai_works_the_escape_for_the_position_it_is_in() -> void:
	var expect := { "side_control": "recover_guard", "mount": "bridge", "back_control": "escape_back" }
	for where: String in expect:
		var sim: FightSim = _on_top(where, _statue("Top"), FighterState.new("Bottom", {}, ["jab"], 0.03))
		_ticks(sim, 300)
		assert_has(_starts(sim, 1), expect[where], "out from under %s" % where)


# --- Calls, the corner, the feed --------------------------------------------------------

func test_pass_works_on_top_and_get_up_calls_the_escape_for_wherever_they_are() -> void:
	var calls := CallLibrary.shared()
	assert_eq(int(calls.get_call("pass").hotkey), int(calls.get_call("takedown").hotkey), "Pass! on the ground is key 4, Takedown! standing")
	var sim: FightSim = _red_on_top("side_control", {}, {}, SEED)
	sim.fighters[0].work_rate = 0.0
	sim.submit(FightCommand.live_call(sim.now, 0, "pass"))
	sim.submit(FightCommand.live_call(sim.now, 1, "get_up"))
	_ticks(sim, 30)
	assert_has(_starts(sim, 0), "take_mount", "from side control, Pass! is the mount")
	assert_has(_starts(sim, 1), "recover_guard", "under side control, Get up! is back to guard first")


func test_the_corner_calls_ground_and_pound_on_landing_on_top_not_on_every_pass() -> void:
	var sim: FightSim = _pair(_statue("Red"), _statue("Blue"))
	sim.corners[0] = Corner.new(Corner.IDEAL, 1)
	var calls: Array[String] = []
	sim.event_emitted.connect(func(e: FightEvent) -> void:
		if e.type == FightEvent.CALL_HEARD and e.actor == 0:
			calls.append(String(e.data.get("call_id", ""))))
	assert_true(sim.apply_transition(0, "double_leg"))
	_ticks(sim, 30)
	assert_true(sim.apply_transition(0, "guard_pass"))
	_ticks(sim, 30)
	assert_eq(calls.count("ground_and_pound"), 1)


func test_the_feed_says_who_has_the_back_and_where_half_a_pass_lands() -> void:
	var sim: FightSim = _red_on_top("full_guard")
	assert_true(sim.apply_transition(0, "guard_pass"))
	assert_true(sim.apply_transition(0, "take_back"))
	var moved: FightEvent = _events(sim, FightEvent.POSITION_CHANGED)[-1]
	assert_string_contains(FightLogFormatter.line(moved, sim), "has the back")
	assert_string_contains(ArenaView.tag_text(sim), "Red has the back")
	var half := FightEvent.new(0, 1, FightEvent.GRAPPLE_WON, 0, { "action_id": "guard_pass", "result": PositionLibrary.PARTIAL, "to": "half_guard", "chance": 0.4 })
	assert_string_contains(FightLogFormatter.line(half, sim), "half works[/b]: half guard")


func test_the_harness_reports_time_in_each_position() -> void:
	var row: Dictionary = FightSummary.run(SEED, FighterLibrary.load_dir(), _actions, "wrestler", "boxer", 1, 300)
	for key: String in ["full_guard", "half_guard", "side_control", "mount", "back_control", "advances_red", "escapes_blue"]:
		assert_has(row, key)
	assert_has(FightSummary.COLUMNS, "side_control")
