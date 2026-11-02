extends GutTest
## Strikes from the bottom (docs/01 §44, D271): elbows and short punches from the guard and half guard,
## the man on top sitting up away from them (POSTURED_UP: the sweep, the get-up and the armbar open),
## held down by the collar tie he eats them instead, amateur rules, *Ground and pound!* from underneath,
## and the fighter AI throwing them by style.

const SEED: int = 20261102
## Enough seeds for a share to show.
const SEEDS: int = 40

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## A fighter who does nothing unless told.
func _statue(fighter_name: String, stats: Dictionary) -> FighterState:
	return FighterState.new(fighter_name, stats, [], 0.0)


## Red on top of Blue in `where` (no rolls), two statues.
func _red_on_top(where: String = "full_guard", red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [_statue("Red", red_stats), _statue("Blue", blue_stats)], _actions, rules, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_true(sim.apply_transition(0, "double_leg"))
	if where == "half_guard":
		assert_true(sim.apply_transition(0, "guard_pass", PositionLibrary.PARTIAL))
	elif where == "side_control":
		assert_true(sim.apply_transition(0, "guard_pass"))
	elif where == "mount":
		assert_true(sim.apply_transition(0, "guard_pass"))
		assert_true(sim.apply_transition(0, "take_mount"))
	assert_eq(sim.situation.position, where)
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)), "%s queued" % action_id)


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


func _bonus_names(b: OddsBreakdown) -> Array[String]:
	var out: Array[String] = []
	for x: Dictionary in b.bonuses:
		out.append(x.name)
	return out


## Throws `id` from the bottom until one lands (a fresh fight each seed); the fight it landed in, or null.
func _landed_from_bottom(id: String, where: String = "full_guard", collar: bool = false, from: int = 0) -> FightSim:
	for n in range(from, from + SEEDS):
		var sim: FightSim = _red_on_top(where, { "top_control": 0 }, { "guard": 100, "clinch_striking": 100, "boxing": 100 }, SEED + n)
		if collar:
			sim.set_ground_grips(0, true)
		_queue(sim, sim.now, 1, id)
		_ticks(sim, 5)
		if not _events(sim, FightEvent.STRIKE_LANDED, 1).is_empty():
			return sim
	return null


# --- Who throws what, from where --------------------------------------------------------

func test_everyone_underneath_in_the_guard_and_half_guard_has_the_elbow_and_the_punch_and_nobody_on_top_does() -> void:
	for where: String in ["full_guard", "half_guard"]:
		var sim: FightSim = _red_on_top(where)
		for id: String in ["bottom_elbow", "bottom_punch"]:
			assert_eq(sim.why_not(1, id), "", "%s from the bottom of %s" % [id, where])
			assert_eq(sim.why_not(0, id), "not possible from the top", "%s from the top of %s" % [id, where])


func test_not_from_under_side_control_or_mount() -> void:
	for where: String in ["side_control", "mount"]:
		var sim: FightSim = _red_on_top(where)
		for id: String in ["bottom_elbow", "bottom_punch"]:
			assert_eq(sim.why_not(1, id), "not possible from this position", "%s under %s" % [id, where])


func test_an_elbow_from_the_bottom_lands_to_the_head_and_hits_harder_than_the_punch() -> void:
	var elbow: FightSim = _landed_from_bottom("bottom_elbow")
	var punch: FightSim = _landed_from_bottom("bottom_punch")
	assert_not_null(elbow, "an elbow lands")
	assert_not_null(punch, "a punch lands")
	var e: FightEvent = _events(elbow, FightEvent.STRIKE_LANDED, 1)[0]
	var p: FightEvent = _events(punch, FightEvent.STRIKE_LANDED, 1)[0]
	assert_eq(e.data.target, "head")
	assert_gt(int(e.data.damage), int(p.data.damage), "the elbow cuts deeper")
	assert_eq(elbow.fighters[1].bottom_strikes_landed, 1)


func test_landing_from_the_bottom_answers_the_shots_so_the_referee_waits() -> void:
	var sim: FightSim = _red_on_top("full_guard", { "top_control": 0 }, { "guard": 100, "clinch_striking": 100 })
	sim.fighters[1].unanswered = 3
	for n in 6:
		_queue(sim, sim.now, 1, "bottom_elbow")
		_ticks(sim, 7)
		if not _events(sim, FightEvent.STRIKE_LANDED, 1).is_empty():
			break
	assert_false(_events(sim, FightEvent.STRIKE_LANDED, 1).is_empty(), "one lands")
	assert_eq(sim.fighters[1].unanswered, 0, "he's fighting back")


# --- What they open -------------------------------------------------------------------

func test_a_clean_one_makes_him_sit_up_away_which_opens_the_sweep_the_get_up_and_the_armbar() -> void:
	var sim: FightSim = _landed_from_bottom("bottom_elbow")
	assert_not_null(sim)
	var hit: FightEvent = _events(sim, FightEvent.STRIKE_LANDED, 1)[0]
	assert_true(hit.data.get("backs_off", false), "he sits up away from it")
	assert_string_contains(FightLogFormatter.describe(hit, sim), "sits up away from it")
	assert_has(sim.active_flags(0), "POSTURED_UP")
	assert_eq(sim.fighters[0].backed_off, 1)
	for id: String in ["sweep", "get_up", "armbar"]:
		assert_has(_bonus_names(sim.odds_breakdown(1, id)), "POSTURED_UP", "%s is open" % id)
	assert_has(_bonus_names(sim.odds_breakdown(1, "bottom_elbow")), "POSTURED_UP", "and he's out of elbow range")
	_ticks(sim, 21)
	assert_false(sim.active_flags(0).has("POSTURED_UP"), "only for a moment (the elbow's 2 s)")


