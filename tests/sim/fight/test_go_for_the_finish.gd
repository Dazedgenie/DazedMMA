extends GutTest
## *Go for the finish!* (docs/01 §25.7, D200): the corner sends the fighter on top after a hold.
## For 10 s he goes for one he knows from where he is, passes to get to one if he has none there,
## and takes an escape's opening for one; once he has tried a hold he's back to his own pace.

const SEED: int = 20261030
const SEEDS: int = 20
## A call is heard, then acted on 6 ticks later (a humble fighter, neutral trust), and a punch
## already on its way finishes first: 2.5 s is plenty.
const ACT_WITHIN: int = 25

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## The Wrestler (humble, so he never ignores a call) on top of a fighter who does nothing.
func _wrestler_on_top(where: String, fight_seed: int = SEED) -> FightSim:
	var red: FighterState = _roster.make("wrestler")
	red.profile = red.profile.duplicate(true)
	red.profile["personality"] = { "ego": -100 }
	var sim := FightSim.new(fight_seed, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	var path := { "full_guard": [], "side_control": ["guard_pass"], "mount": ["guard_pass", "take_mount"],
		"back_control": ["guard_pass", "take_back"] }
	assert_true(sim.apply_transition(0, "double_leg"))
	for id: String in path[where]:
		assert_true(sim.apply_transition(0, id), "%s on the way to %s" % [id, where])
	return sim


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


## The moves a fighter started from tick `since` on, in order.
func _starts(sim: FightSim, actor: int = 0, since: int = 0) -> Array[String]:
	var out: Array[String] = []
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.actor == actor and e.tick >= since:
			out.append(e.data.action_id)
	return out


func _holds(sim: FightSim, actor: int = 0, since: int = 0) -> Array[String]:
	var out: Array[String] = []
	out.assign(_starts(sim, actor, since).filter(func(id: String) -> bool: return _actions.get_action(id).category == FighterAI.SUBMISSION))
	return out


## The tick Red acted on the call (its call_answered "accepted").
func _acted_at(sim: FightSim) -> int:
	for e in sim.events:
		if e.type == FightEvent.CALL_ANSWERED and e.actor == 0 and e.data.outcome == LiveCalls.ACCEPTED:
			return e.tick
	return -1


func _answers(sim: FightSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.CALL_ANSWERED and e.actor == 0:
			out.append(e.data)
	return out


func test_go_for_the_finish_is_key_2_on_top_of_every_ground_position() -> void:
	var call: Dictionary = CallLibrary.shared().get_call("go_for_the_finish")
	assert_eq(String(call.name), "Go for the finish!")
	assert_eq(int(call.hotkey), int(CallLibrary.shared().get_call("circle_out").hotkey), "key 2 on top, Circle out! standing")
	assert_eq(call.roles, ["top"])
	assert_eq(call.positions, ["full_guard", "half_guard", "side_control", "mount", "back_control"])
	assert_eq(LiveCalls.shape(call), LiveCalls.FOCUS)
	assert_eq(int(call.focus.duration_ms), 10000, "a 10 s hunt (Kyle, D200)")


func test_on_the_call_he_goes_for_a_hold_he_knows_from_here_within_a_couple_of_seconds() -> void:
	var expect := { "side_control": "arm_triangle", "mount": "arm_triangle", "back_control": "rear_naked_choke" }
	for where: String in expect:
		var called: int = 0
		var own: int = 0
		for n in SEEDS:
			var sim: FightSim = _wrestler_on_top(where, SEED + n)
			sim.submit(FightCommand.live_call(sim.now, 0, "go_for_the_finish"))
			_ticks(sim, ACT_WITHIN)
			if _holds(sim, 0, _acted_at(sim)) == [expect[where]]:
				called += 1
			var alone: FightSim = _wrestler_on_top(where, SEED + n)
			_ticks(alone, ACT_WITHIN)
			if not _holds(alone).is_empty():
				own += 1
		assert_eq(called, SEEDS, "from %s the call is the %s, every time" % [where, expect[where]])
		assert_lt(own, SEEDS / 2, "on his own he goes for it that soon from %s now and then" % where)


func test_with_no_hold_from_the_guard_he_passes_to_get_to_one() -> void:
	var passed: int = 0
	var held: int = 0
	for n in SEEDS:
		var sim: FightSim = _wrestler_on_top("full_guard", SEED + n)
		sim.submit(FightCommand.live_call(sim.now, 0, "go_for_the_finish"))
		_ticks(sim, ACT_WITHIN)
		if _starts(sim, 0, _acted_at(sim)).has("guard_pass"):
			passed += 1
		_ticks(sim, 100 - ACT_WITHIN)
		if not _holds(sim).is_empty():
			held += 1
	assert_eq(passed, SEEDS, "the Wrestler knows no hold from the top of full guard, so he passes inside a couple of seconds")
	assert_gt(held, SEEDS / 2, "and most times gets past and goes for the arm-triangle inside the 10 s")


func test_the_call_goes_for_a_hold_even_just_after_one_of_his_own() -> void:
	var sim: FightSim = _wrestler_on_top("side_control")
	sim.decisions[0].ai._sub_at = sim.now  # He tried one himself just now: on his own he'd wait 45 s.
	sim.submit(FightCommand.live_call(sim.now, 0, "go_for_the_finish"))
	_ticks(sim, ACT_WITHIN)
	assert_eq(_holds(sim, 0, _acted_at(sim)), ["arm_triangle"] as Array[String])


func test_once_he_has_tried_a_hold_the_hunt_is_over() -> void:
	for n in SEEDS:
		var sim: FightSim = _wrestler_on_top("side_control", SEED + n)
		sim.submit(FightCommand.live_call(sim.now, 0, "go_for_the_finish"))
		_ticks(sim, 100)
		assert_lte(_holds(sim, 0, _acted_at(sim)).size(), 1, "one hold a call (seed %d)" % (SEED + n))


func test_the_hunt_ends_after_10_seconds() -> void:
	var sim: FightSim = _wrestler_on_top("full_guard")
	sim.submit(FightCommand.live_call(sim.now, 0, "go_for_the_finish"))
	_ticks(sim, 8)
	assert_false(sim.decisions[0].hunt(sim.views[0]).is_empty(), "hunting")
	_ticks(sim, 100)
	assert_true(sim.decisions[0].hunt(sim.views[0]).is_empty(), "over 10 s after it was acted on")
	assert_has(_answers(sim).map(func(a: Dictionary) -> String: return a.outcome), LiveCalls.EXPIRED)


func test_underneath_or_standing_the_call_does_nothing() -> void:
	var sim: FightSim = _wrestler_on_top("side_control")
	sim.submit(FightCommand.live_call(sim.now, 1, "go_for_the_finish"))
	_ticks(sim, ACT_WITHIN)
	var under: Array = sim.events.filter(func(e: FightEvent) -> bool: return e.type == FightEvent.CALL_ANSWERED and e.actor == 1)
	assert_eq(under[0].data.outcome, LiveCalls.INFEASIBLE)
	assert_eq(under[0].data.reason, "not possible from the bottom")


func test_the_ai_corner_never_calls_it() -> void:
	# Fights without the call play out exactly as before (the golden fights, D122).
	for style: String in [Corner.IDEAL, Corner.AI]:
		var sim: FightSim = _wrestler_on_top("full_guard")
		sim.corners[0] = Corner.new(style, 1)
		_ticks(sim, 600)
		for e in sim.events:
			if e.type == FightEvent.CALL_HEARD and e.actor == 0:
				assert_ne(String(e.data.get("call_id", "")), "go_for_the_finish", style)
