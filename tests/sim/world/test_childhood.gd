extends GutTest
## His childhood (sim/world/childhood.gd, docs/03 §11.2, D312): three scenes at 8, 12 and 15, and what the choices in
## them make of him.


func _choice(id: String, backgrounds: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var ch: Dictionary = { "id": id, "text": id, "outcome": id, "backgrounds": backgrounds }
	ch.merge(extra)
	return ch


## A small childhood: one scene per age, each with a wrestling, a boxing and a farm choice.
func _small() -> Childhood:
	var kid := Childhood.new()
	for age: int in Childhood.AGES:
		kid.add({ "schema": "vignette@1", "id": "age%d" % age, "age": age, "title": "At %d" % age, "text": "",
			"choices": [
				_choice("wrestle", { "wrestling_family": 3 }, { "stats": { "takedowns": 4 }, "personality": { "discipline": 10 },
					"person": { "role": "Dad", "family": true, "about": "Wrestled in college." } }),
				_choice("box", { "boxing_gym_kid": 3 }, { "stats": { "boxing": 4 }, "money": 200 }),
				_choice("farm", { "farm_kid": 3 }, { "height": 1, "person": { "role": "Grandma", "family": true, "named": false, "about": "Runs the farm." } }),
			] })
	return kid


func _picks(choice_ids: Array) -> Array:
	var out: Array = []
	for i in choice_ids.size():
		out.append({ "scene": "age%d" % Childhood.AGES[i], "choice": choice_ids[i] })
	return out


func test_the_real_scenes_give_one_scene_at_each_age_and_the_same_seed_draws_the_same() -> void:
	var kid: Childhood = Childhood.load_dir()
	var drawn: Array = kid.draw(7)
	assert_eq(drawn.size(), Childhood.AGES.size())
	for i in drawn.size():
		assert_eq(int(kid.scene(drawn[i]).age), Childhood.AGES[i], "in age order")
	assert_eq(kid.draw(7), drawn, "seeded by the career")
	var seen: Dictionary = {}
	for s in 40:
		seen[kid.draw(s)[0]] = true
	assert_gt(seen.size(), 1, "different careers get different scenes")


func test_the_background_he_chose_most_wins_and_the_runner_up_is_his_flavour() -> void:
	var t: Dictionary = _small().tally(_picks(["box", "wrestle", "box"]))
	assert_eq(t.background, "boxing_gym_kid")
	assert_eq(t.second, "wrestling_family")


func test_a_tie_goes_to_the_choice_he_made_later() -> void:
	var t: Dictionary = _small().tally(_picks(["wrestle", "box", "farm"]))
	assert_eq(t.background, "farm_kid", "three different choices: the one at 15 decides")
	assert_eq(t.second, "boxing_gym_kid", "and the one at 12 is the flavour")


func test_his_choices_nudge_his_stats_personality_height_and_money() -> void:
	var kid: Childhood = _small()
	var bgs: BackgroundLibrary = BackgroundLibrary.load_dir()
	var base: Dictionary = bgs.make_fighter("wrestling_family", 3, FighterLibrary.load_dir())
	var picks: Array = _picks(["wrestle", "wrestle", "farm"])
	var p: Dictionary = kid.apply(base, picks, bgs)
	var flavour: int = roundi(BackgroundLibrary.STRENGTH_BONUS * Childhood.SECOND_SHARE)
	var farm_strength: String = String(bgs.get_background("farm_kid").strengths[0])
	var expected_takedowns: int = int(base.stats.takedowns) + 8 + (flavour if farm_strength == "takedowns" else 0)
	assert_eq(int(p.stats.takedowns), clampi(expected_takedowns, BackgroundLibrary.STAT_FLOOR, Childhood.STAT_MAX), "4 points a wrestling choice")
	assert_eq(int(p.stats[farm_strength]), clampi(int(base.stats[farm_strength]) + flavour + (8 if farm_strength == "takedowns" else 0),
		BackgroundLibrary.STAT_FLOOR, Childhood.STAT_MAX), "the farm flavour on its first strength")
	assert_eq(int(p.personality.discipline), clampi(int(base.personality.discipline) + 20, -100, 100))
	assert_eq(int(p.frame.height_cm), int(base.frame.height_cm) + Childhood.HEIGHT_PER_LEAN)
	assert_eq(int(p.frame.reach_cm), int(base.frame.reach_cm) + Childhood.HEIGHT_PER_LEAN, "reach grows with him")
	assert_eq(kid.money(_picks(["box", "box", "farm"])), 400)
	assert_eq(kid.apply(base, picks, bgs), p, "the same picks make the same fighter")


func test_the_people_he_met_are_named_and_family_share_his_surname() -> void:
	var people: Array = _small().people(_picks(["wrestle", "box", "farm"]), "Danny Hill", "england", 5)
	assert_eq(people.size(), 2)
	assert_eq(people[0].role, "Dad")
	assert_true(String(people[0].name).ends_with(" Hill"), "his dad is a Hill")
	assert_eq(people[0].age, 8)
	assert_eq(people[1].role, "Grandma")
	assert_eq(people[1].name, "", "she goes by Grandma")
	assert_eq(people[1].age, 15)
	assert_eq(Childhood.person_text(people[1]), "Grandma: Runs the farm.")
	assert_string_contains(Childhood.person_text(people[0]), "Dad (")


func test_a_career_started_from_his_childhood_is_what_he_chose_and_saves_it() -> void:
	var kid: Childhood = _small()
	var choices := { "coach": "Sam", "name": "Danny Hill", "hometown": "Leeds", "country": "England", "country_id": "england",
		"background": "track_star", "stance": "orthodox", "childhood": _picks(["box", "box", "wrestle"]) }
	var c: Career = Career.start(choices, 11, FighterLibrary.load_dir(), null, null, kid)
	assert_eq(c.about.background, "boxing_gym_kid", "his childhood, not the list, picked it")
	assert_eq(c.childhood.second, "wrestling_family")
	assert_eq(c.money, int(BackgroundLibrary.shared().get_background("boxing_gym_kid").money) + 400)
	assert_eq(c.childhood.people.size(), 1)
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.childhood.picks, c.childhood.picks)
	assert_eq(back.childhood.people[0].age, 15)
	assert_eq(back.childhood.people[0].name, c.childhood.people[0].name)
	assert_eq(CareerHub.fighter_card_text(back).find("with a bit of wrestling family") >= 0, true, "the card says it")


func test_a_career_without_a_childhood_starts_from_the_list_as_before() -> void:
	var choices := { "coach": "Sam", "name": "Danny Hill", "background": "track_star", "stance": "orthodox" }
	var c: Career = Career.start(choices, 11, FighterLibrary.load_dir())
	assert_eq(c.about.background, "track_star")
	assert_true(c.childhood.is_empty())
	assert_true(Career.from_dict({ "schema": Career.SCHEMA, "version": Career.VERSION, "fighter": c.fighter, "trainee": c.trainee.snapshot(),
		"calendar": {} }).childhood.is_empty(), "an older save has none")
