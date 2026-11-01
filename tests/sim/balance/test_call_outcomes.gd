extends GutTest
## CallOutcomes (D257, Kyle's D251 answer): for each call, heard, taken, and whether the exchange
## it was called for was won (docs/01 §22.10).

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _e(tick: int, type: String, actor: int, data: Dictionary = {}) -> FightEvent:
	return FightEvent.new(tick, 1, type, actor, data)


func _heard(tick: int, id: String, outcome: String = LiveCalls.ACCEPTED) -> Array[FightEvent]:
	return [_e(tick, FightEvent.CALL_HEARD, 0, { "call_id": id }), _e(tick + 6, FightEvent.CALL_ANSWERED, 0, { "call_id": id, "outcome": outcome })]


func test_a_called_takedown_that_lands_wins_its_exchange() -> void:
	var events: Array[FightEvent] = _heard(10, "takedown")
	events.append(_e(20, FightEvent.GRAPPLE_WON, 0, { "action_id": "double_leg", "result": "success" }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "takedown": [1, 1, 1, 1] })


func test_a_called_takedown_that_never_lands_loses_it() -> void:
	var events: Array[FightEvent] = _heard(10, "takedown")
	events.append(_e(20, FightEvent.GRAPPLE_STOPPED, 0, { "action_id": "double_leg", "reason": "sprawled on" }))
	events.append(_e(200, FightEvent.STRIKE_LANDED, 1, { "action_id": "jab", "damage": 1.0 }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "takedown": [1, 1, 1, 0] })


func test_an_ignored_call_is_heard_but_not_taken() -> void:
	assert_eq(CallOutcomes.of(_heard(10, "clinch", LiveCalls.IGNORED), 0, _actions), { "clinch": [1, 0, 0, 0] })


func test_a_read_that_never_goes_off_is_taken_but_not_counted() -> void:
	var events: Array[FightEvent] = _heard(10, "fire_back")
	events.append(_e(100, FightEvent.STRIKE_LANDED, 1, { "action_id": "jab", "damage": 2.0 }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "fire_back": [1, 1, 0, 0] })


func test_fire_back_wins_when_he_lands_more_than_he_takes_after_it_goes_off() -> void:
	var events: Array[FightEvent] = _heard(10, "fire_back")
	events.append(_e(30, FightEvent.CALL_ANSWERED, 0, { "call_id": "fire_back", "outcome": LiveCalls.FIRED, "action_id": "jab" }))
	events.append(_e(33, FightEvent.STRIKE_LANDED, 0, { "action_id": "jab", "damage": 2.0 }))
	events.append(_e(36, FightEvent.STRIKE_LANDED, 0, { "action_id": "cross", "damage": 3.0 }))
	events.append(_e(40, FightEvent.STRIKE_LANDED, 1, { "action_id": "hook", "damage": 4.0 }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "fire_back": [1, 1, 1, 1] })


func test_survive_is_won_by_getting_through_it_and_lost_to_a_knockdown() -> void:
	var events: Array[FightEvent] = _heard(10, "survive")
	events.append_array(_heard(400, "survive"))
	events.append(_e(450, FightEvent.KNOCKDOWN, 0, { "by": "hook" }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "survive": [2, 2, 2, 1] })


func test_defend_the_shot_only_counts_once_a_shot_comes() -> void:
	var events: Array[FightEvent] = _heard(10, "defend_the_shot")  # No shot in the 15 s: not counted.
	events.append_array(_heard(400, "defend_the_shot"))
	events.append(_e(420, FightEvent.ACTION_PHASE, 1, { "action_id": "double_leg", "phase": "telegraph" }))
	events.append(_e(430, FightEvent.GRAPPLE_STOPPED, 1, { "action_id": "double_leg", "reason": "sprawled on" }))
	events.append_array(_heard(800, "defend_the_shot"))
	events.append(_e(820, FightEvent.ACTION_PHASE, 1, { "action_id": "double_leg", "phase": "telegraph" }))
	events.append(_e(830, FightEvent.GRAPPLE_WON, 1, { "action_id": "double_leg", "result": "success" }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "defend_the_shot": [3, 3, 2, 1] }, "one stuffed, one landed")


func test_a_spell_of_pressure_is_won_by_landing_more_than_he_takes() -> void:
	var events: Array[FightEvent] = _heard(10, "pressure")
	events.append(_e(30, FightEvent.STRIKE_LANDED, 0, { "action_id": "hook", "damage": 5.0 }))
	events.append(_e(60, FightEvent.STRIKE_LANDED, 1, { "action_id": "jab", "damage": 1.0 }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "pressure": [1, 1, 1, 1] })


func test_feints_shot_off_the_feint_is_one_call_and_one_exchange() -> void:
	var events: Array[FightEvent] = _heard(10, "feint")
	events.append(_e(25, FightEvent.CALL_ANSWERED, 0, { "call_id": "feint", "outcome": LiveCalls.ACCEPTED, "action_id": "double_leg" }))
	events.append(_e(35, FightEvent.GRAPPLE_WON, 0, { "action_id": "double_leg", "result": "success" }))
	assert_eq(CallOutcomes.of(events, 0, _actions), { "feint": [1, 1, 1, 1] })


func test_the_other_fighters_calls_are_not_counted() -> void:
	assert_eq(CallOutcomes.of(_heard(10, "takedown"), 1, _actions), {})


func test_outcomes_go_into_one_csv_cell_and_back() -> void:
	var outcomes := { "takedown": [5, 3, 3, 1], "survive": [2, 2, 2, 2] }
	assert_eq(CallOutcomes.as_text(outcomes), "survive:2/2/2/2;takedown:5/3/3/1")
	assert_eq(CallOutcomes.from_text(CallOutcomes.as_text(outcomes)), outcomes)
	assert_eq(CallOutcomes.from_text(""), {})
