extends GutTest
## LiveCalls: the corner's calls (docs/01 §6.1–6.4, §22, issue #16). Voice, delay in
## fight time, compliance, feasibility, and the three shapes of call: an attempt
## (Takedown!), a focus (Pressure!) and a read (Catch the kick!). Every outcome is a
## call_answered event with a reason.

const SEED: int = 20261025
const KICK_AT: int = 20

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Red and Blue at mid range (1.8 m). Neither starts anything unless told; Blue knows no
## moves, so holds their ground, and Red's feet hold mid range, where the double-leg reaches.
## Red is humble (Ego −100) so with neutral trust they never ignore a call, and the delay stays 6 ticks.
func _sim(red_moves: Array[String] = ["double_leg", "catch_kick_single"], blue_moves: Array[String] = []) -> FightSim:
	var red := FighterState.new("Red", {}, red_moves, 0.0)
	red.profile = { "personality": { "ego": -100 } }
	var sim := FightSim.new(SEED, [red, FighterState.new("Blue", {}, blue_moves, 0.0)], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func _run(sim: FightSim, ticks: int) -> void:
	for n in ticks:
		sim.tick()


func _answers(sim: FightSim, fighter: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.CALL_ANSWERED and e.actor == fighter:
			out.append(e.data)
	return out


func _heard(sim: FightSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.CALL_HEARD:
			out.append(e.data)
	return out


## [tick, action id] of each move a fighter started.
func _starts(sim: FightSim, actor: int = 0) -> Array:
	var out: Array = []
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.actor == actor:
			out.append([e.tick, e.data.action_id])
	return out


func _calls(sim: FightSim) -> LiveCalls:
	return sim.decisions[0].calls


# --- Voice, trust and delay -------------------------------------------------------

func test_every_call_in_the_catalogue_loads_with_its_hotkey() -> void:
	var library: CallLibrary = CallLibrary.shared()
	assert_eq(library.ids(), ["pressure", "circle_out", "work_the_range", "takedown", "clinch", "defend_the_shot",
		"get_up", "survive", "stay_safe", "catch_the_kick"] as Array[String])
	assert_eq(LiveCalls.shape(library.get_call("takedown")), LiveCalls.ATTEMPT)
	assert_eq(LiveCalls.shape(library.get_call("pressure")), LiveCalls.FOCUS)
	assert_eq(LiveCalls.shape(library.get_call("catch_the_kick")), LiveCalls.READ)


func test_a_call_costs_voice_and_the_voice_refills_in_fight_time() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	_run(sim, 1)
	assert_eq(_heard(sim)[0].voice, 80, "Pressure costs 20 of 100")
	assert_almost_eq(_calls(sim).voice(10), 88.0, 0.001, "8 a fight-second")
	assert_almost_eq(_calls(sim).voice(100), LiveCalls.VOICE_MAX, 0.001, "never over the top")


func test_a_call_on_a_spent_voice_is_garbled_slower_and_less_likely_to_be_followed() -> void:
	var sim: FightSim = _sim()
	for n in 4:
		sim.submit(FightCommand.live_call(0, 0, "survive"))  # 25 each: 100 → 0
	sim.submit(FightCommand.live_call(0, 0, "stay_safe"))
	_run(sim, 1)
	var heard: Array[Dictionary] = _heard(sim)
	assert_false(heard[2].garbled, "50 left before the third call")
	assert_true(heard[3].garbled, "25 left before the fourth: under 30")
	assert_true(heard[4].garbled)
	assert_eq(heard[4].delay, roundi(LiveCalls.BASE_DELAY_TICKS * LiveCalls.GARBLED_DELAY))
	var view: FightView = sim.views[0]
	sim.fighters[0].profile = {}
	_calls(sim).trust = LiveCalls.TRUST_START
	assert_almost_eq(_calls(sim).ignore_odds(view, true).chance - _calls(sim).ignore_odds(view, false).chance,
		LiveCalls.IGNORE_GARBLED, 0.001)


func test_the_same_call_again_within_three_seconds_is_spam_and_costs_trust() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	sim.submit(FightCommand.live_call(LiveCalls.SPAM_TICKS, 0, "pressure"))
	sim.submit(FightCommand.live_call(LiveCalls.SPAM_TICKS * 2 + 1, 0, "pressure"))
	_run(sim, LiveCalls.SPAM_TICKS * 2 + 2)
	var heard: Array[Dictionary] = _heard(sim)
	assert_eq(heard.map(func(h: Dictionary) -> bool: return h.spam), [false, true, false])
	assert_eq(_calls(sim).trust, LiveCalls.TRUST_START - LiveCalls.SPAM_TRUST_COST)


func test_the_call_delay_is_6_ticks_shorter_with_fight_iq_and_trust_and_longer_when_tired_or_hurt() -> void:
	var sim: FightSim = _sim()
	var calls: LiveCalls = _calls(sim)
	var view: FightView = sim.views[0]
	var f: FighterState = sim.fighters[0]
	assert_eq(calls.delay_ticks(view), 6, "Fight IQ 50, trust 50, fresh")
	f.stats["fight_iq"] = 100
	assert_eq(calls.delay_ticks(view), 5, "Fight IQ 100: 25% off (4.5 rounds to 5)")
	calls.trust = 100.0
	assert_eq(calls.delay_ticks(view), 4, "and full trust: another 20% off (3.6)")
	f.stats["fight_iq"] = 50
	calls.trust = LiveCalls.TRUST_START
	f.stamina = 0.0
	assert_eq(calls.delay_ticks(view), 8, "exhausted: +30% (7.8)")
	assert_eq(calls.delay_ticks(view, true), 12, "garbled on top: ×1.5 (11.7)")
	f.stamina = f.max_stamina()
	f.damage.head = 500  # Half hurt in the head (Chin 50): +15%, and Fight IQ down 15% with it.
	assert_eq(calls.delay_ticks(view), 7)


func test_ego_stubbornness_distrust_and_panic_make_a_fighter_ignore_calls_more() -> void:
	var sim: FightSim = _sim()
	var calls: LiveCalls = _calls(sim)
	var view: FightView = sim.views[0]
	var f: FighterState = sim.fighters[0]
	f.profile = { "personality": { "ego": 0, "coachable": 0 } }
	assert_almost_eq(calls.ignore_odds(view).chance, LiveCalls.IGNORE_BASE, 0.001, "rare for a neutral fighter (D5)")
	f.profile = { "personality": { "ego": 100, "coachable": -100 } }
	calls.trust = 0.0
	var odds: Dictionary = calls.ignore_odds(view)
	assert_almost_eq(odds.chance, LiveCalls.IGNORE_BASE + LiveCalls.IGNORE_PER_EGO + LiveCalls.IGNORE_PER_STUBBORN + LiveCalls.IGNORE_PER_DISTRUST, 0.001)
	f.damage.head = 1000
	assert_true(f.is_panicking())
	assert_true(calls.ignore_odds(view).parts.has("panicking"))


func test_an_ignored_call_says_why() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].profile = { "personality": { "ego": 100 } }
	_calls(sim).trust = 0.0
	sim.fighters[0].damage.head = 1000  # Panicking too: 3% + 10% + 10% + 25% = 48% to ignore.
	for n in 20:
		sim.submit(FightCommand.live_call(n * 40, 0, "stay_safe"))
	_run(sim, 20 * 40)
	var ignored: Array[Dictionary] = _answers(sim).filter(func(a: Dictionary) -> bool: return a.outcome == LiveCalls.IGNORED)
	assert_gt(ignored.size(), 3, "about half of them")
	assert_lt(ignored.size(), 17)
	assert_eq(ignored[0].reason, "panicking", "the biggest reason is the one given")


# --- Attempts: Takedown!, Clinch!, Get up! ---------------------------------------

func test_takedown_call_shoots_once_the_call_delay_is_up() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "takedown"))
	_run(sim, 10)
	assert_eq(_starts(sim), [[6, "double_leg"]], "no kick to catch, so the double-leg")
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers[0].outcome, LiveCalls.ACCEPTED)
	assert_eq(answers[0].action_id, "double_leg")
	assert_eq(answers[0].reason, "call after 6 ticks")


