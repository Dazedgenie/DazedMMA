extends GutTest
## Combinations (D133, docs/01 §31): a drilled run of strikes that flows, the bonus for
## changing levels, a combination the opponent has seen before, what breaks one, and the
## fighter AI throwing the ones in its profile.

const SEED: int = 20261029
const SEEDS: int = 40

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart in the middle of the cage.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.8, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	return sim


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


## Fighter i's moves as they started, in order: their telegraph events.
func _starts(sim: FightSim, i: int) -> Array[FightEvent]:
	return _events(sim, FightEvent.ACTION_PHASE, i).filter(func(e: FightEvent) -> bool: return e.data.phase == "telegraph")


func _moves(sim: FightSim, i: int) -> Array[String]:
	var out: Array[String] = []
	for e in _starts(sim, i):
		out.append(e.data.action_id)
	return out


## The rolled strike event (landed or missed on its odds) of fighter i's move started at `tick`.
func _rolled(sim: FightSim, i: int, id: String, after_tick: int) -> FightEvent:
	for e in sim.events:
		if (e.type == FightEvent.STRIKE_LANDED or e.type == FightEvent.STRIKE_MISSED) and e.actor == i \
				and e.data.action_id == id and e.tick >= after_tick and e.data.has("odds"):
			return e
	return null


func _bonus(odds: Dictionary, bonus_name: String) -> float:
	for b: Dictionary in odds.bonuses:
		if b.name == bonus_name:
			return float(b.value)
	return 0.0


func _has_bonus(odds: Dictionary, bonus_name: String) -> bool:
	for b: Dictionary in odds.bonuses:
		if b.name == bonus_name:
			return true
	return false


# --- A combination as a whole --------------------------------------------------

func test_a_combination_is_thrown_move_after_move_with_no_gap() -> void:
	var sim: FightSim = _pair()
	assert_true(sim.submit(FightCommand.queue_combo(0, 0, "one_two")))
	_ticks(sim, 20)
	assert_eq(_moves(sim, 0), ["jab", "cross"] as Array[String], "the 1-2, and nothing after it")
	var jab_ended: FightEvent = _events(sim, FightEvent.ACTION_ENDED, 0)[0]
	var cross: FightEvent = _starts(sim, 0)[1]
	assert_eq(cross.tick, jab_ended.tick, "the cross starts the tick the jab is over")
	assert_eq(cross.data.combo, "one_two")
	assert_eq(int(cross.data.step), 1, "the second move of it")
	assert_eq(sim.fighters[0].combos_thrown, 1, "counted once, as its second move starts")
	assert_eq(sim.fighters[0].combo_strikes, 1, "one strike after the first")


func test_each_move_after_the_first_flows_out_of_the_last_with_a_shorter_telegraph() -> void:
	var alone: FightSim = _pair()
	assert_true(alone.submit(FightCommand.queue_action(0, 0, "cross")))
	_ticks(alone, 10)
	var combo: FightSim = _pair()
	assert_true(combo.submit(FightCommand.queue_combo(0, 0, "one_two")))
	_ticks(combo, 20)
	var thrown_alone: int = _events(alone, FightEvent.ACTION_PHASE, 0)[1].tick - _starts(alone, 0)[0].tick
	var cross_start: FightEvent = _starts(combo, 0)[1]
	var windup: FightEvent = _events(combo, FightEvent.ACTION_PHASE, 0).filter(func(e: FightEvent) -> bool:
		return e.data.action_id == "cross" and e.data.phase == "windup")[0]
	assert_eq(thrown_alone, 2, "a cross on its own telegraphs 0.2 s (data/actions/cross.json)")
	assert_eq(windup.tick - cross_start.tick, thrown_alone - FightSim.COMBO_FLOW_TICKS, "in the 1-2 it's 0.1 s: harder to read")


func test_changing_levels_is_easier_to_land_and_staying_up_top_is_not() -> void:
	var low: FightSim = _pair()
	assert_true(low.submit(FightCommand.queue_combo(0, 0, "jab_leg_kick")))
	_ticks(low, 20)
	var kick: FightEvent = _rolled(low, 0, "leg_kick", 0)
	assert_not_null(kick, "the low kick after the jab was rolled")
	assert_almost_eq(_bonus(kick.data.odds, "changes levels"), FightSim.LEVEL_CHANGE, 0.001, "head, then the legs: his eyes are up")
	var high: FightSim = _pair()
	assert_true(high.submit(FightCommand.queue_combo(0, 0, "one_two")))
	_ticks(high, 20)
	var cross: FightEvent = _rolled(high, 0, "cross", 0)
	assert_false(_has_bonus(cross.data.odds, "changes levels"), "jab and cross both go to the head")
	var jab: FightEvent = _rolled(high, 0, "jab", 0)
	assert_eq(jab.data.odds.bonuses.size(), 0, "the first move of a combination is a plain strike")


func test_a_combination_he_has_seen_before_lands_less_up_to_three_times() -> void:
	var sim: FightSim = _pair()
	var expected: Array[float] = [0.0, -0.05, -0.10, -0.15, -0.15]
	for n in expected.size():
		assert_true(sim.submit(FightCommand.queue_combo(n * 20, 0, "one_two")))
	_ticks(sim, expected.size() * 20)
	var crosses: Array[FightEvent] = []
	for e in sim.events:
		if (e.type == FightEvent.STRIKE_LANDED or e.type == FightEvent.STRIKE_MISSED) and e.actor == 0 and e.data.action_id == "cross":
			crosses.append(e)
	assert_eq(crosses.size(), expected.size(), "five 1-2s")
	for n in expected.size():
		assert_almost_eq(_bonus(crosses[n].data.odds, "seen it"), expected[n], 0.001, "1-2 number %d" % (n + 1))
	assert_eq(sim.fighters[0].combos_thrown, 5)


