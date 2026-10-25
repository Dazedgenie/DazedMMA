extends GutTest
## Drilled rules (docs/01 §6.0, §23, issue #17, D82): two slots of trigger → move, set
## before a round, firing with the fighter's own reaction time when eligible and
## reliable, slot 1 first, with a cooldown, opponents disguising a move the rule keeps
## catching, and every outcome in the log.

const SEED: int = 20261025
const KICK_AT: int = 20

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Red knows the takedowns and stands at mid range; Blue holds their ground until told (as in test_live_calls).
func _sim(red_moves: Array[String] = ["double_leg", "catch_kick_single"]) -> FightSim:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, red_moves, 0.0), FighterState.new("Blue", {}, [], 0.0)], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func _run(sim: FightSim, ticks: int) -> void:
	for n in ticks:
		sim.tick()


## Red's rule_answered events: [{rule_id, outcome, reason, slot, …}].
func _answers(sim: FightSim, fighter: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.RULE_ANSWERED and e.actor == fighter:
			out.append(e.data)
	return out


func _outcomes(sim: FightSim) -> Array:
	return _answers(sim).map(func(a: Dictionary) -> String: return a.outcome)


func _starts(sim: FightSim, actor: int = 0) -> Array:
	var out: Array = []
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.actor == actor:
			out.append([e.tick, e.data.action_id])
	return out


func _rules(sim: FightSim) -> DrilledRules:
	return sim.decisions[0].rules


func test_the_catch_rule_catches_the_kick_with_the_fighters_own_reaction_time() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 100))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 40)
	# As the read call: Red first sees the kick at 21, plus 2 ticks of reaction (Speed 50).
	assert_eq(_starts(sim), [[KICK_AT + 3, "catch_kick_single"]])
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers[0].outcome, DrilledRules.SET)
	assert_eq(answers[0].reason, "slot 1, drilled 100%")
	assert_eq(answers[1].outcome, DrilledRules.FIRED)
	assert_eq(answers[1].action_id, "catch_kick_single")
	assert_eq(answers[1].reason, "3 ticks after the body kick started")


func test_a_rule_never_drilled_never_fires_and_says_so() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 0))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 40)
	assert_eq(_starts(sim), [])
	assert_eq(_outcomes(sim), [DrilledRules.SET, DrilledRules.SLOW])
	assert_eq(_answers(sim)[1].reason, "didn't see it in time: 0% sharp")


func test_reliability_follows_the_drilling_fight_iq_and_how_worn_the_fighter_is() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 80))
	_run(sim, 1)
	var view: FightView = sim.views[0]
	var entry: Dictionary = _rules(sim).slots[0]
	assert_almost_eq(_rules(sim).reliability(view, entry), 0.8, 0.001, "Fight IQ 50, fresh")
	sim.fighters[0].stats["fight_iq"] = 100
	assert_almost_eq(_rules(sim).reliability(view, entry), 0.96, 0.001, "× 1.2 at Fight IQ 100")
	sim.fighters[0].stats["fight_iq"] = 50
	sim.fighters[0].damage.head = 100000  # Fully hurt.
	assert_lt(_rules(sim).reliability(view, entry), 0.8 * (1.0 - DrilledRules.RELIABILITY_PER_HEAD_HURT) + 0.001, "a hurt head (and the Fight IQ it costs)")


func test_a_rule_that_just_fired_sits_out_its_cooldown() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 100))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 40)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)  # Wherever the catch took them, back to mid range and standing.
	var fired: int = _answers(sim).filter(func(a: Dictionary) -> bool: return a.outcome == DrilledRules.FIRED).size()
	assert_eq(fired, 1)
	var cooled: bool = false
	_rules(sim).on_event(sim.views[0], FightEvent.new(sim.now, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "body_kick", "phase": "telegraph" }))
	for a: Dictionary in _rules(sim).take_notes():
		cooled = cooled or (a.data.outcome == DrilledRules.COOLING and a.data.reason.begins_with("fired"))
	assert_true(cooled, "a kick inside 15 s of the catch: the rule holds")
	sim.views[0].now = KICK_AT + 3 + 150
	_rules(sim).on_event(sim.views[0], FightEvent.new(sim.views[0].now, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "body_kick", "phase": "telegraph" }))
	assert_ne(_rules(sim).take_notes().map(func(a: Dictionary) -> String: return a.data.outcome), [DrilledRules.COOLING], "15 s on, it's ready again")


