extends GutTest
## Clinch knees and the collar tie (docs/01 §27, D129): the tie breaks the opponent's posture for a
## few seconds in the clinch, knees go to the head harder while it's on, getting out is harder, and
## the AI and the Muay Thai fighter use it.

const SEED: int = 20261028
const SEEDS: int = 40
## Stats that win (or lose) every contest the tie and the knee have.
const BEST := { "clinch_control": 100, "strength": 100, "clinch_striking": 100, "power": 50 }
const WORST := { "clinch_control": 0, "strength": 0, "striking_defense": 0, "footwork": 0 }

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, tied up in the clinch in the middle of the cage.
func _clinched(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, rules, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_true(sim.apply_transition(0, "clinch_entry"))
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)))


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


func _starts(sim: FightSim, fighter: int) -> Array[String]:
	var out: Array[String] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, fighter):
		if e.data.phase == "telegraph":
			out.append(e.data.action_id)
	return out


func _bonus_names(b: OddsBreakdown) -> Array[String]:
	var out: Array[String] = []
	for x: Dictionary in b.bonuses:
		out.append(x.name)
	return out


## Red ties Blue up (trying until it works), and the tie is on.
func _tied(red_stats: Dictionary = BEST, blue_stats: Dictionary = WORST, rules: Variant = 1) -> FightSim:
	var sim: FightSim = _clinched(red_stats, blue_stats, SEED, rules)
	for k in 10:
		_queue(sim, sim.now, 0, "collar_tie")
		_ticks(sim, 6)
		if sim.fighters[1].tied_up_ticks > 0:
			break
	assert_gt(sim.fighters[1].tied_up_ticks, 0, "the tie is on")
	return sim


# --- The tie -----------------------------------------------------------------------------------

func test_a_collar_tie_breaks_his_posture_for_four_seconds_and_the_fight_stays_in_the_clinch() -> void:
	var tied: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched({ "clinch_control": 60, "strength": 60 }, {}, SEED + n)
		_queue(sim, sim.now, 0, "collar_tie")
		_ticks(sim, 6)
		assert_eq(sim.situation.position, PositionLibrary.CLINCH, "a tie doesn't move the fight")
		var won: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
		if won.is_empty():
			assert_eq(sim.fighters[1].tied_up_ticks, 0)
			continue
		tied += 1
		assert_eq(won[0].data.result, "tied_up")
		assert_has(sim.active_flags(1), "POSTURE_BROKEN")
		assert_almost_eq(sim.fighters[1].tied_up_ticks, 40, 4, "about 4 s left")
		assert_eq(sim.fighters[0].collar_ties_tried, 1)
		assert_eq(sim.fighters[0].collar_ties_won, 1)
		_ticks(sim, 41)
		assert_does_not_have(sim.active_flags(1), "POSTURE_BROKEN", "it wears off")
	assert_between(tied, 15, 35, "55%: base 45% + 10 points of stats")


func test_knees_from_a_collar_tie_go_to_the_head_harder() -> void:
	var sim: FightSim = _tied()
	var b: OddsBreakdown = sim.odds_breakdown(0, "knee")
	assert_has(_bonus_names(b), "POSTURE_BROKEN", "+15% with his head pulled down")
	var expected: int = maxi(1, roundi(sim.strike_damage(sim.fighters[0], "knee") * 1.2))
	_queue(sim, sim.now, 0, "knee")
	_ticks(sim, 5)
	var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0].data.target, "head")
	assert_eq(landed[0].data.damage, expected, "× 1.2")
	assert_eq(sim.fighters[0].clinch_knees_landed, 1)
	assert_eq(sim.fighters[0].tied_knees_landed, 1)


func test_teen_rules_keep_knees_from_the_tie_on_the_body() -> void:
	var sim: FightSim = _tied(BEST, WORST, Ruleset.load_id("amateur_teen"))
	_queue(sim, sim.now, 0, "knee")
	_ticks(sim, 5)
	var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0].data.target, "body", "no knees to the head (docs/08)")


func test_with_his_head_tied_breaking_away_and_kneeing_back_are_harder() -> void:
	var sim: FightSim = _tied()
	for id: String in ["clinch_break", "knee", "collar_tie"]:
		assert_has(_bonus_names(sim.odds_breakdown(1, id)), "own POSTURE_BROKEN", id)
	assert_does_not_have(_bonus_names(sim.odds_breakdown(0, "clinch_break")), "own POSTURE_BROKEN", "the one holding it is free")


