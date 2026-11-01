extends GutTest
## *Hand fight!* (D265, docs/01 §40.13): key H in the clinch and on the ground. For 10 s every grip
## the fighter goes for (an underhook in the clinch; a wrist, the collar tie, the half-guard underhook,
## a frame or two hands on the choking arm underneath; posturing up, the crossface, flattening the
## frame or stripping the hands on top) is 15% likelier to work. The AI corner's hand_fight moment (D257) calls it when the
## other man wins a grip, with voice to spare, and the HUD says who holds what.

const SEED: int = 20261031
const SEEDS: int = 20
const WINDOW: int = 100  # The call's 10 s.


var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A humble Wrestler (he never ignores a call) against the Boxer, put in the clinch or on the ground.
func _fight(where: String, fight_seed: int) -> FightSim:
	var pair: Array[FighterState] = _roster.make_pair("wrestler", "boxer")
	pair[0].profile = pair[0].profile.duplicate(true)
	pair[0].profile["personality"] = { "ego": -100 }
	pair[1].profile = pair[1].profile.duplicate(true)
	pair[1].profile["personality"] = { "ego": -100 }
	var sim := FightSim.new(fight_seed, pair, _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	match where:
		"clinch":
			assert_true(sim.apply_transition(0, "clinch_entry"))
		"full_guard":
			assert_true(sim.apply_transition(0, "double_leg"))
		"side_control":
			assert_true(sim.apply_transition(0, "double_leg"))
			assert_true(sim.apply_transition(0, "guard_pass"))
	return sim


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


func _bonus(sim: FightSim, i: int, id: String, name: String) -> float:
	for bonus: Dictionary in sim.odds_breakdown(i, id).to_dict().get("bonuses", []):
		if bonus.name == name:
			return float(bonus.value)
	return 0.0


func test_hand_fight_is_key_h_in_the_clinch_and_on_the_ground_only() -> void:
	var call: Dictionary = CallLibrary.shared().get_call("hand_fight")
	assert_eq(String(call.name), "Hand fight!")
	assert_eq(call.hotkey, "H")
	assert_false(call.positions.has("standing"))
	assert_true(call.positions.has("clinch"))
	assert_true(call.positions.has("crucifix"))
	assert_eq(int(call.focus.duration_ms), 10000)


func test_on_the_call_his_grips_are_easier_to_win_for_ten_seconds() -> void:
	for setup: Array in [["clinch", "pummel"], ["full_guard", "wrist_control"], ["side_control", "frame"]]:
		var sim: FightSim = _fight(setup[0], SEED)
		sim.fighters[0].work_rate = 0.0  # Red holds still, so the position stays put.
		sim.fighters[1].work_rate = 0.0
		assert_eq(_bonus(sim, 1, setup[1], "hand fight"), 0.0, "%s: nothing before the call" % setup[1])
		assert_true(sim.submit(FightCommand.live_call(0, 1, "hand_fight")))
		_ticks(sim, 20)
		assert_eq(sim.situation.position, setup[0])
		assert_almost_eq(_bonus(sim, 1, setup[1], "hand fight"), 0.15, 0.001, "%s on the call" % setup[1])
		_ticks(sim, WINDOW)
		assert_eq(_bonus(sim, 1, setup[1], "hand fight"), 0.0, "%s: back to normal after 10 s" % setup[1])


func test_the_call_does_nothing_for_his_other_moves() -> void:
	var sim: FightSim = _fight("clinch", SEED)
	sim.fighters[0].work_rate = 0.0
	sim.fighters[1].work_rate = 0.0
	assert_true(sim.submit(FightCommand.live_call(0, 1, "hand_fight")))
	_ticks(sim, 20)
	assert_eq(_bonus(sim, 1, "clinch_break", "hand fight"), 0.0)
	assert_eq(_bonus(sim, 1, "double_leg", "hand fight"), 0.0)


func test_standing_the_call_is_refused_as_impossible() -> void:
	var sim: FightSim = _fight("standing", SEED)
	assert_true(sim.submit(FightCommand.live_call(0, 0, "hand_fight")))
	_ticks(sim, 20)
	var outcomes: Array[String] = []
	for e in sim.events:
		if e.type == FightEvent.CALL_ANSWERED and e.actor == 0:
			outcomes.append(String(e.data.outcome))
	assert_eq(outcomes, [LiveCalls.INFEASIBLE] as Array[String])


func test_the_ai_corner_calls_it_when_the_other_man_wins_a_grip() -> void:
	# The hand_fight moment on its own (D257's `ideal:<moments>`), one corner a case, so the moment's
	# "not again while it's on" doesn't hide the case being tested.
	var cases: Array = [
		[1, "pummel", LiveCalls.VOICE_MAX, ["hand_fight"], "the other man's underhook"],
		[0, "pummel", LiveCalls.VOICE_MAX, [], "not for his own grip"],
		[1, "double_leg", LiveCalls.VOICE_MAX, [], "not for a takedown"],
		[1, "wrist_control", Corner.SPARE_VOICE - 1.0, [], "not without voice to spare for the bigger calls"],
	]
	for case: Array in cases:
		var sim: FightSim = _fight("clinch", SEED)
		var corner := Corner.new("ideal:hand_fight", 1)
		var view: FightView = sim.views[0]
		view.now = 10
		corner.on_event(view, FightEvent.new(10, 1, FightEvent.GRAPPLE_WON, case[0], { "action_id": case[1], "result": "won" }))
		view.now += Corner.IDEAL_REACTION
		var want: Array[String] = []
		want.assign(case[3])
		assert_eq(corner.due(view, case[2]), want, case[4])


func test_the_hud_says_who_holds_what() -> void:
	var clinch: FightSim = _fight("clinch", SEED)
	assert_eq(FightHud.grips_text(clinch), "")
	clinch.set_grips([0, 0])
	assert_eq(FightHud.grips_text(clinch), "WRESTLER: BODY LOCK · BOXER: OVERHOOK")
	clinch.set_grips([0, 1])
	assert_eq(FightHud.grips_text(clinch), "WRESTLER: UNDERHOOK · BOXER: UNDERHOOK")
	var ground: FightSim = _fight("side_control", SEED)
	assert_eq(FightHud.grips_text(ground), "")
	ground.set_ground_grips(1, false, FightSim.NO_GRIP, true)
	assert_eq(FightHud.grips_text(ground), "BOXER HOLDS A WRIST, FRAMES")
	assert_true(ground.apply_transition(0, "take_crucifix"))
	assert_eq(FightHud.grips_text(ground), "BOXER'S ARMS TRAPPED")