func test_takedown_called_into_the_kick_becomes_the_catch_kick_single() -> void:
	# Blue's body kick: telegraph from tick 20, wind-up (ONE_LEG up) from tick 23 to the end of recovery.
	var sim: FightSim = _sim()
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	sim.submit(FightCommand.live_call(KICK_AT - LiveCalls.BASE_DELAY_TICKS + 3, 0, "takedown"))
	_run(sim, 40)
	assert_eq(_starts(sim), [[KICK_AT + 3, "catch_kick_single"]], "the call lands with the leg up: catch it (docs/01 §5.1)")
	for e in sim.events:
		if e.type == FightEvent.GRAPPLE_STOPPED and e.actor == 0:
			assert_ne(e.data.reason, "nothing to catch")


func test_takedown_called_too_early_shoots_the_double_leg_into_the_kick() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	sim.submit(FightCommand.live_call(KICK_AT - LiveCalls.BASE_DELAY_TICKS, 0, "takedown"))
	_run(sim, 40)
	assert_eq(_starts(sim), [[KICK_AT, "double_leg"]], "the kick was only a telegraph when the call landed: timing matters")


func test_the_fighter_never_catches_a_kick_without_a_call() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].work_rate = 0.2
	for n in 10:
		sim.submit(FightCommand.queue_action(KICK_AT + n * 30, 1, "body_kick"))
	_run(sim, 400)
	for s: Array in _starts(sim):
		assert_ne(s[1], "catch_kick_single", "D103: only a call or a drilled rule throws it")


