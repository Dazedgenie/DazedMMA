extends GutTest
## More ground and pound (docs/01 §41, D270): the hammerfist, the body punch and the posture-up
## bomb from the top, covering up underneath, what covering up and a body shot open for the man
## on top, and turning away from mount to give up the back.

const SEED: int = 20261031
## Enough seeds that a rarer outcome turns up.
const SEEDS: int = 60

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## A fighter who does nothing unless told.
func _statue(fighter_name: String, stats: Dictionary) -> FighterState:
	return FighterState.new(fighter_name, stats, [], 0.0)


## Red on top of Blue in `where` (no rolls), two statues.
func _red_on_top(where: String, red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [_statue("Red", red_stats), _statue("Blue", blue_stats)], _actions, rules, 300)
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


# --- The new strikes -------------------------------------------------------------------

func test_everyone_on_top_has_the_hammerfist_and_the_body_punch_and_nobody_underneath_does() -> void:
	for where: String in ["full_guard", "half_guard", "side_control", "mount"]:
		var sim: FightSim = _red_on_top(where)
		for id: String in ["hammerfist", "ground_body_punch"]:
			assert_eq(sim.why_not(0, id), "", "%s from the top of %s" % [id, where])
			assert_eq(sim.why_not(1, id), "not possible from the bottom", "%s from the bottom of %s" % [id, where])
	assert_eq(_red_on_top("back_control").why_not(0, "hammerfist"), "", "hammerfists from the back")


func test_the_posture_up_bomb_is_only_thrown_from_inside_the_guard() -> void:
	assert_eq(_red_on_top("full_guard").why_not(0, "posture_bomb"), "")
	assert_eq(_red_on_top("half_guard").why_not(0, "posture_bomb"), "")
	assert_eq(_red_on_top("mount").why_not(0, "posture_bomb"), "not possible from this position")


func test_a_hammerfist_from_mount_lands_to_the_head() -> void:
	var sim: FightSim = _red_on_top("mount", { "top_control": 100, "power": 50 }, { "guard": 0 })
	_queue(sim, sim.now, 0, "hammerfist")
	_ticks(sim, 6)
	var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0].data.target, "head")
	assert_eq(int(landed[0].data.damage), roundi(3 * 1.3), "base 3 × Power 50 × mount top 1.3")


func test_the_bomb_postures_up_from_the_start_and_hits_hardest() -> void:
	var sim: FightSim = _red_on_top("full_guard", { "top_control": 100, "power": 50 }, { "guard": 0 })
	_queue(sim, sim.now, 0, "posture_bomb")
	_ticks(sim, 1)
	assert_eq(sim.fighters[0].phase, "telegraph")
	assert_has(sim.active_flags(0), "POSTURED_UP", "he sits up before he throws it: the way out is open")
	assert_has(_bonus_names(sim.odds_breakdown(1, "get_up")), "POSTURED_UP")
	_ticks(sim, 12)
	var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
	assert_eq(landed.size(), 1)
	assert_eq(int(landed[0].data.damage), roundi(8 * 0.8), "base 8 × full guard top 0.8")


func test_a_body_punch_on_the_ground_brings_his_hands_down() -> void:
	var sim: FightSim = _red_on_top("side_control", { "top_control": 100, "boxing": 100 }, { "guard": 0 })
	assert_false(sim.active_flags(1).has("HANDS_LOW"))
	_queue(sim, sim.now, 0, "ground_body_punch")
	_ticks(sim, 6)
	var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0].data.target, "body")
	assert_eq(sim.fighters[1].damage.head, 0)
	assert_has(sim.active_flags(1), "HANDS_LOW", "his hands come down to the ribs")
	assert_has(_bonus_names(sim.odds_breakdown(0, "ground_punch")), "HANDS_LOW", "the head is open")
	_ticks(sim, 20)
	assert_false(sim.active_flags(1).has("HANDS_LOW"), "for a moment only")


func test_under_amateur_rules_the_new_strikes_go_to_the_body() -> void:
	var sim: FightSim = _red_on_top("mount", { "top_control": 100 }, { "guard": 0 }, SEED, Ruleset.load_id("amateur_adult"))
	_queue(sim, sim.now, 0, "hammerfist")
	_ticks(sim, 6)
	assert_eq(_events(sim, FightEvent.STRIKE_LANDED, 0)[0].data.target, "body")


# --- Covering up underneath ------------------------------------------------------------

func test_covering_up_underneath_halves_the_punch_but_a_hammerfist_gets_round_the_gloves() -> void:
	for id: String in ["ground_punch", "hammerfist"]:
		var open: FightSim = _red_on_top("mount", { "top_control": 100, "power": 100 }, { "guard": 0 })
		_queue(open, open.now, 0, id)
		_ticks(open, 6)
		var covered: FightSim = _red_on_top("mount", { "top_control": 100, "power": 100 }, { "guard": 0 })
		_queue(covered, covered.now, 1, "ground_cover")
		_queue(covered, covered.now + 1, 0, id)
		_ticks(covered, 7)
		var full: int = int(_events(open, FightEvent.STRIKE_LANDED, 0)[0].data.damage)
		var hit: FightEvent = _events(covered, FightEvent.STRIKE_LANDED, 0)[0]
		assert_true(hit.data.get("covered", false), "%s on the gloves" % id)
		var through: float = 0.8 if id == "hammerfist" else 0.5
		assert_almost_eq(float(hit.data.damage), float(full) * through, 1.0, "%s: %d of %d" % [id, hit.data.damage, full])


