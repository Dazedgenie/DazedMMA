extends GutTest
## Corner: a corner that makes its own calls (docs/01 §22.7, issue #18, D12, D68): the
## harness's ideal and spam callers and the opponent's AI corner. What it watches for,
## when it calls, and that its calls go through the fighter's normal call pipeline.

const SEED: int = 20261025

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Red knows the takedowns and stands at mid range; Blue holds their ground until told (as in test_live_calls).
func _statues() -> FightSim:
	var red := FighterState.new("Red", {}, ["double_leg", "catch_kick_single"], 0.0)
	red.profile = { "personality": { "ego": -100 } }
	var sim := FightSim.new(SEED, [red, FighterState.new("Blue", {}, [], 0.0)], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func _pair(red: String, blue: String) -> FightSim:
	return FightSim.new(SEED, _roster.make_pair(red, blue), _actions, 1, 60)


func _heard(sim: FightSim, actor: int = 0) -> Array:
	var out: Array = []
	for e in sim.events:
		if e.type == FightEvent.CALL_HEARD and e.actor == actor:
			out.append([e.tick, e.data.call_id])
	return out


## What the corner shouts `ticks` after now, with a full voice.
func _due_after(corner: Corner, view: FightView, ticks: int) -> Array[String]:
	view.now += ticks
	return corner.due(view, LiveCalls.VOICE_MAX)


func test_a_corner_that_never_calls_leaves_the_fight_as_it_was() -> void:
	var plain: FightSim = _pair("wrestler", "kicker")
	plain.run_to_end()
	var quiet: FightSim = _pair("wrestler", "kicker")
	quiet.corners[0] = Corner.new(Corner.NONE, 1)
	quiet.run_to_end()
	assert_eq(JSON.stringify(quiet.events_as_dicts()), JSON.stringify(plain.events_as_dicts()))


func test_the_ideal_corner_calls_takedown_as_the_kick_starts_and_the_fighter_catches_it() -> void:
	# Blue's body kick: telegraph at tick 20, the leg up from 23 until the end of the recovery.
	var sim: FightSim = _statues()
	sim.corners[0] = Corner.new(Corner.IDEAL, 1)
	sim.submit(FightCommand.queue_action(20, 1, "body_kick"))
	for n in 40:
		sim.tick()
	assert_eq(_heard(sim), [[20 + Corner.IDEAL_REACTION, "takedown"]], "a coach's reaction time after the kick started")
	var started: Array = []
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.actor == 0 and e.data.phase == "windup":
			started.append(e.data.action_id)
	assert_eq(started, ["catch_kick_single"], "the call's 6 ticks later, with the leg still up")


func test_the_ideal_corner_primes_catch_the_kick_when_the_kickers_scouted_tell_fires() -> void:
	var sim: FightSim = _pair("wrestler", "kicker")
	var corner := Corner.new(Corner.IDEAL, 1)
	var view: FightView = sim.views[0]
	view.now = 10
	corner.on_event(view, FightEvent.new(10, 1, FightEvent.STRIKE_MISSED, 1, { "action_id": "jab", "chance": 0.4 }))
	assert_eq(corner.due(view, LiveCalls.VOICE_MAX), [] as Array[String], "not before the coach's reaction time")
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["catch_the_kick"] as Array[String], "the Kicker's jab got blocked: the body kick is coming")


func test_survive_when_rocked_and_pressure_when_the_opponent_is() -> void:
	var sim: FightSim = _pair("boxer", "boxer")
	var corner := Corner.new(Corner.IDEAL, 1)
	var view: FightView = sim.views[0]
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.ROCKED, 0, { "by": "hook" }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["survive"] as Array[String])
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.ROCKED, 1, { "by": "hook" }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["pressure"] as Array[String])


func test_a_corner_only_calls_what_its_fighter_can_act_on() -> void:
	# The Kicker knows no takedown and never learned the catch-kick.
	var sim: FightSim = _pair("kicker", "kicker")
	var corner := Corner.new(Corner.IDEAL, 1)
	var view: FightView = sim.views[0]
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "body_kick", "phase": "telegraph" }))
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.STRIKE_MISSED, 1, { "action_id": "jab", "chance": 0.4 }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), [] as Array[String])


func test_the_ideal_corner_waits_rather_than_call_on_a_spent_voice() -> void:
	var sim: FightSim = _pair("boxer", "boxer")
	var corner := Corner.new(Corner.IDEAL, 1)
	var view: FightView = sim.views[0]
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.ROCKED, 0, { "by": "hook" }))
	view.now = Corner.IDEAL_REACTION
	var survive: float = float(CallLibrary.shared().get_call("survive").voice_cost)
	assert_eq(corner.due(view, Corner.SAVE_VOICE + survive - 1.0), [] as Array[String], "it would leave the voice garbled")
	assert_eq(corner.due(view, LiveCalls.VOICE_MAX), [] as Array[String], "and the moment has gone")


func test_the_ai_corner_reacts_slower_and_misses_about_half_the_moments() -> void:
	var sim: FightSim = _pair("boxer", "boxer")
	var corner := Corner.new(Corner.AI, 7)
	var view: FightView = sim.views[0]
	assert_eq(corner.reaction, Corner.AI_REACTION)
	var called: int = 0
	for n in 200:
		corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.ROCKED, 1, { "by": "hook" }))
		called += _due_after(corner, view, Corner.AI_REACTION).size()
	assert_between(called, 70, 130, "AI_NOTICE 0.5 of 200 moments")


func test_the_spam_caller_shouts_a_random_call_every_one_and_a_half_seconds() -> void:
	var sim: FightSim = _pair("wrestler", "kicker")
	var corner := Corner.new(Corner.SPAM, 3)
	var view: FightView = sim.views[0]
	var ticks: Array[int] = []
	var ids: Dictionary = {}
	for n in 300:
		view.now = n
		for id in corner.due(view, 0.0):
			ticks.append(n)
			ids[id] = true
	assert_eq(ticks.size(), 300 / Corner.SPAM_EVERY - 1, "every 15 ticks after the bell, voice or not")
	assert_eq(ticks[0], Corner.SPAM_EVERY)
	assert_gt(ids.size(), 5, "all sorts of calls")


func test_a_fight_with_corners_replays_from_its_command_log_without_them() -> void:
	var sim: FightSim = _pair("wrestler", "kicker")
	sim.corners[0] = Corner.new(Corner.IDEAL, 1)
	sim.corners[1] = Corner.new(Corner.AI, 2)
	sim.run_to_end()
	assert_gt(_heard(sim, 0).size() + _heard(sim, 1).size(), 0, "the corners called")
	var again: FightSim = FightSim.replay(SEED, _roster.make_pair("wrestler", "kicker"), _actions, sim.command_log_as_dicts(), 1, 60)
	assert_eq(JSON.stringify(again.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))


func test_nothing_is_logged_after_the_fight_ends_even_a_call_answered_on_the_knockout_tick() -> void:
	# Seed 28 (when written): the Boxer's corner calls Pressure! and it's answered on the tick his hook ends the fight.
	var sim := FightSim.new(28, _roster.make_pair("wrestler", "boxer"), _actions, Ruleset.load_id("pro"), 300)
	sim.corners[1] = Corner.new(Corner.IDEAL, FightSummary.corner_seed(28, 1))
	sim.run_to_end()
	assert_eq(sim.events[-1].type, FightEvent.FIGHT_ENDED)