func test_slot_one_goes_first_when_two_rules_answer_the_same_moment() -> void:
	var sim: FightSim = _sim(["double_leg", "catch_kick_single", "jab"])
	var lib: RuleLibrary = RuleLibrary.load_dir()
	lib.add({ "id": "jab_the_kick", "name": "When he kicks → jab", "trigger": "opp_kick_starts", "action": "jab", "cooldown_ms": 15000 })
	_rules(sim).library = lib
	sim.submit(FightCommand.set_rule(0, 0, 1, "jab_the_kick", 100))
	sim.submit(FightCommand.set_rule(0, 0, 2, "catch_kick_and_shoot", 100))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 30)
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers[2].rule_id, "catch_kick_and_shoot")
	assert_eq(answers[2].outcome, DrilledRules.OUTRANKED)
	assert_eq(answers[2].reason, "the slot 1 rule goes first")
	assert_eq(answers[3].rule_id, "jab_the_kick")
	assert_eq(answers[3].outcome, DrilledRules.FIRED)
	assert_eq(_starts(sim)[0][1], "jab")


func test_a_rule_out_of_range_doesnt_fire_and_says_why() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(-0.5, 0.0)  # Pocket range: too close to catch a kick.
	sim.fighters[1].pos = Vector2(0.5, 0.0)
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 100))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 40)
	assert_eq(_outcomes(sim), [DrilledRules.SET, DrilledRules.NOT_ELIGIBLE])
	assert_eq(_answers(sim)[1].reason, "out of range")


func test_a_rocked_fighter_cant_use_a_rule() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 100))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, KICK_AT)
	sim.fighters[0].rocked_ticks = 100
	_run(sim, 20)
	assert_eq(_answers(sim)[-1].reason, "rocked")


func test_a_fighter_busy_until_the_kick_is_over_misses_it() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 100))
	sim.submit(FightCommand.queue_action(KICK_AT - 1, 0, "double_leg"))  # Red is mid-shot when the kick comes.
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 60)
	assert_has(_outcomes(sim), DrilledRules.MISSED)


func test_rules_are_set_before_a_round_with_a_move_the_fighter_knows() -> void:
	var sim: FightSim = _sim(["jab"])
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 80))
	sim.submit(FightCommand.set_rule(0, 0, 3, "sprawl_on_the_shot", 80))
	sim.submit(FightCommand.set_rule(0, 0, 1, "sprawl_on_the_shot", 80))
	sim.submit(FightCommand.set_rule(5, 0, 2, "sprawl_on_the_shot", 80))
	_run(sim, 10)
	var refused: Array = sim.events.filter(func(e: FightEvent) -> bool: return e.type == FightEvent.COMMAND_REJECTED) \
		.map(func(e: FightEvent) -> String: return e.data.reason)
	assert_eq(refused, ["hasn't learned the catch-kick single leg", "there are 2 rule slots", "rules are set before a round"])
	assert_eq(_rules(sim).slots[0].rule.id, "sprawl_on_the_shot", "the sprawl is a move everyone knows")


func test_the_opponent_disguises_a_move_a_rule_keeps_catching_more_with_a_high_fight_iq() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 100))
	_run(sim, 1)
	var view: FightView = sim.views[0]
	var entry: Dictionary = _rules(sim).slots[0]
	entry.fires = 3
	assert_almost_eq(_rules(sim).reliability(view, entry), 1.0 - 3 * DrilledRules.ADAPT_PER_FIRE * 0.5, 0.001, "Fight IQ 50: half the adaptation")
	sim.fighters[1].stats["fight_iq"] = 100
	assert_almost_eq(_rules(sim).reliability(view, entry), 0.7, 0.001)
	entry.fires = 20
	assert_almost_eq(_rules(sim).reliability(view, entry), 1.0 - DrilledRules.ADAPT_MAX, 0.001, "never more than half")


func test_a_rule_that_never_triggers_leaves_the_fight_as_it_was() -> void:
	# The Boxer never shoots, so the sprawl rule never wakes.
	var plain: FightSim = FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions, 1, 60)
	plain.run_to_end()
	var ruled: FightSim = FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions, 1, 60)
	ruled.submit(FightCommand.set_rule(0, 1, 1, "sprawl_on_the_shot", 100))
	ruled.run_to_end()
	var events: Array = ruled.events_as_dicts().filter(func(e: Dictionary) -> bool: return e.type != FightEvent.RULE_ANSWERED)
	assert_eq(JSON.stringify(events), JSON.stringify(plain.events_as_dicts()))


func test_a_fight_with_rules_replays_from_its_command_log() -> void:
	var sim: FightSim = FightSim.new(SEED, _roster.make_pair("wrestler", "kicker"), _actions, 1, 120)
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 80))
	sim.submit(FightCommand.set_rule(0, 1, 1, "sprawl_on_the_shot", 80))
	sim.run_to_end()
	assert_gt(_answers(sim, 0).size() + _answers(sim, 1).size(), 2, "the rules did something")
	var again: FightSim = FightSim.replay(SEED, _roster.make_pair("wrestler", "kicker"), _actions, sim.command_log_as_dicts(), 1, 120)
	assert_eq(JSON.stringify(again.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))