func test_covering_up_on_the_ground_isnt_answering_so_the_referee_keeps_counting() -> void:
	var sim: FightSim = _red_on_top("mount", { "top_control": 100 }, { "guard": 0, "chin": 100 })
	_queue(sim, sim.now, 1, "ground_cover")
	_queue(sim, sim.now + 1, 0, "hammerfist")
	_ticks(sim, 7)
	assert_true(_events(sim, FightEvent.STRIKE_LANDED, 0)[0].data.get("covered", false))
	assert_eq(sim.fighters[1].unanswered, 1, "on the ground the shots on the gloves still count")


func test_covering_up_opens_the_pass_the_back_the_choke_and_the_body() -> void:
	var guard: FightSim = _red_on_top("full_guard")
	_queue(guard, guard.now, 1, "ground_cover")
	_ticks(guard, 2)
	assert_has(guard.active_flags(1), "COVERED")
	assert_has(_bonus_names(guard.odds_breakdown(0, "guard_pass")), "COVERED")
	assert_has(_bonus_names(guard.odds_breakdown(0, "ground_body_punch")), "COVERED")
	assert_has(_bonus_names(guard.odds_breakdown(0, "hammerfist")), "COVERED")
	var mount: FightSim = _red_on_top("mount")
	_queue(mount, mount.now, 1, "ground_cover")
	_ticks(mount, 2)
	assert_has(_bonus_names(mount.odds_breakdown(0, "take_back")), "COVERED")
	var back: FightSim = _red_on_top("back_control")
	_queue(back, back.now, 1, "ground_cover")
	_ticks(back, 2)
	assert_has(_bonus_names(back.odds_breakdown(0, "rear_naked_choke")), "COVERED", "hands on his face, not on the arm")


# --- Turning away from mount -----------------------------------------------------------

func test_covering_up_in_mount_he_sometimes_turns_away_and_gives_up_his_back() -> void:
	var turned: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("mount", { "top_control": 100 }, { "guard": 0, "fight_iq": 0, "chin": 100 }, SEED + n)
		sim.fighters[1].damage.head = 400
		_queue(sim, sim.now, 1, "ground_cover")
		_queue(sim, sim.now + 1, 0, "hammerfist")
		_ticks(sim, 7)
		if sim.situation.position != "back_control":
			assert_eq(sim.situation.position, "mount")
			continue
		turned += 1
		assert_eq(sim.role(0), PositionLibrary.TOP, "Red has the back")
		assert_eq(sim.role(1), PositionLibrary.BOTTOM)
		assert_eq(sim.fighters[1].unanswered, 1, "turning away doesn't answer the shots")
		assert_eq(sim.fighters[1].escapes, 0, "and isn't getting out")
		assert_eq(sim.fighters[1].turned_away, 1)
		var changed: Array[FightEvent] = _events(sim, FightEvent.POSITION_CHANGED, 1)
		assert_eq(changed[-1].data.action_id, FightSim.TURN_AWAY)
		assert_string_contains(FightLogFormatter.describe(changed[-1], sim), "GIVES UP HIS BACK")
	assert_gt(turned, 0, "some turn away (%d of %d)" % [turned, SEEDS])
	assert_lt(turned, SEEDS / 2, "most don't (%d of %d)" % [turned, SEEDS])


func test_a_man_in_mount_with_his_hands_free_and_his_head_clear_never_turns_away() -> void:
	for n in SEEDS / 2:
		var sim: FightSim = _red_on_top("mount", { "top_control": 100 }, { "guard": 0, "fight_iq": 0, "chin": 100 }, SEED + n)
		_queue(sim, sim.now, 0, "hammerfist")
		_ticks(sim, 6)
		assert_eq(sim.situation.position, "mount")


func test_only_the_sim_turns_him_away_never_his_own_ai() -> void:
	assert_false(_actions.get_action(FightSim.TURN_AWAY).get("basic", false), "nobody knows it as a move: it's a reaction")


# --- The fighter AI ----------------------------------------------------------------------

func test_on_top_the_wrestler_mixes_his_ground_strikes_and_the_boxer_covers_up_underneath() -> void:
	var roster := FighterLibrary.load_dir()
	var starts: Dictionary = {}
	for n in 12:
		var sim := FightSim.new(SEED + n, roster.make_pair("gnp_wrestler", "boxer"), _actions, 1, 300)
		sim.apply_transition(0, "double_leg")
		_ticks(sim, 400)
		for e in _events(sim, FightEvent.ACTION_PHASE):
			if e.data.phase == "windup":
				starts[e.data.action_id] = starts.get(e.data.action_id, 0) + 1
	for id: String in ["ground_punch", "hammerfist", "ground_body_punch", "posture_bomb"]:
		assert_gt(starts.get(id, 0), 0, "the Wrestler throws the %s (%s)" % [id, starts])
	assert_gt(starts.get("ground_cover", 0), 0, "the Boxer covers up (%s)" % starts)


func test_the_feed_says_a_body_shot_on_the_ground_brings_his_hands_down() -> void:
	var sim: FightSim = _red_on_top("side_control", { "top_control": 100, "boxing": 100 }, { "guard": 0 })
	_queue(sim, sim.now, 0, "ground_body_punch")
	_ticks(sim, 6)
	assert_string_contains(FightLogFormatter.describe(_events(sim, FightEvent.STRIKE_LANDED, 0)[0], sim), "his hands come down")