func test_held_down_by_the_collar_tie_he_cant_sit_up_and_the_elbows_come_easier() -> void:
	var open: FightSim = _red_on_top()
	var tied: FightSim = _red_on_top()
	tied.set_ground_grips(0, true)
	assert_has(_bonus_names(tied.odds_breakdown(1, "bottom_elbow")), "POSTURE_BROKEN")
	assert_gt(tied.odds_breakdown(1, "bottom_elbow").chance, open.odds_breakdown(1, "bottom_elbow").chance)
	var sim: FightSim = _landed_from_bottom("bottom_elbow", "full_guard", true)
	assert_not_null(sim)
	assert_false(_events(sim, FightEvent.STRIKE_LANDED, 1)[0].data.get("backs_off", false), "held down, he eats it")
	assert_false(sim.active_flags(0).has("POSTURED_UP"))


func test_sitting_up_away_ends_with_the_position() -> void:
	var sim: FightSim = _landed_from_bottom("bottom_punch")
	assert_not_null(sim)
	assert_gt(sim.fighters[0].backed_off_ticks, 0)
	assert_true(sim.apply_transition(0, "guard_pass"))
	assert_eq(sim.fighters[0].backed_off_ticks, 0)


func test_a_sweep_off_him_sitting_up_is_counted() -> void:
	var used: int = 0
	for n in SEEDS:
		var sim: FightSim = _landed_from_bottom("bottom_elbow", "full_guard", false, n * SEEDS)
		if sim == null:
			continue
		for k in 5:
			if sim.fighters[1].is_free():
				break
			_ticks(sim, 1)
		if sim.fighters[1].is_free() and sim.fighters[0].backed_off_ticks > 0 and sim.why_not(1, "sweep") == "":
			_queue(sim, sim.now, 1, "sweep")
			_ticks(sim, 12)
		used += sim.fighters[1].backed_off_used
		if used > 0:
			break
	assert_gt(used, 0, "a sweep that works while he sits up counts as using it")


# --- Rules ------------------------------------------------------------------------------

func test_under_amateur_rules_no_elbows_and_the_punches_go_to_the_body() -> void:
	var sim: FightSim = _red_on_top("full_guard", { "top_control": 0 }, { "guard": 100, "boxing": 100 }, SEED, Ruleset.load_id("amateur_adult"))
	assert_ne(sim.why_not(1, "bottom_elbow"), "", "elbows are banned")
	for n in 6:
		_queue(sim, sim.now, 1, "bottom_punch")
		_ticks(sim, 5)
	var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 1)
	assert_false(landed.is_empty())
	for e: FightEvent in landed:
		assert_eq(e.data.target, "body")
		assert_false(e.data.get("backs_off", false), "a body punch doesn't make him sit up")


# --- The call and the AI -------------------------------------------------------------------

func test_ground_and_pound_is_heard_underneath_in_the_guard_but_not_under_mount() -> void:
	var call: Dictionary = CallLibrary.load_dir().get_call("ground_and_pound")
	var guard: FightSim = _red_on_top()
	var layer := DecisionLayer.new(FighterAI.new())
	assert_eq(layer.calls._infeasible(FightView.new(guard, 1), call), "", "from his back in the guard")
	var mount: FightSim = _red_on_top("mount")
	assert_ne(layer.calls._infeasible(FightView.new(mount, 1), call), "", "nothing to throw from under mount")
	assert_eq(layer.calls._infeasible(FightView.new(mount, 0), call), "", "on top it's as it was")


func test_the_call_makes_him_strike_more_from_his_back() -> void:
	var layer := DecisionLayer.new(FighterAI.new())
	assert_eq(layer.calls.bottom_strike_focus(), 1.0)
	layer.calls.focus = { "call": CallLibrary.load_dir().get_call("ground_and_pound"), "since": 0, "until": 1000, "scale": 1.0 }
	assert_gt(layer.calls.bottom_strike_focus(), 1.0)


## How many of `n` moves the fighter AI picks from his back in the guard (fighter `who` underneath) are strikes.
func _bottom_strike_share(who: String, n: int, called: bool = false) -> float:
	var sim := FightSim.new(SEED, FighterLibrary.load_dir().make_pair("wrestler", who), _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_true(sim.apply_transition(0, "double_leg"))
	var layer := DecisionLayer.new(FighterAI.new())
	if called:
		layer.calls.focus = { "call": CallLibrary.load_dir().get_call("ground_and_pound"), "since": 0, "until": 1000000, "scale": 1.0 }
	var view := FightView.new(sim, 1)
	var strikes: int = 0
	var moves: int = 0
	for k in n * 4:
		var d: Decision = layer.decide(view)
		if d == null or d.action_id == "":
			continue
		moves += 1
		if String(d.action_id).begins_with("bottom_"):
			strikes += 1
		if moves >= n:
			break
	return float(strikes) / maxf(1.0, float(moves))


func test_strikers_throw_more_from_their_backs_than_wrestlers_and_the_call_makes_it_more() -> void:
	var boxer: float = _bottom_strike_share("boxer", 400)
	var wrestler: float = _bottom_strike_share("wrestler", 400)
	assert_gt(boxer, wrestler, "the Boxer hits up more than the Wrestler (%.2f vs %.2f of his moves)" % [boxer, wrestler])
	assert_gt(wrestler, 0.0, "but the Wrestler throws some")
	var called: float = _bottom_strike_share("wrestler", 400, true)
	assert_gt(called, wrestler * 1.5, "on Ground and pound! from underneath (%.2f vs %.2f)" % [called, wrestler])