func test_winning_a_tie_of_your_own_frees_your_head() -> void:
	var sim: FightSim = _tied({ "clinch_control": 100, "strength": 100 }, { "clinch_control": 100, "strength": 100 })
	var freed: bool = false
	for k in 30:
		if sim.fighters[1].tied_up_ticks <= 0:
			break
		_queue(sim, sim.now, 1, "collar_tie")
		_ticks(sim, 6)
		if not _events(sim, FightEvent.GRAPPLE_WON, 1).is_empty():
			freed = true
			break
	assert_true(freed, "the tie works back sooner or later")
	assert_eq(sim.fighters[1].tied_up_ticks, 0, "his own head is free")
	assert_gt(sim.fighters[0].tied_up_ticks, 0, "and now the other one is tied")


func test_the_tie_comes_off_when_the_clinch_ends() -> void:
	var sim: FightSim = _tied()
	sim._break_apart(0)
	assert_eq(sim.fighters[1].tied_up_ticks, 0)


# --- The fighter AI ----------------------------------------------------------------------------

func test_holding_the_tie_the_ai_knees_and_never_ties_again() -> void:
	var knees: int = 0
	for n in 10:
		var holder := FighterState.new("Holder", { "clinch_striking": 75 }, ["knee", "collar_tie"], 0.015)
		var sim := FightSim.new(SEED + n, [holder, FighterState.new("Statue", {}, [], 0.0)], _actions, 1, 300)
		for k in 300:
			if sim.situation.is_standing():
				sim.apply_transition(0, "clinch_entry")
			sim.fighters[1].tied_up_ticks = 40  # Kept tied.
			sim.tick()
		var starts: Array[String] = _starts(sim, 0)
		assert_does_not_have(starts, "collar_tie", "the head is already tied")
		knees += starts.count("knee")
	assert_gt(knees, 20, "knees from the tie")


## The first thing the AI does in the clinch, over SEEDS fights.
func _first_moves(tied: bool) -> Dictionary:
	var counts := {}
	for n in SEEDS:
		var sim := FightSim.new(SEED + n, [FighterState.new("Red", {}, ["knee"], 0.015), FighterState.new("Statue", {}, [], 0.0)], _actions, 1, 300)
		sim.apply_transition(0, "clinch_entry")
		for k in 300:
			if tied:
				sim.fighters[0].tied_up_ticks = 40
			sim.tick()
			var starts: Array[String] = _starts(sim, 0)
			if not starts.is_empty():
				counts[starts[0]] = counts.get(starts[0], 0) + 1
				break
	return counts


func test_tied_up_the_ai_wants_out() -> void:
	var tied: Dictionary = _first_moves(true)
	var free: Dictionary = _first_moves(false)
	assert_gt(tied.get("clinch_break", 0), free.get("clinch_break", 0), "breaks more with his head tied: %s, free %s" % [tied, free])
	assert_lt(tied.get("knee", 0), free.get("knee", 0), "and knees less")


# --- The call and the fighter ---------------------------------------------------------------

func test_the_collar_tie_call_is_only_for_a_fighter_who_knows_it_and_only_in_the_clinch() -> void:
	var call: Dictionary = CallLibrary.shared().get_call("collar_tie")
	assert_eq(call.hotkey, CallLibrary.shared().get_call("clinch").hotkey, "shares Clinch!'s key: standing vs in the clinch")
	var red := FighterState.new("Red", {}, ["collar_tie"], 0.0)
	red.profile = { "personality": { "ego": -100 } }  # Humble: never ignores a call.
	var sim := FightSim.new(SEED, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_ne(FightHud.call_problem(sim, 0, call), "", "not standing")
	sim.apply_transition(0, "clinch_entry")
	assert_eq(FightHud.call_problem(sim, 0, call), "")
	assert_true(sim.submit(FightCommand.live_call(sim.now, 0, "collar_tie")))
	_ticks(sim, 30)
	assert_has(_starts(sim, 0), "collar_tie")
	var wrestler: FightSim = FightSim.new(SEED, FighterLibrary.load_dir().make_pair("wrestler", "kicker"), _actions)
	wrestler.apply_transition(0, "clinch_entry")
	assert_eq(FightHud.call_problem(wrestler, 0, call), "not learned")


func test_the_muay_thai_fighter_ties_up_and_knees_in_real_fights() -> void:
	var roster := FighterLibrary.load_dir()
	var ties: int = 0
	var knees: int = 0
	for n in 3:
		var sim := FightSim.new(SEED + n, roster.make_pair("muay_thai", "boxer"), _actions)
		sim.run_to_end()
		ties += sim.fighters[0].collar_ties_won
		knees += sim.fighters[0].tied_knees_landed
	assert_gt(ties, 0, "the Muay Thai fighter gets the tie")
	assert_gt(knees, 0, "and lands knees from it")


func test_nobody_who_fought_before_knows_the_collar_tie() -> void:
	var roster := FighterLibrary.load_dir()
	for id: String in ["kicker", "boxer", "wrestler", "judoka", "bjj"]:
		assert_does_not_have(roster.make(id).repertoire, "collar_tie", id)