func test_takedown_call_steps_in_from_long_range_to_shoot() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(-1.75, 0.0)
	sim.fighters[1].pos = Vector2(1.75, 0.0)  # 3.5 m: out of range; the double-leg reaches from mid.
	sim.submit(FightCommand.live_call(0, 0, "takedown"))
	_run(sim, 30)
	var starts: Array = _starts(sim)
	assert_eq(starts.size(), 1)
	assert_eq(starts[0][1], "double_leg")
	assert_gt(starts[0][0], 6, "walked in first")
	assert_lt(starts[0][0], 6 + LiveCalls.ATTEMPT_TICKS)


func test_an_attempt_that_never_finds_its_range_is_infeasible_after_two_seconds() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].stats["footwork"] = 0
	sim.fighters[0].stats["speed"] = 0
	sim.fighters[0].pos = Vector2(-3.4, 0.0)
	sim.fighters[1].pos = Vector2(3.4, 0.0)
	sim.submit(FightCommand.live_call(0, 0, "takedown"))
	_run(sim, 6 + LiveCalls.ATTEMPT_TICKS + 1)
	assert_eq(_starts(sim), [])
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers.size(), 1)
	assert_eq(answers[0].outcome, LiveCalls.INFEASIBLE)
	assert_eq(answers[0].reason, "couldn't get in range")


func test_a_fighter_who_knows_no_takedown_cannot_take_the_takedown_call() -> void:
	var sim: FightSim = _sim(["jab"])
	sim.submit(FightCommand.live_call(0, 0, "takedown"))
	_run(sim, 10)
	assert_eq(_answers(sim)[0].outcome, LiveCalls.INFEASIBLE)
	assert_eq(_answers(sim)[0].reason, "doesn't know how")


func test_get_up_is_only_for_the_fighter_underneath() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "get_up"))
	_run(sim, 10)
	assert_eq(_answers(sim)[0].reason, "not possible from this position", "standing already")
	sim = _sim()
	sim.apply_transition(0, "double_leg")  # Red takes Blue down: Red on top.
	sim.submit(FightCommand.live_call(0, 0, "get_up"))
	sim.submit(FightCommand.live_call(0, 1, "get_up"))
	_run(sim, 10)
	assert_eq(_answers(sim, 0)[0].reason, "not possible from the top")
	assert_eq(_answers(sim, 1)[0].outcome, LiveCalls.ACCEPTED, "get up is basic: everyone knows it")
	assert_eq(_answers(sim, 1)[0].action_id, "get_up")


