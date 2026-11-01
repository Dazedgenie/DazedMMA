extends GutTest
## The gameplan pickers (ui/gameplan_picker.gd, D320, docs/01 §42): approach, target and where to fight,
## on the fight setup, the between-rounds panel and the career's fight night card.


func test_it_starts_on_his_own_game_and_gives_back_what_was_picked() -> void:
	var picker: GameplanPicker = autofree(GameplanPicker.new())
	assert_eq(picker.picked(), { "approach": "", "target": "", "where": "" })
	assert_eq(picker.text(), "No plan: he fights his own way.")
	picker.show_plan({ "approach": "counter", "target": "legs" })
	assert_eq(picker.picked(), { "approach": "counter", "target": "legs", "where": "" })
	assert_string_contains(picker.text(), "Counter: Let him lead")
	assert_string_contains(picker.text(), "Legs: Chop the legs")
	picker.pick(Gameplan.WHERE, "clinch_work")
	assert_eq(String(picker.picked().where), "clinch_work")


func test_scouting_says_what_his_corner_will_tell_him() -> void:
	var plan: Dictionary = StyleLibrary.gameplan_of({ "id": "boxer" })
	assert_eq(plan, { "approach": "pressure", "target": "head", "where": "keep_standing" }, "the authored Boxer: the Pressure boxer sheet's plan")
	assert_eq(GameplanPicker.expect_text(plan), "Expect his corner's plan: Pressure · Head · Keep it standing")
	assert_eq(StyleLibrary.gameplan_of({ "id": "x", "style_id": "wrestler" }).where, "wrestle_heavy", "a generated opponent: his style's")
	assert_eq(StyleLibrary.gameplan_of({ "id": "check_red" }), {}, "no sheet: his own game")
	assert_string_contains(FightSetup._scouting_bbcode({}, plan), "Expect his corner's plan")


func test_the_camps_last_instruction_fills_in_the_fight_night_plan() -> void:
	var planner := CampPlanner.new(FighterLibrary.load_dir().profile("wrestler"), 1)
	add_child_autofree(planner)
	planner.plan_start = { "target": "body" }
	planner.pick_preset("wrestler")  # Told to: Take him down.
	planner.run_rest()
	assert_eq(planner.night_card.gameplan.picked(), { "approach": "", "target": "body", "where": "wrestle_heavy" })
