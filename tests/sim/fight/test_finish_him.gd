extends GutTest
## *Finish him!* (docs/01 §22.13, D480–D484): the corner sends his fighter after a rocked or badly hurt man
## on the feet. For 6 s, even once the other man recovers, he throws more and harder, walks him down and cuts
## off his way out, and his own guard drops 15% while he does.

const SEED: int = 20261105
const SEEDS: int = 30
## The call is heard and acted on 6 ticks later (a humble fighter, neutral trust).
const HEARD_BY: int = 8
## 6 s of fight time.
const SWARM_TICKS: int = 60

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## The Boxer (humble, so he never ignores a call) against a Kicker at mid range.
func _boxer(fight_seed: int = SEED) -> FightSim:
	var red: FighterState = _roster.make("boxer")
	red.profile = red.profile.duplicate(true)
	red.profile["personality"] = { "ego": -100 }
	var blue: FighterState = _roster.make("kicker")
	var sim := FightSim.new(fight_seed, [red, blue], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


func _answers(sim: FightSim, actor: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.CALL_ANSWERED and e.actor == actor:
			out.append(e.data)
	return out


## Strikes Red started from tick `since` on.
func _strikes(sim: FightSim, since: int = 0) -> int:
	var n: int = 0
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.actor == 0 and e.tick >= since \
				and _actions.get_action(e.data.action_id).category == FighterAI.STRIKE:
			n += 1
	return n


## Blue's head this hurt (0–1): his health is 1 − it.
func _hurt_head(f: FighterState, share: float) -> void:
	f.damage.head = share * FighterState.HURT_SCALE * (f.effective_stat("chin") + 50.0)


func test_finish_him_is_key_1_on_the_feet_for_6_seconds() -> void:
	var call: Dictionary = CallLibrary.shared().get_call("finish_him")
	assert_eq(String(call.name), "Finish him!")
	assert_eq(int(call.hotkey), int(CallLibrary.shared().get_call("pressure").hotkey), "key 1, in place of Pressure! (Kyle, D481)")
	assert_eq(call.positions, ["standing"])
	assert_eq(LiveCalls.shape(call), LiveCalls.FOCUS)
	assert_eq(int(call.focus.duration_ms), 6000, "6 s, even if he recovers (Kyle, D482)")
	assert_almost_eq(float(call.focus.guard_drop), 0.15, 0.001, "his guard drops 15% (Kyle, D483)")
	assert_almost_eq(float(call.opponent_hurt), 0.5, 0.001, "rocked, or past half hurt (Kyle, D480)")


func test_it_comes_ahead_of_pressure_on_key_1() -> void:
	var ids: Array[String] = CallLibrary.shared().ids()
	assert_lt(ids.find("finish_him"), ids.find("pressure"), "the fight screen makes the first call on a key that works from here")


func test_on_a_fresh_man_he_says_he_isnt_hurt() -> void:
	var sim: FightSim = _boxer()
	sim.submit(FightCommand.live_call(sim.now, 0, "finish_him"))
	_ticks(sim, HEARD_BY)
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers.size(), 1)
	assert_eq(String(answers[0].outcome), LiveCalls.INFEASIBLE)
	assert_eq(String(answers[0].reason), "he isn't hurt")
	assert_true(sim.decisions[0].calls.focus.is_empty())


func test_he_takes_it_on_a_rocked_man_and_on_a_man_past_half_hurt() -> void:
	var rocked: FightSim = _boxer()
	rocked.fighters[1].rocked_ticks = 40
	rocked.submit(FightCommand.live_call(rocked.now, 0, "finish_him"))
	_ticks(rocked, HEARD_BY)
	assert_eq(String(_answers(rocked)[0].outcome), LiveCalls.ACCEPTED, "rocked")
	var hurt: FightSim = _boxer()
	_hurt_head(hurt.fighters[1], 0.55)
	hurt.submit(FightCommand.live_call(hurt.now, 0, "finish_him"))
	_ticks(hurt, HEARD_BY)
	assert_eq(String(_answers(hurt)[0].outcome), LiveCalls.ACCEPTED, "badly hurt, health 45%")
	var bit: FightSim = _boxer()
	_hurt_head(bit.fighters[1], 0.4)
	bit.submit(FightCommand.live_call(bit.now, 0, "finish_him"))
	_ticks(bit, HEARD_BY)
	assert_eq(String(_answers(bit)[0].outcome), LiveCalls.INFEASIBLE, "a bit hurt, health 60%: not yet")


func test_his_guard_drops_while_he_swarms_and_comes_back_after_6_seconds() -> void:
	var sim: FightSim = _boxer()
	var plain: float = sim.fighters[0].effective_stat("striking_defense")
	sim.fighters[1].rocked_ticks = 20  # Recovers 2 s in: the swarm goes on.
	sim.submit(FightCommand.live_call(sim.now, 0, "finish_him"))
	_ticks(sim, HEARD_BY)
	assert_false(sim.decisions[0].calls.focus.is_empty(), "swarming")
	assert_almost_eq(sim.fighters[0].effective_stat("striking_defense"), plain * 0.85, 0.5, "15% off his Striking defense")
	assert_has(sim.fighters[0].condition_reasons("striking_defense"), "swarming")
	_ticks(sim, 30)
	assert_false(sim.fighters[1].is_rocked(), "the other man has recovered")
	assert_false(sim.decisions[0].calls.focus.is_empty(), "and he's still swarming: 6 s, even if he recovers")
	_ticks(sim, SWARM_TICKS)
	assert_true(sim.decisions[0].calls.focus.is_empty(), "over after 6 s")
	assert_almost_eq(sim.fighters[0].effective_stat("striking_defense"), plain, 0.5, "his guard back up")


func test_on_the_call_he_throws_more_at_a_rocked_man() -> void:
	var called: int = 0
	var alone: int = 0
	for n in SEEDS:
		var sim: FightSim = _boxer(SEED + n)
		sim.fighters[1].rocked_ticks = 60
		sim.submit(FightCommand.live_call(sim.now, 0, "finish_him"))
		_ticks(sim, SWARM_TICKS)
		called += _strikes(sim)
		var own: FightSim = _boxer(SEED + n)
		own.fighters[1].rocked_ticks = 60
		_ticks(own, SWARM_TICKS)
		alone += _strikes(own)
	assert_gt(float(called), float(alone) * 1.2, "a swarm: more shots than he throws at a rocked man on his own (%d against %d)" % [called, alone])


func test_the_fight_screen_hides_it_until_he_is_hurt() -> void:
	var sim: FightSim = _boxer()
	var call: Dictionary = sim.calls.get_call("finish_him")
	assert_eq(FightHud.call_problem(sim, 0, call), "he isn't hurt")
	assert_false(FightHud.call_fits(sim, 0, call), "hidden: key 1 shows Pressure!")
	sim.fighters[1].rocked_ticks = 30
	assert_eq(FightHud.call_problem(sim, 0, call), "")
	assert_true(FightHud.call_fits(sim, 0, call))