func test_the_defender_knows_how_often_he_has_seen_it_while_it_comes() -> void:
	var sim: FightSim = _pair()
	assert_true(sim.submit(FightCommand.queue_combo(0, 0, "one_two")))
	assert_true(sim.submit(FightCommand.queue_combo(20, 0, "one_two")))
	var seen: Array[int] = []
	for k in 40:
		sim.tick()
		if sim.fighters[0].action_id == "cross":
			seen.append(sim.views[1].combo_seen_before())
	assert_eq(seen.front(), 0, "the first 1-2 is new to him")
	assert_eq(seen.back(), 1, "the second time he's seen it once before: he reads it better (FighterAI.COMBO_SEEN_READ)")
	assert_eq(sim.views[0].combo_seen_before(), 0, "nobody is in a combination now")


func test_a_combination_stops_when_its_next_move_will_not_reach() -> void:
	var sim: FightSim = _pair({}, {}, 1.8)
	assert_true(sim.submit(FightCommand.queue_combo(0, 0, "one_two_three")))
	_ticks(sim, 30)
	assert_eq(_moves(sim, 0), ["jab", "cross"] as Array[String], "from mid range the hook (pocket only) doesn't reach: it stops after the 1-2")
	var close: FightSim = _pair({}, {}, 1.2)
	assert_true(close.submit(FightCommand.queue_combo(0, 0, "one_two_three")))
	_ticks(close, 30)
	assert_eq(_moves(close, 0), ["jab", "cross", "hook"] as Array[String], "in the pocket it's the whole 1-2-3")


func test_a_clean_shot_in_the_middle_of_a_combination_breaks_it() -> void:
	var broken: int = 0
	var went_on: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({}, {}, 1.2, SEED + n)
		assert_true(sim.submit(FightCommand.queue_combo(0, 0, "one_two")))
		assert_true(sim.submit(FightCommand.queue_action(0, 1, "jab")))
		_ticks(sim, 20)
		var hit: bool = not _events(sim, FightEvent.STRIKE_LANDED, 1).is_empty()
		if hit:
			broken += 1
			assert_eq(_moves(sim, 0), ["jab"] as Array[String], "seed %d: hit while throwing the jab, he never throws the cross" % (SEED + n))
		else:
			went_on += 1
			assert_eq(_moves(sim, 0), ["jab", "cross"] as Array[String], "seed %d: not hit, the 1-2 goes on" % (SEED + n))
	assert_gt(broken, 0, "Blue's jab landed in some fights")
	assert_gt(went_on, 0, "and missed in others")


func test_a_move_that_is_not_the_next_one_is_no_part_of_the_combination() -> void:
	var sim: FightSim = _pair()
	assert_true(sim.submit(FightCommand.new(0, 0, FightCommand.QUEUE_ACTION, { "action_id": "hook", "combo": "one_two" })))
	_ticks(sim, 1)
	assert_eq(sim.fighters[0].action_id, "hook")
	assert_eq(sim.fighters[0].combo_id, "", "the 1-2 starts with a jab: this is a plain hook")


# --- The fighter AI --------------------------------------------------------------

func test_strikers_throw_the_combinations_in_their_profile_and_nothing_else() -> void:
	for pair: Array in [["boxer", "kicker"], ["muay_thai", "boxer"]]:
		for n in 3:
			var sim := FightSim.new(SEED + n, _roster.make_pair(pair[0], pair[1]), _actions)
			sim.run_to_end()
			for i in 2:
				var f: FighterState = sim.fighters[i]
				var last: String = ""
				for e in _starts(sim, i):
					var combo: String = String(e.data.get("combo", ""))
					if combo != "":
						assert_has(f.combos, combo, "%s only throws his own combinations" % f.name)
						assert_eq(e.data.action_id, sim.combos.move(combo, int(e.data.step)), "%s: the %s's move %d" % [f.name, combo, int(e.data.step)])
						assert_eq(last, sim.combos.move(combo, int(e.data.step) - 1), "%s: straight after the move before it" % f.name)
					last = e.data.action_id
			assert_gt(sim.fighters[0].combos_thrown, 0, "%s throws combinations (seed %d)" % [sim.fighters[0].name, SEED + n])


func test_the_boxer_mixes_his_combinations_up() -> void:
	var counts: Dictionary = {}
	for n in 5:
		var sim := FightSim.new(SEED + n, _roster.make_pair("boxer", "kicker"), _actions)
		sim.run_to_end()
		for e in _starts(sim, 0):
			if int(e.data.get("step", 0)) == 1:
				counts[e.data.combo] = int(counts.get(e.data.combo, 0)) + 1
	assert_gte(counts.size(), 3, "at least three of his four combinations get thrown: %s" % counts)


func test_fighters_with_no_combinations_never_throw_one() -> void:
	for n in 3:
		var sim := FightSim.new(SEED + n, _roster.make_pair("wrestler", "judoka"), _actions)
		sim.run_to_end()
		for i in 2:
			assert_eq(sim.fighters[i].combos_thrown, 0, "%s has no combinations in his profile" % sim.fighters[i].name)
			for e in _starts(sim, i):
				assert_false(e.data.has("combo"), "no move of theirs is part of one")
