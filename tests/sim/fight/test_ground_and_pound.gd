extends GutTest
## Health, the referee and ground and pound (docs/01 §24, D120, D121): ground strikes
## from the top of full guard, tie-ups and get-ups from underneath, the referee's
## stoppages, amateur rules on the ground, and 10-8 rounds needing real damage.

const SEED: int = 20261026
## Enough seeds that a 95% move works on most of them and a rarer outcome turns up.
const SEEDS: int = 40

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, a step apart in the middle of the cage.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, rules, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	return sim


## Red takes Blue down (no roll): full guard, Red on top.
func _on_the_ground(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim: FightSim = _pair(red_stats, blue_stats, fight_seed, rules)
	assert_true(sim.apply_transition(0, "double_leg"))
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


func _bonus_names(odds: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in odds.bonuses:
		out.append(b.name)
	return out


## Red throws `id` every `every` ticks for `ticks` ticks (a queued move waits until Red is free).
func _keep_throwing(sim: FightSim, id: String, ticks: int, every: int = 2) -> void:
	for t in range(sim.now, sim.now + ticks, every):
		_queue(sim, t, 0, id)
	_ticks(sim, ticks)


# --- Health -------------------------------------------------------------------------

func test_health_is_the_head_damage_a_fighter_can_still_take() -> void:
	var f := FighterState.new("Red", { "chin": 50 })
	assert_eq(f.health(), 1.0)
	f.damage.head = 500
	assert_almost_eq(f.health(), 0.5, 0.0001, "10 × (Chin + 50) of head damage is all of it")
	f.damage.head = 5000
	assert_eq(f.health(), 0.0)


func test_the_referee_stops_it_when_health_runs_out() -> void:
	var sim: FightSim = _pair({ "boxing": 100 }, { "striking_defense": 0 })
	sim.fighters[1].damage.head = 998  # One jab (3 damage) from empty.
	_queue(sim, 0, 0, "jab")
	_ticks(sim, 10)
	var ended: Array[FightEvent] = _events(sim, FightEvent.FIGHT_ENDED)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].data.result, FightSim.RESULT_TKO)
	assert_eq(ended[0].data.winner, 0)
	assert_eq(ended[0].data.why, FightSim.STOP_HEALTH)


func test_amateur_referees_stop_it_with_some_health_left() -> void:
	var adult := FightSim.new(SEED, [FighterState.new("Red", {}, []), FighterState.new("Blue", {}, [])], _actions, Ruleset.load_id("amateur_adult"))
	assert_almost_eq(adult.stop_health(), 0.15, 0.0001, "early_stoppage_bias 0.3 × 0.5")
	assert_eq(adult.stop_unanswered(), 1, "and step in after one shot fewer")
	var pro: FightSim = _pair()
	assert_eq(pro.stop_health(), 0.0)
	assert_eq(pro.stop_unanswered(), FightSim.STOP_UNANSWERED)


func test_the_referee_stops_a_rocked_fighter_who_takes_more_clean_shots_without_answering() -> void:
	# Power 0 jabs barely hurt, so they never rock or drop him: only the referee ends it.
	var sim: FightSim = _pair({ "boxing": 100, "power": 0 }, { "striking_defense": 0 })
	sim.fighters[1].rocked_ticks = 1000
	_keep_throwing(sim, "jab", 60)
	var ended: Array[FightEvent] = _events(sim, FightEvent.FIGHT_ENDED)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].data.why, FightSim.STOP_SHOTS)
	assert_eq(_events(sim, FightEvent.STRIKE_LANDED, 0).size(), FightSim.STOP_UNANSWERED)
	assert_eq(_events(sim, FightEvent.KNOCKDOWN).size(), 0)


func test_landing_something_back_answers() -> void:
	var sim: FightSim = _pair({ "striking_defense": 0 }, { "boxing": 100 })
	sim.fighters[1].rocked_ticks = 1000
	sim.fighters[1].unanswered = FightSim.STOP_UNANSWERED - 1
	_queue(sim, 0, 1, "jab")
	_ticks(sim, 6)
	assert_eq(_events(sim, FightEvent.STRIKE_LANDED, 1).size(), 1, "the setup: Blue's jab lands")
	assert_eq(sim.fighters[1].unanswered, 0, "landing back clears the count")


# --- Ground and pound ------------------------------------------------------------------

