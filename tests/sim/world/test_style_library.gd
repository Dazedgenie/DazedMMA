extends GutTest
## StyleLibrary: opponent style sheets (data/styles, docs/09 style@1, docs/03 §6, D160).

var _styles: StyleLibrary
var _roster: FighterLibrary
var _actions: ActionLibrary


func before_all() -> void:
	_styles = StyleLibrary.load_dir()
	_roster = FighterLibrary.load_dir()
	_actions = ActionLibrary.load_dir()


func test_there_is_a_sheet_for_every_planned_style() -> void:
	var ids: Array = _styles.ids()
	ids.sort()
	assert_eq(ids, ["bjj", "boxer", "brawler", "counter_striker", "dirty_boxer", "gnp_wrestler", "judoka", "karate", "kicker", "leg_kicker",
		"muay_thai", "pressure_wrestler", "sambo", "sprawl_brawl", "wrestler"])


func test_the_same_style_seed_and_level_make_the_same_opponent() -> void:
	var a: Dictionary = _styles.generate("brawler", 7, 0, _roster)
	var b: Dictionary = _styles.generate("brawler", 7, 0, _roster)
	assert_eq(JSON.stringify(a), JSON.stringify(b))


func test_different_seeds_make_different_opponents_of_the_same_style() -> void:
	var a: Dictionary = _styles.generate("kicker", 1, 0, _roster)
	var b: Dictionary = _styles.generate("kicker", 2, 0, _roster)
	assert_ne(JSON.stringify(a.stats), JSON.stringify(b.stats))
	assert_eq(a.techniques, b.techniques, "the moves are the style's")
	assert_eq(a.tells, b.tells, "the tell is the style's, so scouting it works on every one of them")


func test_opponents_stay_close_to_the_signature_fighter() -> void:
	for id: String in _styles.ids():
		var sheet: Dictionary = _styles.get_style(id)
		var base: Dictionary = _roster.profile(sheet.fighter)
		for n in 20:
			var p: Dictionary = _styles.generate(id, n, 0, _roster)
			for stat: String in StyleLibrary.stat_ids():
				var from: int = int(base.stats.get(stat, FighterState.DEFAULT_STAT))
				assert_almost_eq(int(p.stats[stat]), from, int(sheet.variation.stats), "%s #%d %s" % [id, n, stat])
			for leaning: String in StyleLeanings.LEANINGS:
				assert_almost_eq(int(p.style[leaning]), int(base.style.get(leaning, 0)), int(sheet.variation.style), "%s #%d %s" % [id, n, leaning])


func test_a_higher_level_makes_a_better_fighter_of_the_same_style() -> void:
	var novice: Dictionary = _styles.generate("wrestler", 3, -20, _roster)
	var contender: Dictionary = _styles.generate("wrestler", 3, 20, _roster)
	for stat: String in StyleLibrary.stat_ids():
		assert_true(contender.stats[stat] >= novice.stats[stat], stat)
	assert_eq(contender.stats.takedowns - novice.stats.takedowns, 40)
	assert_eq(contender.style, novice.style, "level changes how good, not how they fight")


func test_stats_and_leanings_stay_in_range_at_the_extremes() -> void:
	for level in [-StyleLibrary.MAX_LEVEL * 2, StyleLibrary.MAX_LEVEL * 2]:
		var p: Dictionary = _styles.generate("brawler", 11, level, _roster)
		assert_eq(p.level, clampi(level, -StyleLibrary.MAX_LEVEL, StyleLibrary.MAX_LEVEL))
		for stat: String in p.stats:
			assert_between(int(p.stats[stat]), 0, 100, stat)
		for leaning: String in p.style:
			assert_between(int(p.style[leaning]), -100, 100, leaning)


func test_a_generated_opponent_fights_a_full_fight_and_replays_identically() -> void:
	var roster := FighterLibrary.load_dir()
	roster.add(_styles.generate("counter_striker", 5, 10, roster, "gen_counter"))
	var sim := FightSim.new(9, roster.make_pair("gen_counter", "boxer"), _actions)
	sim.run_to_end()
	assert_true(sim.is_over())
	var replayed := FightSim.from_record(JSON.parse_string(JSON.stringify(sim.record())), roster, _actions)
	assert_eq(JSON.stringify(replayed.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))


func test_opponents_are_named_and_numbered_after_their_style() -> void:
	var p: Dictionary = _styles.generate("sprawl_brawl", 42, 0, _roster)
	assert_eq(p.id, "sprawl_brawl_42")
	assert_eq(p.name, "Sprawl-and-brawl #42")
	assert_eq(p.style_id, "sprawl_brawl")
	assert_null(p.template)
