extends GutTest
## Corner: a corner that makes its own calls (docs/01 §22.7, issue #18, D12, D68): the
## harness's ideal and spam callers and the opponent's AI corner. What it watches for,
## when it calls, and that its calls go through the fighter's normal call pipeline. Since D257
## it has a moment for every call (§22.10) and a key-masher bot.

const SEED: int = 20261025

var _actions: ActionLibrary
var _roster: FighterLibrary


## The ideal corner without the D257/D259 moments: Red is a grappler against a man who doesn't shoot, so the
## plain corner would also have him pressing (close_in_fresh) while these tests watch the reads.
const OLD_CALLS := "ideal:"


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
	sim.corners[0] = Corner.new(OLD_CALLS, 1)
	sim.submit(FightCommand.queue_action(20, 1, "body_kick"))
	for n in 40:
		sim.tick()
	assert_eq(_heard(sim)[0], [20 + Corner.IDEAL_REACTION, "takedown"], "a coach's reaction time after the kick started")
	assert_eq(_heard(sim).size(), 2)
	assert_eq(_heard(sim)[1][1], "ground_and_pound", "and once the catch puts Red on top: Ground and pound! (D121)")
	var started: Array = []
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.actor == 0 and e.data.phase == "windup":
			started.append(e.data.action_id)
	assert_eq(started, ["catch_kick_single"], "the call's 6 ticks later, with the leg still up")


func test_the_ideal_corner_primes_catch_the_kick_when_the_kickers_scouted_tell_fires() -> void:
	var sim: FightSim = _pair("wrestler", "kicker")
	var corner := Corner.new(OLD_CALLS, 1)
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


func test_on_top_the_corner_calls_ground_and_pound() -> void:
	var sim: FightSim = _pair("wrestler", "boxer")
	var corner := Corner.new(Corner.IDEAL, 1)
	var view: FightView = sim.views[0]
	sim.apply_transition(0, "double_leg")
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.POSITION_CHANGED, 0, { "action_id": "double_leg", "roles": ["top", "bottom"] }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["ground_and_pound"] as Array[String], "the Wrestler landed on top")
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.ROCKED, 1, { "by": 0 }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["ground_and_pound"] as Array[String], "the opponent rocked underneath: not Pressure!, which is for standing")
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.POSITION_CHANGED, 1, { "action_id": "get_up", "roles": ["neutral", "neutral"] }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), [] as Array[String], "nothing when they get back up")


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


## A moment as an event, seen by fighter 0's ideal corner; what it calls a reaction time later.
func _calls_on(sim: FightSim, event: FightEvent, style: String = Corner.IDEAL) -> Array[String]:
	var corner := Corner.new(style, 1)
	var view: FightView = sim.views[0]
	view.now = event.tick
	corner.on_event(view, event)
	return _due_after(corner, view, Corner.IDEAL_REACTION)


func test_defend_the_shot_when_a_grappler_shoots_and_not_again_while_it_is_on() -> void:
	# One of the moments left out of a plain corner (it cost wins, §22.10): asked for by name.
	var sim: FightSim = _pair("kicker", "wrestler")
	var corner := Corner.new("ideal:defend_the_shot", 1)
	var view: FightView = sim.views[0]
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "double_leg", "phase": "telegraph" }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["defend_the_shot"] as Array[String])
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "double_leg", "phase": "telegraph" }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), [] as Array[String], "the 15 s focus is still on")
	view.now += 150
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "double_leg", "phase": "telegraph" }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["defend_the_shot"] as Array[String], "he's still shooting once it's over")


func test_a_stuffed_shot_gets_feint_called_to_set_up_the_next_one() -> void:
	var stuffed := FightEvent.new(0, 1, FightEvent.GRAPPLE_STOPPED, 0, { "action_id": "double_leg", "reason": "sprawled on" })
	assert_eq(_calls_on(_pair("wrestler", "kicker"), stuffed, "ideal:feint"), ["feint"] as Array[String])
	var too_far := FightEvent.new(0, 1, FightEvent.GRAPPLE_STOPPED, 0, { "action_id": "double_leg", "reason": "out of range" })
	assert_eq(_calls_on(_pair("wrestler", "kicker"), too_far, "ideal:feint"), [] as Array[String], "not when it never got there")
	assert_eq(_calls_on(_pair("wrestler", "kicker"), stuffed), [] as Array[String], "and a plain corner leaves it out")


func test_fire_back_when_the_opponents_strike_runs_on_into_a_combination() -> void:
	var into := FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "cross", "phase": "telegraph", "combo": "jab_cross", "step": 1 })
	assert_eq(_calls_on(_pair("boxer", "boxer"), into), ["fire_back"] as Array[String])
	var single := FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "jab", "phase": "telegraph" })
	assert_eq(_calls_on(_pair("boxer", "boxer"), single), [] as Array[String], "a single shot isn't a flurry")
	assert_eq(_calls_on(_pair("wrestler", "boxer"), into), [] as Array[String], "not for a man who shoots: it would hold his shots")


