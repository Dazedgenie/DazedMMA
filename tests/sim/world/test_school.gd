extends GutTest
## School weeks (sim/world/school.gd, docs/03 §11.4, D314): until he's 18, term time takes his weekday mornings; the
## summer holidays give him full weeks.


func _career(age: int = 16, career_seed: int = 3) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = age
	p.potential = 80
	var c: Career = Career.create(p, career_seed, { "coach": "Sam", "hometown": "Leeds", "country": "England" })
	c.next_offers_week = 1000  # No fight offers to get in the way.
	return c


func _total(gains: Dictionary) -> float:
	var out: float = 0.0
	for id: String in gains:
		out += float(gains[id])
	return out


func _kinds(report: Dictionary) -> Array:
	return report.events.map(func(e: Dictionary) -> String: return String(e.kind))


func test_a_school_week_keeps_his_weekday_mornings_for_school() -> void:
	var c: Career = _career()
	assert_true(School.school_week(c), "a January week at 16 is term time")
	assert_eq(c.trainee.taken.keys(), [0, 2, 4, 6, 8], "Monday to Friday mornings")
	var plan: Dictionary = TrainingLibrary.shared().plan("striker")
	var forecast: Dictionary = c.trainee.forecast(plan)
	for slot: Dictionary in forecast.slots:
		var index: int = int(slot.day) * TrainingCamp.SLOTS_PER_DAY + int(slot.slot)
		if index in School.SLOTS:
			assert_eq(String(slot.session), School.SESSION, "slot %d is school" % index)
		else:
			assert_eq(String(slot.session), String(plan.days[slot.day][slot.slot]), "slot %d is his to train" % index)
	assert_ne(String(plan.days[0][0]), School.SESSION, "the plan itself doesn't change")
	assert_eq(School.sessions_left(), 7)
	assert_string_contains(School.week_line(c), "trains 7 of the 12 sessions")
	assert_string_contains(CareerHub.week_text(c), "School week")
	var at_school: Dictionary = c.run_week("striker")
	var left: Career = _career(18)
	assert_true(left.trainee.taken.is_empty(), "at 18 he's left school")
	var full: Dictionary = left.run_week("striker")
	assert_lt(_total(at_school.gains), _total(full.gains), "school weeks teach him less")
	assert_lt(int(at_school.done), int(full.done))


func test_the_summer_holidays_give_him_full_weeks() -> void:
	var c: Career = _career()
	c.week = 21  # Mon 31 May 2027.
	var ahead: Array[Dictionary] = c.calendar()
	assert_true(Career.SCHOOL_OUT in ahead[4].events.map(func(e: Dictionary) -> String: return String(e.kind)),
		"the calendar shows the summer coming: Mon 28 Jun is the last school week")
	c.week = 25
	var june: Dictionary = c.run_week("time_off")
	assert_eq(c.date_text(), "Mon 5 Jul 2027")
	assert_true(Career.SCHOOL_OUT in _kinds(june), "school's out: Advance stops for it")
	assert_true(c.trainee.taken.is_empty(), "every session is his")
	assert_string_contains(School.week_line(c), "Summer holidays")
	c.week = 34  # Mon 30 Aug: the last week of the holidays.
	var august: Dictionary = c.run_week("time_off")
	assert_true(Career.BACK_TO_SCHOOL in _kinds(august))
	assert_eq(c.trainee.taken.size(), School.SLOTS.size(), "mornings at school again from Mon 6 Sep")
	assert_ne(Career.event_text({ "kind": Career.SCHOOL_OUT }), Career.SCHOOL_OUT)


func test_he_leaves_school_on_his_18th_birthday() -> void:
	var c: Career = _career(17)
	c.trainee.age_years = 18.0 - 0.5 / Ageing.WEEKS_PER_YEAR  # Half a week short of 18.
	assert_true(School.at_school(c))
	var report: Dictionary = c.run_week("time_off")
	assert_eq(c.age(), 18)
	assert_true(Career.LEFT_SCHOOL in _kinds(report))
	assert_true(c.trainee.taken.is_empty())
	assert_eq(School.week_line(c), "", "nothing to say about school once he's left")


func test_school_comes_back_with_a_saved_career() -> void:
	var c: Career = _career()
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.trainee.taken, c.trainee.taken, "worked out again from the calendar and his age")
	assert_false(c.to_dict().has("taken"), "nothing new in the save")
