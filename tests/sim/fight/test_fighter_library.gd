extends GutTest
## FighterLibrary and FighterState.from_profile: fighters come from data/fighters
## (docs/09 fighter@1, D94, issue #32), and a fight replays from seed + fighter ids + commands.

const SEED: int = 20261024

var _roster: FighterLibrary
var _actions: ActionLibrary


func before_all() -> void:
	_roster = FighterLibrary.load_dir()
	_actions = ActionLibrary.load_dir()


func test_the_showcase_fighters_load_from_data() -> void:
	var kicker: FighterState = _roster.make("kicker")
	assert_eq(kicker.id, "kicker")
	assert_eq(kicker.name, "Kicker")
	assert_eq(kicker.stat("kicking"), 70)
	assert_eq(kicker.stat("chin"), FighterState.DEFAULT_STAT, "unlisted stats are average")
	assert_eq(kicker.repertoire, ["jab", "teep", "leg_kick", "body_kick", "head_kick", "knee", "triangle", "armbar"] as Array[String])
	assert_almost_eq(kicker.work_rate, 0.015, 0.0001)
	assert_eq(kicker.style.value(StyleLeanings.RANGE), -60.0)
	assert_eq(kicker.profile.stance, "orthodox")
	assert_eq(kicker.profile.gifts, ["long_limbs"])


func test_a_template_fills_in_what_a_profile_leaves_out() -> void:
	var blue: Dictionary = _roster.profile("check_blue")
	assert_eq(blue.template, "check_red")
	assert_eq(blue.stance, "southpaw", "its own fields win")
	assert_eq(blue.techniques, ["jab"], "missing fields come from the template")
	assert_eq(blue.stats.striking_defense, 55.0)


func test_template_stats_merge_key_by_key() -> void:
	var library := FighterLibrary.new()
	library.add({ "id": "wrestler", "name": "Archetype", "template": null, "stats": { "takedowns": 70, "cardio": 60 }, "techniques": ["double_leg"] })
	library.add({ "id": "gen_0001", "name": "Generated", "template": "wrestler", "stats": { "cardio": 45 } })
	var f: FighterState = library.make("gen_0001")
	assert_eq(f.name, "Generated")
	assert_eq(f.stat("takedowns"), 70)
	assert_eq(f.stat("cardio"), 45)
	assert_eq(f.repertoire, ["double_leg"] as Array[String])


func test_each_fighter_is_made_fresh() -> void:
	var a: FighterState = _roster.make("boxer")
	a.stats.boxing = 1
	assert_eq(_roster.make("boxer").stat("boxing"), 65, "a fight never changes the data")


func test_tendencies_tilt_what_the_fighter_throws() -> void:
	var library := FighterLibrary.new()
	library.add({ "id": "jabber", "name": "Jabber", "template": null, "techniques": ["jab", "cross"],
		"tendencies": { "work_rate": 0.1, "actions": { "jab": 4.0 } } })
	library.add({ "id": "statue", "name": "Statue", "template": null, "techniques": [], "tendencies": { "work_rate": 0.0 } })
	var sim := FightSim.new(SEED, library.make_pair("jabber", "statue"), _actions)
	sim.run_to_end()
	var thrown := { "jab": 0, "cross": 0 }
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.actor == 0:
			thrown[e.data.action_id] += 1
	assert_gt(thrown.jab, thrown.cross * 2, "jab weighted 4× over the cross")


func test_a_fight_replays_from_seed_fighter_ids_and_commands() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	sim.submit(FightCommand.queue_action(50, 0, "body_kick"))
	sim.submit(FightCommand.live_call(300, 1, "hook"))
	sim.run_to_end()
	var saved: Variant = JSON.parse_string(JSON.stringify(sim.record()))
	assert_eq(saved.fighters, ["kicker", "boxer"])
	var again: FightSim = FightSim.from_record(saved, _roster, _actions)
	assert_gt(sim.events.size(), 1000)
	assert_eq(JSON.stringify(again.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))


func test_a_record_keeps_short_rounds() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("check_red", "check_blue"), _actions, 1, 30)
	sim.run_to_end()
	var again: FightSim = FightSim.from_record(sim.record(), _roster, _actions)
	assert_eq(again.now, 30 * FightClock.TICKS_PER_SECOND)
	assert_eq(JSON.stringify(again.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))
