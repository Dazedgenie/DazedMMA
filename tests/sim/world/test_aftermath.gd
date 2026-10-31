extends GutTest
## What a fight does to him afterwards (sim/world/aftermath.gd, docs/03 §10.5, D305): the medical suspension and the
## Chin a knockout takes for good.


func _career() -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"background": "wrestling_family", "stance": "orthodox" }, 1, FighterLibrary.load_dir())


func test_a_knockout_loss_costs_the_most() -> void:
	assert_eq(Aftermath.of("loss", "KO", false), { "days": 60, "chin": 1.0, "why": "a KO loss" })
	assert_eq(Aftermath.of("loss", "TKO", true), { "days": 30, "chin": 0.5, "why": "a TKO loss" })
	assert_eq(int(Aftermath.of("win", "KO", true).days), Aftermath.HARD_DAYS, "a hard win")
	assert_eq(float(Aftermath.of("win", "KO", true).chin), 0.0, "only a knockout loss costs Chin")
	assert_eq(int(Aftermath.of("loss", "Submission", false).days), Aftermath.OTHER_DAYS)
	assert_eq(int(Aftermath.of("draw", "Split decision", false).days), Aftermath.OTHER_DAYS)


func test_a_hard_fight_is_a_knockdown_or_a_lot_of_damage() -> void:
	assert_true(Aftermath.is_hard(0.1, 0.1, 1), "knocked down")
	assert_true(Aftermath.is_hard(Aftermath.HARD_HEAD, 0.0, 0), "hurt to the head")
	assert_true(Aftermath.is_hard(0.0, Aftermath.HARD_BODY, 0), "hurt to the body")
	assert_false(Aftermath.is_hard(0.2, 0.3, 0))


func test_a_ko_loss_suspends_him_from_fight_night_and_takes_chin() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	var o: Dictionary = c.offers[0]
	c.accept(String(o.id))
	while c.week < int(o.week):
		c.end_week()
	var chin: float = c.trainee.stat("chin")
	c.finish_fight({ "result": "loss", "method": "KO", "round": 2 })
	assert_eq(c.suspended_days, Aftermath.KO_DAYS - Career.FIGHT_TO_MONDAY, "counted from Saturday")
	assert_almost_eq(c.trainee.stat("chin"), chin - Aftermath.KO_CHIN, 0.0001)
	assert_eq(int(c.fights[-1].suspension_days), Aftermath.KO_DAYS)
	assert_eq(String(c.fights[-1].suspension_why), "a KO loss")
	var cleared: bool = false
	for w: Dictionary in c.calendar(9):
		for e: Dictionary in w.events:
			cleared = cleared or e.kind == Career.CLEARED
	assert_true(cleared, "the calendar says when he's cleared")
	c.run_week("time_off")
	c.run_week("time_off")
	assert_true(c.offers.is_empty(), "no offers while he's suspended")


func test_an_easy_win_is_a_week_off() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	c.accept(String(c.offers[0].id))
	c.finish_fight({ "result": "win", "method": "Unanimous decision", "round": 3 })
	assert_eq(c.suspended_days, Aftermath.OTHER_DAYS - Career.FIGHT_TO_MONDAY)
	assert_eq(float(c.fights[-1].chin_lost), 0.0)