func test_on_top_a_ground_punch_lands_to_the_head_and_scores() -> void:
	var sim: FightSim = _on_the_ground({ "top_control": 100, "boxing": 100 }, { "guard": 0 })
	var before: float = sim.round_points()[0]
	_queue(sim, 0, 0, "ground_punch")
	_ticks(sim, 8)
	var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0].data.target, "head")
	assert_eq(sim.fighters[1].damage.head, landed[0].data.damage)
	assert_eq(int(landed[0].data.damage), roundi(4 * 1.0 * 0.8), "base 4 × Power 50 × full guard top 0.8")
	assert_gt(sim.round_points()[0], before + float(landed[0].data.damage) - 0.0001)


func test_only_the_fighter_on_top_can_ground_and_pound() -> void:
	var sim: FightSim = _on_the_ground()
	assert_eq(sim.why_not(0, "ground_punch"), "")
	assert_eq(sim.why_not(1, "ground_punch"), "not possible from the bottom")
	assert_eq(sim.why_not(1, "tie_up"), "")
	assert_eq(sim.why_not(0, "tie_up"), "not possible from the top")
	var standing: FightSim = _pair()
	assert_eq(standing.why_not(0, "ground_punch"), "not possible from this position")


func test_under_amateur_rules_ground_strikes_go_to_the_body_and_elbows_are_out() -> void:
	var amateur: Ruleset = Ruleset.load_id("amateur_adult")
	assert_false(amateur.allows_action(_actions.get_action("ground_elbow")), "no elbows (docs/08)")
	assert_true(Ruleset.load_id("pro").allows_action(_actions.get_action("ground_elbow")))
	assert_false(amateur.allows_target(_actions.get_action("ground_punch"), "head"))
	assert_true(amateur.allows_target(_actions.get_action("jab"), "head"), "standing head punches are fine")
	var sim: FightSim = _on_the_ground({ "top_control": 100, "boxing": 100 }, { "guard": 0 }, SEED, amateur)
	_queue(sim, 0, 0, "ground_punch")
	_ticks(sim, 8)
	assert_eq(_events(sim, FightEvent.STRIKE_LANDED, 0)[0].data.target, "body")


func test_posturing_up_to_strike_gives_the_bottom_fighter_a_way_out() -> void:
	var sim: FightSim = _on_the_ground()
	assert_false(_bonus_names(sim.odds_breakdown(1, "get_up").to_dict()).has("POSTURED_UP"))
	_queue(sim, 0, 0, "ground_punch")
	_ticks(sim, 2)  # In the wind-up.
	assert_has(sim.active_flags(0), "POSTURED_UP")
	assert_has(_bonus_names(sim.odds_breakdown(1, "get_up").to_dict()), "POSTURED_UP")
	assert_has(_bonus_names(sim.odds_breakdown(1, "tie_up").to_dict()), "POSTURED_UP")


func test_a_tie_up_from_the_bottom_smothers_the_strike_and_stops_ground_strikes_until_he_postures_up() -> void:
	var tied: int = 0
	for n in SEEDS:
		var sim: FightSim = _on_the_ground({ "top_control": 0 }, { "guard": 100, "strength": 100 }, SEED + n)
		_queue(sim, 0, 1, "tie_up")
		_queue(sim, 3, 0, "ground_punch")  # Still winding up when the tie-up is rolled, 0.5 s in.
		_ticks(sim, 10)
		var won: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 1)
		if won.is_empty():
			continue
		tied += 1
		assert_eq(won[0].data.result, "collar", "the tie-up is the collar tie, held until he postures up (D263)")
		assert_eq(sim.situation.position, "full_guard", "the fight stays where it is")
		assert_eq(_events(sim, FightEvent.STRIKE_LANDED, 0).size(), 0, "the punch was smothered")
		assert_true(sim.ground_grips().collar)
		assert_has(sim.active_flags(0), "POSTURE_BROKEN")
		_queue(sim, sim.now, 0, "ground_punch")
		_ticks(sim, 8)
		assert_eq(_events(sim, FightEvent.STRIKE_MISSED, 0)[-1].data.reason, "tied up")
	assert_gt(tied, SEEDS / 2, "most tie-ups work at 95%% (%d of %d)" % [tied, SEEDS])


func test_underneath_the_referee_stops_a_fighter_who_never_answers() -> void:
	var sim: FightSim = _on_the_ground({ "top_control": 100, "boxing": 100, "power": 0 }, { "guard": 0, "chin": 100 })
	_keep_throwing(sim, "ground_punch", 400)
	var ended: Array[FightEvent] = _events(sim, FightEvent.FIGHT_ENDED)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].data.why, FightSim.STOP_SHOTS)
	var landed: int = _events(sim, FightEvent.STRIKE_LANDED, 0).size()
	assert_lte(landed, FightSim.STOP_UNANSWERED + roundi(FightSim.GROUND_STOP_PER_HEALTH), "a fresh fighter: about 16 in a row")
	assert_gt(landed, 10)


