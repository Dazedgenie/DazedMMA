extends GutTest
## The camp planner's fatigue line (ui/fatigue_line.gd, D160, docs/02 §3.10).


func test_it_starts_where_the_week_starts_and_follows_every_session() -> void:
	var line := FatigueLine.new()
	add_child_autofree(line)
	var camp := TrainingCamp.new(FighterLibrary.load_dir().profile("wrestler"), 1)
	var forecast: Dictionary = camp.forecast(TrainingLibrary.shared().plan("speed"))
	line.show_week(forecast)
	assert_eq(line.points.size(), 13)
	assert_almost_eq(line.peak().y, float(forecast.fatigue_peak), 0.001)


func test_in_fight_week_the_last_point_is_the_fight() -> void:
	var line := FatigueLine.new()
	add_child_autofree(line)
	var camp := TrainingCamp.new(FighterLibrary.load_dir().profile("wrestler"), 1)
	line.show_week(camp.forecast(TrainingLibrary.shared().plan("speed"), true))
	assert_true(line.fight_week)
	assert_eq(line.points.size(), 13, "eleven sessions, then the fight as Saturday morning left him")
	assert_eq(line.points[-1], line.points[-2])