func test_follow_him_down_when_a_grappler_knocks_him_down_but_not_a_striker() -> void:
	var down := FightEvent.new(0, 1, FightEvent.KNOCKDOWN, 1, { "by": "overhand" })
	assert_eq(_calls_on(_pair("wrestler", "boxer"), down), ["takedown"] as Array[String])
	assert_eq(_calls_on(_pair("boxer", "wrestler"), down), [] as Array[String], "the Boxer doesn't shoot")


func test_get_up_when_the_man_on_top_is_rocked() -> void:
	var sim: FightSim = _pair("boxer", "wrestler")
	sim.apply_transition(1, "double_leg")
	assert_eq(_calls_on(sim, FightEvent.new(0, 1, FightEvent.ROCKED, 1, { "by": "ground_punch" })), ["get_up"] as Array[String],
		"not Pressure!, which can't be done on his back")


func test_pass_when_the_man_underneath_covers_up() -> void:
	var sim: FightSim = _pair("wrestler", "boxer")
	sim.apply_transition(0, "double_leg")
	var cover := FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 1, { "action_id": FightSim.GROUND_COVER, "phase": "windup" })
	assert_eq(_calls_on(sim, cover, "ideal:pass"), ["pass"] as Array[String])


func test_go_for_the_finish_on_taking_the_back() -> void:
	var sim: FightSim = _pair("wrestler", "boxer")
	var corner := Corner.new("ideal:go_for_the_finish", 1)
	var view: FightView = sim.views[0]
	sim.apply_transition(0, "double_leg")
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.POSITION_CHANGED, 0, { "action_id": "double_leg", "position": "full_guard", "roles": ["top", "bottom"] }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["ground_and_pound"] as Array[String], "in his guard: punch")
	sim.apply_transition(0, "take_back")
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.POSITION_CHANGED, 0, { "action_id": "take_back", "position": "back_control", "roles": ["top", "bottom"] }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["go_for_the_finish"] as Array[String], "on the back, where everyone knows the choke")


func test_collar_tie_as_the_clinch_starts_for_a_fighter_who_knows_it() -> void:
	var tie := func(red: String) -> Array[String]:
		var sim: FightSim = _pair(red, "boxer")
		sim.apply_transition(0, "clinch_entry")
		return _calls_on(sim, FightEvent.new(0, 1, FightEvent.POSITION_CHANGED, 0, { "action_id": "clinch_entry", "position": "clinch", "roles": ["neutral", "neutral"] }))
	assert_eq(tie.call("muay_thai"), ["collar_tie"] as Array[String])
	assert_eq(tie.call("boxer"), [] as Array[String], "the Boxer never learned it")
	var sim: FightSim = _pair("muay_thai", "wrestler")
	sim.apply_transition(0, "clinch_entry")
	assert_eq(_calls_on(sim, FightEvent.new(0, 1, FightEvent.POSITION_CHANGED, 0, { "action_id": "clinch_entry", "position": "clinch", "roles": ["neutral", "neutral"] })),
		[] as Array[String], "not against a man who shoots: tied up there he trips or takes him down")


func test_a_new_focus_never_cuts_short_survive() -> void:
	var sim: FightSim = _pair("kicker", "wrestler")
	var corner := Corner.new("ideal:defend_the_shot", 1)
	var view: FightView = sim.views[0]
	corner.on_event(view, FightEvent.new(0, 1, FightEvent.ROCKED, 0, { "by": "overhand" }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["survive"] as Array[String])
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "double_leg", "phase": "telegraph" }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), [] as Array[String], "Defend the shot! would replace Survive!")


func test_a_corner_written_with_some_moments_uses_only_those() -> void:
	var stuffed := FightEvent.new(0, 1, FightEvent.GRAPPLE_STOPPED, 0, { "action_id": "double_leg", "reason": "sprawled on" })
	assert_eq(_calls_on(_pair("wrestler", "kicker"), stuffed, "ideal:feint"), ["feint"] as Array[String])
	assert_eq(_calls_on(_pair("wrestler", "kicker"), stuffed, "ideal:pass+get_up"), [] as Array[String])
	assert_eq(_calls_on(_pair("wrestler", "kicker"), stuffed, "ideal:"), [] as Array[String], "the corner as it was before D257")
	assert_true(Corner.valid("ai:fire_back+pass"))
	assert_false(Corner.valid("ideal:nonsense"))
	assert_false(Corner.valid("mash"), "the masher needs a call")
	assert_false(Corner.valid("mash:nonsense"))


