extends GutTest
## BodyDamageFigure: the top bar's damage figure (D150, docs/06 §6).


func test_an_area_runs_green_to_yellow_to_red_as_it_gets_hurt() -> void:
	assert_eq(BodyDamageFigure.damage_colour(0.0), BodyDamageFigure.FRESH)
	assert_eq(BodyDamageFigure.damage_colour(0.5), BodyDamageFigure.HALF)
	assert_eq(BodyDamageFigure.damage_colour(1.0), BodyDamageFigure.DONE)
	var quarter: Color = BodyDamageFigure.damage_colour(0.25)
	assert_almost_eq(quarter.r, (BodyDamageFigure.FRESH.r + BodyDamageFigure.HALF.r) / 2.0, 0.001, "a quarter gone is halfway to yellow")


func test_it_reads_a_fighters_damage_and_whether_hes_rocked() -> void:
	var roster := FighterLibrary.load_dir()
	var f: FighterState = roster.make_pair("wrestler", "kicker")[1]
	f.damage.legs = 250
	f.rocked_ticks = 5
	var figure := BodyDamageFigure.new()
	add_child_autofree(figure)
	figure.show_fighter(f)
	assert_almost_eq(float(figure.hurt.legs), f.hurt("legs"), 0.0001)
	assert_gt(float(figure.hurt.legs), 0.0)
	assert_eq(float(figure.hurt.head), 0.0)
	assert_true(figure.rocked)


func test_a_flash_whitens_the_area_then_fades() -> void:
	var figure := BodyDamageFigure.new()
	add_child_autofree(figure)
	figure.flash("head")
	assert_true(figure.is_flashing("head"))
	assert_eq(figure.area_colour("head"), Color.WHITE, "fully white the moment it lands")
	assert_eq(figure.area_colour("body"), BodyDamageFigure.FRESH)
	figure._process(BodyDamageFigure.FLASH_SECONDS)
	assert_false(figure.is_flashing("head"))
	assert_eq(figure.area_colour("head"), BodyDamageFigure.FRESH)


func test_a_rocked_head_pulses() -> void:
	var figure := BodyDamageFigure.new()
	add_child_autofree(figure)
	figure.rocked = true
	figure._process(BodyDamageFigure.PULSE_SECONDS / 2.0)
	assert_almost_eq(figure.area_colour("head").a, BodyDamageFigure.PULSE_LOW, 0.001, "faintest halfway through a beat")
	assert_eq(figure.area_colour("body").a, 1.0, "only the head pulses")
