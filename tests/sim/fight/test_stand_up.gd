extends GutTest
## Standing up from the top (docs/01 §42, D330–D335): the move and how hard it is from each position,
## the grips that hold him down, the man underneath left on his back a moment, the up-kick and the
## leg grab as he rises, the fighter AI standing up (strikers, and anyone in a dangerous guard), and
## *Get up!* doing it on top.

const SEED: int = 20261101
const SEEDS: int = 40

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _statue(fighter_name: String, p_stats: Dictionary = {}) -> FighterState:
	return FighterState.new(fighter_name, p_stats, [], 0.0)


## Red on top of Blue in `where` (no rolls).
func _on_top(where: String, red: FighterState, blue: FighterState, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [red, blue], _actions, rules, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
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


func _bonus(b: OddsBreakdown, bonus_name: String) -> float:
	for x: Dictionary in b.bonuses:
		if x.name == bonus_name:
			return float(x.value)
	return 0.0


# --- The move ---------------------------------------------------------------------------

func test_only_the_man_on_top_can_stand_up_and_from_every_position_on_top() -> void:
	for where: String in ["full_guard", "half_guard", "side_control", "mount", "back_control"]:
		var sim: FightSim = _on_top(where, _statue("Red"), _statue("Blue"))
		assert_eq(sim.why_not(0, FightSim.STAND_UP), "", "on top in %s" % where)
		assert_ne(sim.why_not(1, FightSim.STAND_UP), "", "underneath in %s he gets up his own way" % where)
		assert_eq(sim.transition_for(0, FightSim.STAND_UP).to, PositionLibrary.STANDING)
	assert_true(_actions.get_action(FightSim.STAND_UP).get("basic", false), "everyone knows how (D330)")


func test_it_is_easy_off_side_control_mount_and_the_back_and_harder_out_of_the_guard() -> void:
	var odds := {}
	for where: String in ["full_guard", "half_guard", "side_control", "mount", "back_control"]:
		odds[where] = _on_top(where, _statue("Red"), _statue("Blue")).odds(0, FightSim.STAND_UP)
	assert_almost_eq(float(odds.full_guard), 0.45, 0.001, "his legs are wrapped round you (Kyle, D331)")
	assert_almost_eq(float(odds.half_guard), 0.45, 0.001, "a leg trapped")
	for where: String in ["side_control", "mount", "back_control"]:
		assert_gt(float(odds[where]), 0.7, "%s: you just step off" % where)
	var b: OddsBreakdown = _on_top("mount", _statue("Red"), _statue("Blue")).odds_breakdown(0, FightSim.STAND_UP)
	assert_almost_eq(_bonus(b, "from mount"), 0.30, 0.001, "the position's bonus is named in the odds")


func test_his_grips_from_underneath_hold_him_down() -> void:
	var sim: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue"))
	var free: float = sim.odds(0, FightSim.STAND_UP)
	sim.set_ground_grips(0, true)
	assert_almost_eq(sim.odds(0, FightSim.STAND_UP), free - 0.15, 0.001, "his head tied down (D333)")
	sim.set_ground_grips(2, false)
	assert_almost_eq(sim.odds(0, FightSim.STAND_UP), free - 0.15, 0.001, "both wrists held: -5% and -10%")
	var half: FightSim = _on_top("half_guard", _statue("Red"), _statue("Blue"))
	var plain: float = half.odds(0, FightSim.STAND_UP)
	half.set_ground_grips(0, false, 1)
	assert_almost_eq(half.odds(0, FightSim.STAND_UP), plain - 0.10, 0.001, "his underhook in half guard")


func test_standing_up_leaves_him_on_his_back_a_second_then_he_gets_up() -> void:
	var sim: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue"))
	assert_true(sim.apply_transition(0, FightSim.STAND_UP))
	assert_true(sim.situation.is_standing())
	assert_true(sim.fighters[1].is_down(), "still on his back (Kyle, D332)")
	assert_eq(sim.fighters[1].down_ticks, 10, "for a second")
	assert_false(sim.fighters[1].is_rocked(), "not hurt: just down")
	assert_eq(sim.fighters[0].stand_ups, 1)
	assert_eq(sim.fighters[1].knockdowns, 0, "it isn't a knockdown")
	assert_eq(sim.why_not(0, "follow_down"), "", "he can dive back down on him")
	assert_gt(_bonus(sim.odds_breakdown(0, "follow_down"), "DOWN"), 0.0)
	_ticks(sim, 10)
	assert_false(sim.fighters[1].is_down())
	var up: Array[FightEvent] = _events(sim, FightEvent.GOT_UP, 1)
	assert_eq(up.size(), 1)
	assert_true(up[0].data.get("left_down", false), "the feed says he got up off his back, not that he beat a count")
	assert_string_contains(FightLogFormatter.describe(up[0], sim), "off his back")


func test_under_pride_rules_the_man_on_his_back_can_be_kicked() -> void:
	var sim: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue"), SEED, Ruleset.load_id("pride"))
	assert_true(sim.apply_transition(0, FightSim.STAND_UP))
	assert_eq(sim.why_not(0, "soccer_kick"), "")
	var unified: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue"))
	assert_true(unified.apply_transition(0, FightSim.STAND_UP))
	assert_ne(unified.why_not(0, "soccer_kick"), "", "not under unified rules")


func test_a_stand_up_that_works_or_fails_shows_in_the_feed() -> void:
	var sim: FightSim = _on_top("mount", _statue("Red", { "top_control": 100 }), _statue("Blue"))
	_queue(sim, sim.now, 0, FightSim.STAND_UP)
	_ticks(sim, 20)
	var moved: Array[FightEvent] = _events(sim, FightEvent.POSITION_CHANGED, 0).filter(func(e: FightEvent) -> bool: return e.tick > 0)
	assert_eq(moved.size(), 1)
	assert_eq(moved[0].data.action_id, FightSim.STAND_UP)
	assert_string_contains(FightLogFormatter.describe(moved[0], sim), "STANDS UP")
	assert_eq(sim.fighters[0].stand_ups_tried, 1)


# --- His answers underneath ---------------------------------------------------------------

func test_the_up_kick_only_lands_on_a_man_standing_up_and_stops_him() -> void:
	var sim: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue"))
	assert_eq(sim.odds_breakdown(1, FightSim.UP_KICK).missing, FightSim.STANDING_UP, "nothing to kick at while he's down on you")
	var stopped: int = 0
	for n in SEEDS:
		var s: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue", { "kicking": 100, "speed": 100 }), SEED + n)
		_queue(s, s.now, 0, FightSim.STAND_UP)
		_queue(s, s.now + 2, 1, FightSim.UP_KICK)
		_ticks(s, 15)
		var landed: Array[FightEvent] = _events(s, FightEvent.STRIKE_LANDED, 1)
		if landed.is_empty():
			continue
		assert_eq(landed[0].data.get("into", ""), FightSim.STAND_UP, "it stops the stand-up")
		assert_eq(landed[0].data.target, "head")
		assert_eq(s.situation.position, "full_guard", "he's still on top")
		assert_eq(s.fighters[1].up_kicks_landed, 1)
		stopped += 1
	assert_gt(stopped, SEEDS / 2, "a good kicker lands most of them")


func test_the_up_kick_hits_like_a_standing_kick_not_a_punch_from_the_bottom() -> void:
	for n in SEEDS:
		var s: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue", { "kicking": 100, "speed": 100 }), SEED + n)
		_queue(s, s.now, 0, FightSim.STAND_UP)
		_queue(s, s.now + 2, 1, FightSim.UP_KICK)
		_ticks(s, 15)
		var landed: Array[FightEvent] = _events(s, FightEvent.STRIKE_LANDED, 1)
		if not landed.is_empty():
			assert_gte(int(landed[0].data.damage), 6, "the bottom's 0.4 doesn't shrink it (× 2.5 on the opening)")
			return
	fail_test("no up-kick landed")


func test_amateur_up_kicks_go_to_the_body() -> void:
	for n in SEEDS:
		var s: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue", { "kicking": 100, "speed": 100 }), SEED + n, Ruleset.load_id("amateur_adult"))
		_queue(s, s.now, 0, FightSim.STAND_UP)
		_queue(s, s.now + 2, 1, FightSim.UP_KICK)
		_ticks(s, 15)
		var landed: Array[FightEvent] = _events(s, FightEvent.STRIKE_LANDED, 1)
		if not landed.is_empty():
			assert_eq(landed[0].data.target, "body", "no head strikes on the ground in amateur rules")
			return
	fail_test("no up-kick landed")


func test_a_leg_locker_gets_the_leg_as_it_comes_past() -> void:
	var sim: FightSim = _on_top("full_guard", _statue("Red"), _statue("Blue"))
	var plain: float = sim.odds(1, "ankle_lock")
	_queue(sim, sim.now, 0, FightSim.STAND_UP)
	_ticks(sim, 3)
	assert_eq(sim.fighters[0].action_id, FightSim.STAND_UP)
	assert_almost_eq(_bonus(sim.odds_breakdown(1, "ankle_lock"), FightSim.STANDING_UP), 0.15, 0.001, "D333")
	assert_gt(sim.odds(1, "ankle_lock"), plain)
	for id: String in ["heel_hook", "kneebar"]:
		assert_true(_actions.get_action(id).opportunities.any(func(o: Dictionary) -> bool: return o.get("opponent_flag", "") == FightSim.STANDING_UP), id)


# --- The fighter AI ------------------------------------------------------------------------

func test_a_striker_on_top_stands_up_after_a_while_and_a_grappler_stays_down() -> void:
	var boxer_up: int = 0
	var wrestler_up: int = 0
	var early: int = 0
	for n in 10:
		var boxer: FightSim = _on_top("full_guard", _roster.make("boxer"), _statue("Blue"), SEED + n)
		_ticks(boxer, 600)
		var tried: Array[FightEvent] = _events(boxer, FightEvent.ACTION_PHASE, 0).filter(
			func(e: FightEvent) -> bool: return e.data.phase == "telegraph" and e.data.action_id == FightSim.STAND_UP)
		if not tried.is_empty():
			boxer_up += 1
			if tried[0].tick < FighterAI.STAND_AFTER_TICKS:
				early += 1
		var wrestler: FightSim = _on_top("full_guard", _roster.make("wrestler"), _statue("Blue"), SEED + n)
		_ticks(wrestler, 600)
		if _starts(wrestler, 0).has(FightSim.STAND_UP):
			wrestler_up += 1
	assert_gt(boxer_up, 6, "the Boxer would rather be on his feet (Kyle, D334)")
	assert_eq(early, 0, "but not straight away")
	assert_eq(wrestler_up, 0, "the Wrestler is happy on top")


func test_even_a_grappler_gets_out_of_a_dangerous_guard() -> void:
	var judoka := _roster.make("judoka")
	var bjj := _roster.make("bjj")
	assert_gt(bjj.effective_stat("submissions"), judoka.effective_stat("submission_defense"))
	var up: int = 0
	for n in 10:
		var sim: FightSim = _on_top("full_guard", _roster.make("judoka"), _statue("BJJ", { "submissions": 90 }), SEED + n)
		sim.fighters[1].repertoire = ["triangle", "armbar"] as Array[String]
		_ticks(sim, 600)
		if _starts(sim, 0).has(FightSim.STAND_UP):
			up += 1
	assert_gt(up, 3, "a black belt's guard is no place to stay (Kyle, D334)")


func test_the_ai_doesnt_stand_up_off_a_rocked_man() -> void:
	var stood: int = 0
	for n in 10:
		var sim: FightSim = _on_top("full_guard", _roster.make("boxer"), _statue("Blue"), SEED + n)
		sim.fighters[1].rocked_ticks = 1000
		_ticks(sim, 400)
		if _starts(sim, 0).has(FightSim.STAND_UP):
			stood += 1
	assert_eq(stood, 0, "he pounds a hurt man")


func test_underneath_the_ai_up_kicks_or_grabs_a_leg_as_he_stands() -> void:
	var kicks: int = 0
	var grabs: int = 0
	for n in SEEDS:
		var sim: FightSim = _on_top("full_guard", _statue("Red"), _roster.make("sambo"), SEED + n)
		_queue(sim, sim.now, 0, FightSim.STAND_UP)
		_ticks(sim, 12)
		var starts: Array[String] = _starts(sim, 1)
		if starts.has(FightSim.UP_KICK):
			kicks += 1
		if starts.has("ankle_lock") or starts.has("kneebar") or starts.has("heel_hook"):
			grabs += 1
	assert_gt(kicks, 0, "the Sambo man kicks up at him now and then")
	assert_gt(grabs, 0, "and goes for the leg now and then")
	assert_lt(kicks + grabs, SEEDS, "but not every time")


func test_after_standing_up_a_striker_lets_him_up_and_a_grappler_sometimes_dives_back_in() -> void:
	var dives := { "boxer": 0, "wrestler": 0 }
	for id: String in dives:
		for n in 20:
			var sim: FightSim = _on_top("full_guard", _roster.make(id), _statue("Blue"), SEED + n)
			assert_true(sim.apply_transition(0, FightSim.STAND_UP))
			_ticks(sim, 10)
			if _starts(sim, 0).has("follow_down"):
				dives[id] += 1
	assert_eq(dives.boxer, 0, "the Boxer stood up to stay standing (D332)")
	assert_gt(dives.wrestler, 0, "the Wrestler goes back after him now and then")
	assert_lt(dives.wrestler, 20)


# --- The call -----------------------------------------------------------------------------

func test_get_up_stands_him_up_on_top_of_every_ground_position() -> void:
	var call: Dictionary = CallLibrary.load_dir().get_call("get_up")
	assert_true(call.roles.has("top"), "Get up! on top too (Kyle, D335)")
	assert_true(call.actions.has(FightSim.STAND_UP))
	for where: String in ["full_guard", "side_control", "mount"]:
		var sim: FightSim = _on_top(where, _roster.make("wrestler"), _statue("Blue"))
		sim.submit(FightCommand.live_call(sim.now, 0, "get_up"))
		_ticks(sim, 20)
		assert_has(_starts(sim, 0), FightSim.STAND_UP, "from %s" % where)