func test_a_hurt_fighter_underneath_is_stopped_sooner() -> void:
	var sim: FightSim = _on_the_ground({ "top_control": 100, "boxing": 100, "power": 0 }, { "guard": 0, "chin": 50 })
	sim.fighters[1].damage.head = 800  # 20% health left.
	_keep_throwing(sim, "ground_punch", 400)
	assert_eq(_events(sim, FightEvent.FIGHT_ENDED)[0].data.why, FightSim.STOP_SHOTS)
	assert_lte(_events(sim, FightEvent.STRIKE_LANDED, 0).size(), FightSim.STOP_UNANSWERED + roundi(FightSim.GROUND_STOP_PER_HEALTH * 0.2))


func test_getting_out_from_under_or_tying_up_answers() -> void:
	var sim: FightSim = _on_the_ground()
	sim.fighters[1].unanswered = 5
	sim.apply_transition(1, "get_up")
	assert_eq(sim.fighters[1].unanswered, 0)


func test_rocked_again_on_the_ground_is_the_ko_roll_not_a_knockdown() -> void:
	var again: int = 0
	for n in SEEDS:
		var sim: FightSim = _on_the_ground({ "top_control": 100, "power": 100 }, { "guard": 0, "chin": 0 }, SEED + n)
		sim.fighters[1].rocked_ticks = 1000
		sim.fighters[1].damage.head = 300
		_queue(sim, 0, 0, "ground_elbow")
		_ticks(sim, 10)
		assert_eq(_events(sim, FightEvent.KNOCKDOWN).size(), 0, "nowhere to fall")
		for e in _events(sim, FightEvent.ROCKED, 1):
			assert_true(e.data.get("again", false))
			again += 1
		if not sim.is_over():
			assert_eq(sim.situation.position, "full_guard", "still on the ground")
	assert_gt(again, 0)


# --- The fighter AI on the ground ---------------------------------------------------

func test_underneath_a_fighter_under_fire_ties_up_and_gets_up() -> void:
	var roster := FighterLibrary.load_dir()
	var starts: Dictionary = {}
	for n in 10:
		var sim := FightSim.new(SEED + n, roster.make_pair("wrestler", "boxer"), _actions, 1, 300)
		sim.apply_transition(0, "double_leg")
		_ticks(sim, 300)
		for e in _events(sim, FightEvent.ACTION_PHASE):
			if e.data.phase == "telegraph" or (e.data.phase == "windup" and e.data.action_id == "tie_up"):
				starts[e.data.action_id] = starts.get(e.data.action_id, 0) + 1
	assert_gt(starts.get("ground_punch", 0) + starts.get("ground_elbow", 0), 0, "the Wrestler pounds")
	assert_gt(starts.get("ground_elbow", 0), 0, "and knows elbows")
	assert_gt(starts.get("tie_up", 0), 0, "the Boxer ties him up")
	assert_gt(starts.get("get_up", 0), 0, "and works to get up")


func test_tied_up_the_fighter_on_top_postures_up_before_he_punches_again() -> void:
	var roster := FighterLibrary.load_dir()
	var sim := FightSim.new(SEED, roster.make_pair("wrestler", "boxer"), _actions, 1, 300)
	sim.apply_transition(0, "double_leg")
	sim.set_ground_grips(0, true)  # His head is tied (D263).
	sim.fighters[1].work_rate = 0.0
	var postured: int = -1
	var thrown: int = 0
	for k in 300:
		sim.tick()
		if not sim.ground_grips().collar:
			postured = k
			break
	for e in _events(sim, FightEvent.ACTION_PHASE, 0):
		if e.data.phase == "telegraph" and sim.actions.get_action(e.data.action_id).category == "strike":
			thrown += 1
	assert_gt(postured, -1, "he postures up out of it")
	assert_eq(thrown, 0, "and throws nothing while his head is tied")


# --- Judges ----------------------------------------------------------------------

func test_a_10_8_for_out_landing_needs_real_damage() -> void:
	assert_eq(Judging.round_card([200.0, 20.0], [0, 0], [], [1, 0]), [10, 8] as Array[int], "a beating with a rock in it")
	assert_eq(Judging.round_card([200.0, 20.0], [0, 0], [], [0, 0]), [10, 9] as Array[int], "a lot of landing that never hurt him (D120)")
	assert_eq(Judging.round_card([200.0, 20.0], [0, 0]), [10, 8] as Array[int], "with nothing said about impact, out-landing alone")