func test_a_newer_call_replaces_one_of_the_same_kind_still_being_processed() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	sim.submit(FightCommand.live_call(2, 0, "circle_out"))
	sim.submit(FightCommand.live_call(2, 0, "takedown"))
	_run(sim, 12)
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers[0].call_id, "pressure")
	assert_eq(answers[0].outcome, LiveCalls.REPLACED)
	var outcomes: Dictionary = {}
	for a in answers.slice(1):
		outcomes[a.call_id] = a.outcome
	assert_eq(outcomes, { "circle_out": LiveCalls.ACCEPTED, "takedown": LiveCalls.ACCEPTED }, "different kinds don't replace each other")


# --- Focus: Pressure!, Circle out!, Defend the shot! … -----------------------------

func test_a_focus_call_tilts_the_leanings_for_15_seconds_then_the_gameplan_is_back() -> void:
	var sim: FightSim = _sim()
	var layer: DecisionLayer = sim.decisions[0]
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	_run(sim, 7)
	assert_eq(layer.leaning(sim.views[0], StyleLeanings.PACE), 60.0)
	assert_eq(layer.leaning(sim.views[0], StyleLeanings.RANGE), 50.0)
	assert_eq(_answers(sim)[0].reason, "for 15 s")
	_run(sim, 150)
	assert_eq(layer.leaning(sim.views[0], StyleLeanings.PACE), 0.0)
	assert_eq(_answers(sim)[1].outcome, LiveCalls.EXPIRED)
	assert_eq(_answers(sim)[1].reason, "back to the gameplan")


func test_defend_the_shot_makes_shots_easier_to_read_and_sprawl_on() -> void:
	var sim: FightSim = _sim()
	var layer: DecisionLayer = sim.decisions[0]
	var view: FightView = sim.views[0]
	var shot: Dictionary = _actions.get_action("double_leg")
	var jab: Dictionary = _actions.get_action("jab")
	sim.submit(FightCommand.live_call(0, 0, "defend_the_shot"))
	_run(sim, 7)
	assert_almost_eq(layer.read_chance(view, shot, 0.4), 0.9, 0.001)
	assert_almost_eq(layer.read_chance(view, jab, 0.4), 0.4, 0.001, "only shots")
	assert_almost_eq(layer.sprawl_chance(view, 0.6), 0.9, 0.001)


func test_pressure_walks_the_fighter_forward_and_circle_out_takes_them_away() -> void:
	var gaps: Array[float] = []
	for call: String in ["", "pressure", "circle_out"]:
		var red := FighterState.new("Red", {}, ["jab", "cross"], 0.0)
		var blue := FighterState.new("Blue", {}, ["jab", "cross"], 0.0)
		var sim := FightSim.new(SEED, [red, blue], _actions)
		if call != "":
			sim.submit(FightCommand.live_call(0, 0, call))
		_run(sim, 120)
		gaps.append(sim.distance())
	assert_lt(gaps[1], gaps[0], "Pressure closes the distance")
	assert_gt(gaps[2], gaps[1], "Circle out keeps it")


# --- Reads: Catch the kick! ---------------------------------------------------------

func test_catch_the_kick_fires_on_the_kick_with_the_fighters_own_reaction_time() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "catch_the_kick"))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 40)
	# Blue steps after Red, so Red first sees the kick at 21, plus 2 ticks of reaction (Speed 50).
	assert_eq(_starts(sim), [[KICK_AT + 3, "catch_kick_single"]])
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers[0].outcome, LiveCalls.ACCEPTED)
	assert_eq(answers[0].reason, "watching for it for 6 s")
	assert_eq(answers[1].outcome, LiveCalls.FIRED)
	assert_eq(answers[1].action_id, "catch_kick_single")
	assert_string_contains(answers[1].reason, "read the body kick")