func test_the_key_masher_repeats_one_call_as_soon_as_it_is_over_wherever_it_can_be_heard() -> void:
	var sim: FightSim = _pair("wrestler", "kicker")
	var corner := Corner.new("mash:pressure", 3)
	var view: FightView = sim.views[0]
	var ticks: Array[int] = []
	for n in 400:
		view.now = n
		if not corner.due(view, LiveCalls.VOICE_MAX).is_empty():
			ticks.append(n)
	assert_eq(ticks, [0, 150, 300] as Array[int], "Pressure! again the moment its 15 s are up")
	assert_eq(corner.due(view, Corner.SAVE_VOICE), [] as Array[String], "never on a spent voice")
	sim.apply_transition(0, "double_leg")
	view.now = 1000
	assert_eq(corner.due(view, LiveCalls.VOICE_MAX), [] as Array[String], "not on the ground, where Pressure! can't be done")


func test_in_a_fight_the_corners_new_calls_go_out_and_the_harness_counts_what_they_did() -> void:
	var sim: FightSim = FightSummary.setup(SEED, _roster, _actions, "wrestler", "kicker", null, 300, [Corner.IDEAL, Corner.IDEAL] as Array[String])
	var row: Dictionary = FightSummary.play(sim)
	var red: Dictionary = CallOutcomes.from_text(row.call_outcomes_red)
	var blue: Dictionary = CallOutcomes.from_text(row.call_outcomes_blue)
	assert_true(red.has("cut_the_cage"), "the Wrestler's corner had him cut off the circling Kicker (D257): %s" % row.call_outcomes_red)
	assert_false(blue.is_empty(), "and the Kicker's corner called too: %s" % row.call_outcomes_blue)
	for id: String in red:
		assert_true(red[id][CallOutcomes.TAKEN] <= red[id][CallOutcomes.HEARD] and red[id][CallOutcomes.WON] <= red[id][CallOutcomes.JUDGED])


func test_keep_pressing_when_he_is_winning_the_exchanges_on_the_feet() -> void:
	var sim: FightSim = _pair("boxer", "kicker")
	var corner := Corner.new(Corner.IDEAL, 1)
	var view: FightView = sim.views[0]
	view.now = 100
	corner.on_event(view, FightEvent.new(100, 1, FightEvent.STRIKE_LANDED, 0, { "action_id": "hook", "damage": 6.0 }))
	corner.on_event(view, FightEvent.new(100, 1, FightEvent.STRIKE_LANDED, 1, { "action_id": "jab", "damage": 2.0 }))
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), [] as Array[String], "4 ahead isn't enough")
	corner.on_event(view, FightEvent.new(view.now, 1, FightEvent.STRIKE_LANDED, 0, { "action_id": "cross", "damage": 7.0 }))
	assert_eq(_due_after(corner, view, 1), [] as Array[String], "a coach's reaction time first")
	assert_eq(_due_after(corner, view, Corner.IDEAL_REACTION), ["pressure"] as Array[String], "11 ahead: Pressure!")
	view.now += Corner.PRESSING_TICKS + 1
	assert_eq(corner.due(view, LiveCalls.VOICE_MAX), [] as Array[String], "the lead gets old and goes")


## The ticks a corner shouts Pressure! over the first `ticks` of a standing fight, full voice.
func _pressure_ticks(corner: Corner, view: FightView, ticks: int) -> Array[int]:
	var out: Array[int] = []
	for n in ticks:
		view.now = n
		if corner.due(view, LiveCalls.VOICE_MAX).has("pressure"):
			out.append(n)
	return out


func test_close_in_has_a_grappler_press_a_striker_to_get_to_his_shots() -> void:
	var view: FightView = _pair("wrestler", "kicker").views[0]
	assert_eq(_pressure_ticks(Corner.new("ideal:close_in", 1), view, 400), [3, 157, 311] as Array[int],
		"Pressure! again the tick after each one's 15 s are up, and a coach's reaction later")
	assert_eq(_pressure_ticks(Corner.new("ideal:close_in", 1), _pair("boxer", "kicker").views[0], 400), [] as Array[int], "not for a striker")
	assert_eq(_pressure_ticks(Corner.new("ideal:close_in", 1), _pair("wrestler", "pressure_wrestler").views[0], 400), [] as Array[int],
		"not against a man who shoots too")


func test_close_in_fresh_waits_until_pressure_would_be_fresh_again() -> void:
	var view: FightView = _pair("wrestler", "kicker").views[0]
	var ticks: Array[int] = _pressure_ticks(Corner.new("ideal:close_in_fresh", 1), view, 1400)
	assert_eq(ticks, [Corner.IDEAL_REACTION, LiveCalls.REPEAT_TICKS + Corner.IDEAL_REACTION, 2 * LiveCalls.REPEAT_TICKS + Corner.IDEAL_REACTION] as Array[int],
		"once a minute, so it never wears off")
