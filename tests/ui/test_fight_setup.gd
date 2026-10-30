extends GutTest
## The fight setup as a tale of the tape (ui/fight_setup.gd, ui/tale_of_the_tape.gd, D172, docs/06 §6.7): any two
## fighters with ◀ ▶, their frames and stat groups face to face (the opponent's scouted, as grades), the scouting
## card and the keys to the fight.

var _setup: FightSetup


func before_each() -> void:
	_setup = FightSetup.new()
	add_child_autofree(_setup)


func _profile(stats: Dictionary, height: int = 180, reach: int = 180, stance: String = "orthodox") -> Dictionary:
	return { "stats": stats, "stance": stance, "frame": { "height_cm": height, "reach_cm": reach, "build": "average" } }


func test_it_opens_on_the_playtest_matchup() -> void:
	var s: Dictionary = _setup.settings()
	assert_eq([s.red, s.blue], ["wrestler", "kicker"])
	assert_eq(s.label, "Wrestler vs Kicker")
	assert_string_contains(_setup.text(), "WRESTLER")


func test_the_arrows_step_through_every_fighter_with_a_style_sheet_and_wrap() -> void:
	assert_eq(_setup.fighters.size(), StyleLibrary.shared().ids().size(), "one fighter per style sheet")
	assert_false(_setup.fighters.has("check_red"), "the engine's check fighters aren't offered")
	var seen: Array[String] = []
	for i in _setup.fighters.size():
		seen.append(_setup.settings().blue)
		_setup.step_fighter(1, 1)
	assert_eq(_setup.settings().blue, "kicker", "all the way round comes back to the start")
	assert_eq(seen.size(), _setup.fighters.size())
	_setup.step_fighter(0, -1)
	assert_eq(_setup.settings().red, _setup.fighters[-1], "back from the first is the last")


func test_any_two_fighters_can_meet() -> void:
	_setup.pick_fighters("sambo", "karate")
	var s: Dictionary = _setup.settings()
	assert_eq([s.red, s.blue], ["sambo", "karate"])
	assert_eq(s.label, "Sambo vs Karate point fighter")
	assert_string_contains(_setup.text(), "KARATE POINT FIGHTER")


func test_changing_your_fighter_rebuilds_the_drilled_rules_for_him() -> void:
	var before: RuleSlots = _setup.rule_slots()
	_setup.pick_fighters("wrestler", "boxer")
	assert_eq(_setup.rule_slots(), before, "same red fighter, same slots")
	_setup.pick_fighters("boxer", "boxer")
	assert_ne(_setup.rule_slots(), before)


func test_the_tape_shows_the_frames_and_the_longer_reach() -> void:
	var text: String = _setup.text()
	assert_string_contains(text, "HEIGHT 178 cm | 183 cm")
	assert_string_contains(text, "REACH 180 cm | 190 cm")
	assert_string_contains(text, "He has 10 cm more reach")


func test_the_opponents_stats_are_scouted_grades_and_yours_are_exact() -> void:
	var tape := TaleOfTheTape.new()
	add_child_autofree(tape)
	tape.show_fighters(_profile({ "takedowns": 80 }), _profile({ "boxing": 70 }))
	var stats: Array = tape.rows.filter(func(r: Dictionary) -> bool: return r.has("stat"))
	assert_eq(stats.size(), TaleOfTheTape.TAPE_STATS.size())
	var lines: PackedStringArray = tape.text().split("\n")
	assert_true(lines.has("Takedowns 80 A+ | B"), "your number and grade, his grade only")
	assert_true(lines.has("Boxing 50 B | A−"))
	var boxing: Dictionary = stats.filter(func(r: Dictionary) -> bool: return r.stat == "boxing")[0]
	assert_eq([boxing.blue_low, boxing.blue_high], [65.0, 72.0], "his bar covers his grade's whole band")


func test_a_stat_a_fighter_doesnt_list_is_the_default() -> void:
	assert_eq(TaleOfTheTape.stat({ "stats": { "takedowns": 90 } }, "takedowns"), 90.0)
	assert_eq(TaleOfTheTape.stat({ "stats": {} }, "chin"), float(FighterState.DEFAULT_STAT))


func test_grade_bands_run_from_the_grade_to_the_next_one_up() -> void:
	assert_eq(TaleOfTheTape.grade_band(55.0), [50.0, 65.0])
	assert_eq(TaleOfTheTape.grade_band(85.0), [80.0, 100.0])
	assert_eq(TaleOfTheTape.grade_band(10.0), [0.0, 20.0])


func test_the_keys_name_a_big_stat_gap_each_way_and_the_scouting_card() -> void:
	var keys: Array[String] = TaleOfTheTape.keys(_profile({ "takedowns": 85 }), _profile({ "kicking": 90, "power": 60 }),
		{ "how_to_beat": "Take him down." })
	var all: String = "\n".join(keys)
	assert_string_contains(all, "A big edge to you in takedowns (A+ against his B)")
	assert_string_contains(all, "A big edge to him in kicking (A+ against your B)")
	assert_false(all.contains("power"), "one grade apart isn't worth a key")
	assert_string_contains(all, "Scouting: Take him down.")
	assert_eq(TaleOfTheTape.keys(_profile({}), _profile({})), [] as Array[String], "an even match has no keys")


func test_the_keys_name_reach_then_height_and_a_southpaw() -> void:
	assert_string_contains(TaleOfTheTape.keys(_profile({}, 180, 190), _profile({}))[0], "You have 10 cm more reach")
	assert_string_contains(TaleOfTheTape.keys(_profile({}), _profile({}, 186, 182))[0], "He's 6 cm taller")
	assert_string_contains(TaleOfTheTape.keys(_profile({}), _profile({}, 180, 180, "southpaw"))[0], "He's a southpaw")


func test_show_settings_puts_the_fighters_and_rules_back() -> void:
	_setup.pick_fighters("judoka", "bjj")
	var s: Dictionary = _setup.settings()
	_setup.pick_fighters("boxer", "kicker")
	_setup.show_settings(s)
	assert_eq([_setup.settings().red, _setup.settings().blue], ["judoka", "bjj"])


func test_a_playtest_step_picks_its_fighters() -> void:
	var step: Dictionary = Playtest.steps()[0]
	_setup.pick_fighters("sambo", "karate")
	_setup.pick_step(String(step.id))
	assert_eq([_setup.settings().red, _setup.settings().blue], [String(step.red), String(step.blue)])
	assert_string_contains(_setup.text(), String(step.name))
