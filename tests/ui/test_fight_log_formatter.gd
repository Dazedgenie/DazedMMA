extends GutTest
## FightLogFormatter: readable console lines for fight events.

var _sim: FightSim


func before_each() -> void:
	_sim = FightSim.new(1, SimCheck.default_fighters(), ActionLibrary.load_dir())


func _plain(bbcode: String) -> String:
	return RegEx.create_from_string("\\[[^\\]]*\\]").sub(bbcode, "", true)


func test_a_landed_strike_names_the_fighter_move_target_and_damage() -> void:
	var e := FightEvent.new(34, 1, FightEvent.STRIKE_LANDED, 0, { "action_id": "jab", "target": "head", "damage": 3 })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:03.4  t34  Red's Jab LANDS (head, 3 damage)")


func test_time_is_counted_from_the_start_of_the_events_round() -> void:
	var e := FightEvent.new(3000 + 615, 2, FightEvent.STRIKE_MISSED, 1, { "action_id": "jab", "target": "head" })
	assert_eq(FightLogFormatter.time_label(e, 300), "R2 1:01.5")


func test_only_the_start_of_a_move_is_shown_without_phase_details() -> void:
	var start := FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "jab", "phase": "telegraph" })
	var windup := FightEvent.new(1, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "jab", "phase": "windup" })
	assert_false(FightLogFormatter.is_detail(start))
	assert_true(FightLogFormatter.is_detail(windup))