func test_a_quick_fighter_waits_for_the_leg_to_come_up_before_catching() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].stats["speed"] = 100  # Reacts in 1 tick, before the kick's wind-up.
	sim.submit(FightCommand.live_call(0, 0, "catch_the_kick"))
	sim.submit(FightCommand.queue_action(KICK_AT, 1, "body_kick"))
	_run(sim, 40)
	var starts: Array = _starts(sim)
	assert_eq(starts.size(), 1)
	assert_eq(starts[0][1], "catch_kick_single")
	for e in sim.events:
		if e.type == FightEvent.GRAPPLE_STOPPED and e.actor == 0:
			assert_ne(e.data.reason, "nothing to catch")


func test_catch_the_kick_needs_the_technique() -> void:
	var sim: FightSim = _sim(["double_leg"])
	sim.submit(FightCommand.live_call(0, 0, "catch_the_kick"))
	_run(sim, 10)
	assert_eq(_answers(sim)[0].outcome, LiveCalls.INFEASIBLE)
	assert_eq(_answers(sim)[0].reason, "hasn't learned the catch-kick single leg")


func test_a_primed_read_costs_defense_until_it_expires() -> void:
	var sim: FightSim = _sim()
	var f: FighterState = sim.fighters[0]
	sim.submit(FightCommand.live_call(0, 0, "catch_the_kick"))
	_run(sim, 7)
	assert_almost_eq(f.effective_stat("striking_defense"), 50.0 * 0.85, 0.001, "watching for kicks: −15% defense")
	assert_eq(f.effective_stat("boxing"), 50.0, "only defense")
	_run(sim, 60)
	assert_eq(f.effective_stat("striking_defense"), 50.0)
	var last: Dictionary = _answers(sim)[-1]
	assert_eq(last.outcome, LiveCalls.EXPIRED)
	assert_eq(last.reason, "nothing came in 6 s")


func test_no_more_than_two_reads_are_primed_at_once() -> void:
	var sim: FightSim = _sim()
	sim.calls = CallLibrary.load_dir()
	for id: String in ["watch_one", "watch_two"]:
		var extra: Dictionary = sim.calls.get_call("catch_the_kick").duplicate(true)
		extra.id = id
		extra.requires_technique = null
		sim.calls.add(extra)
	sim.submit(FightCommand.live_call(0, 0, "catch_the_kick"))
	sim.submit(FightCommand.live_call(1, 0, "watch_one"))
	sim.submit(FightCommand.live_call(2, 0, "watch_two"))
	_run(sim, 10)
	assert_eq(_calls(sim).reads.size(), LiveCalls.MAX_READS)
	assert_almost_eq(sim.fighters[0].attention, 0.3, 0.001, "two reads: twice the attention cost (D67)")
	var replaced: Array[Dictionary] = _answers(sim).filter(func(a: Dictionary) -> bool: return a.outcome == LiveCalls.REPLACED)
	assert_eq(replaced.size(), 1)
	assert_eq(replaced[0].call_id, "catch_the_kick", "the oldest goes")


# --- The fight log and replays ----------------------------------------------------------

func test_a_fight_with_no_calls_never_wakes_the_call_pipeline() -> void:
	var sim: FightSim = _sim()
	_run(sim, 50)
	assert_false(_calls(sim).active)
	assert_eq(_heard(sim), [])


func test_fights_with_every_kind_of_call_replay_exactly() -> void:
	var pair := func() -> Array[FighterState]:
		var roster := FighterLibrary.load_dir()
		return roster.make_pair("wrestler", "kicker")
	var sim := FightSim.new(SEED, pair.call(), _actions)
	var at: int = 50
	for id: String in ["catch_the_kick", "pressure", "takedown", "defend_the_shot", "get_up", "survive", "clinch", "stay_safe"]:
		sim.submit(FightCommand.live_call(at, 0, id))
		sim.submit(FightCommand.live_call(at + 5, 1, id))
		at += 80
	sim.run_to_end()
	assert_gt(_answers(sim).size(), 10)
	var again: FightSim = FightSim.replay(SEED, pair.call(), _actions, sim.command_log_as_dicts())
	assert_eq(JSON.stringify(again.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))
