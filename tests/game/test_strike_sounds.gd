extends GutTest
## StrikeSounds (D190, docs/06 §6.8): every strike sounds connected, missed or blocked, the three
## versions made from the same sound, and which one a fight event plays.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _event(type: String, data: Dictionary) -> FightEvent:
	return FightEvent.new(0, 1, type, 0, data)


func test_every_strike_in_the_data_has_a_sound_and_every_sound_is_a_strike() -> void:
	var strikes: Array[String] = []
	for id in _actions.ids():
		if _actions.get_action(id).category == "strike":
			strikes.append(id)
	for id in strikes:
		assert_true(StrikeSounds.RECIPES.has(id), "%s needs a line in StrikeSounds.RECIPES" % id)
	for id: String in StrikeSounds.RECIPES:
		assert_has(strikes, id, "%s isn't a strike in data/actions/" % id)


func test_landed_is_connected_unless_it_went_through_a_cover_up() -> void:
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.STRIKE_LANDED, { "action_id": "hook", "damage": 8 })), StrikeSounds.CONNECTED)
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.STRIKE_LANDED, { "action_id": "hook", "damage": 4, "covered": true })), StrikeSounds.BLOCKED)


func test_a_checked_kick_is_blocked_and_a_slipped_punch_whooshes_past() -> void:
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.STRIKE_MISSED, { "action_id": "leg_kick", "reason": "defended", "by_action": "check_kick" })), StrikeSounds.BLOCKED)
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.STRIKE_MISSED, { "action_id": "cross", "reason": "defended", "by_action": "slip" })), StrikeSounds.MISSED)
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.STRIKE_MISSED, { "action_id": "cross", "chance": 0.4 })), StrikeSounds.MISSED)
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.STRIKE_MISSED, { "action_id": "jab", "reason": "out of range" })), StrikeSounds.MISSED)


func test_only_strikes_make_a_sound() -> void:
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.GRAPPLE_WON, { "action_id": "double_leg", "result": "success" })), "")
	assert_eq(StrikeSounds.outcome_for(_event(FightEvent.STRIKE_DEFENDED, { "action_id": "check_kick", "against": "leg_kick", "worked": true })), "",
		"the check itself is heard through the kick's blocked sound")


func test_the_three_versions_are_different_but_each_is_the_same_every_time() -> void:
	var recipe: Dictionary = StrikeSounds.RECIPES.jab
	var versions: Array[PackedFloat32Array] = []
	for outcome in StrikeSounds.OUTCOMES:
		var samples: PackedFloat32Array = StrikeSounds.render(recipe, outcome, 1)
		assert_eq(samples, StrikeSounds.render(recipe, outcome, 1), "%s is the same sound each time it's made" % outcome)
		var peak: float = 0.0
		for v in samples:
			peak = maxf(peak, absf(v))
		assert_almost_eq(peak, 0.9, 0.001, "%s never clips" % outcome)
		versions.append(samples)
	assert_ne(versions[0], versions[1])
	assert_ne(versions[0], versions[2])
	assert_ne(versions[1], versions[2])


func test_a_harder_hit_is_louder_and_deeper_and_a_miss_is_quieter_than_a_hit() -> void:
	var light: Dictionary = StrikeSounds.play_settings("cross", StrikeSounds.CONNECTED, 2)
	var heavy: Dictionary = StrikeSounds.play_settings("cross", StrikeSounds.CONNECTED, 14)
	assert_gt(heavy.db, light.db)
	assert_lt(heavy.pitch, light.pitch)
	assert_lt(StrikeSounds.play_settings("cross", StrikeSounds.MISSED).db, heavy.db)


func test_a_fight_plays_hits_and_misses_and_muting_silences_them() -> void:
	var sounds := StrikeSounds.new()
	add_child_autofree(sounds)
	var heard: Array = []
	sounds.played.connect(func(id: String, outcome: String, was_heard: bool) -> void: heard.append([id, outcome, was_heard]))
	var sim := FightSim.new(7, _roster.make_pair("kicker", "boxer"), _actions)
	sounds.watch(sim)
	for n in 2000:
		if not sim.is_over():
			sim.tick()
	var outcomes: Array = heard.map(func(h: Array) -> String: return h[1])
	assert_has(outcomes, StrikeSounds.CONNECTED)
	assert_has(outcomes, StrikeSounds.MISSED)
	assert_true(heard.all(func(h: Array) -> bool: return h[2]))
	sounds.muted = true
	heard.clear()
	for n in 2000:
		if not sim.is_over():
			sim.tick()
	assert_gt(heard.size(), 0)
	assert_true(heard.all(func(h: Array) -> bool: return not h[2]), "muted: nothing is heard")
