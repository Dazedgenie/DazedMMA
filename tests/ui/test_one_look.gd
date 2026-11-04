extends GutTest
## One look off the fight (docs/06 §6.15, D435): the dimmed hall behind every screen off the fight, one button style
## (ui/off_cage.gd), the quick fade from one screen to the next, and the camp's stat names whole.

const SAVE_DIR := "user://test_one_look_saves/"


func test_a_button_is_dark_and_edged_in_red_on_hover_and_under_the_keyboard() -> void:
	var b := Button.new()
	b.text = "Run this week"
	OffCage.style_button(b)
	var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
	var hover := b.get_theme_stylebox("hover") as StyleBoxFlat
	var focus := b.get_theme_stylebox("focus") as StyleBoxFlat
	assert_eq(normal.bg_color, OffCage.BUTTON, "dark")
	assert_eq(normal.border_width_left, 0, "no edge until the mouse is on it")
	assert_eq(hover.border_color, OffCage.EDGE, "red on hover")
	assert_gt(hover.border_width_left, 0)
	assert_eq(focus.border_color, OffCage.EDGE, "red under the keyboard too")
	assert_false(focus.draw_center, "focus only draws the edge")
	assert_true(b.has_theme_font_override("font"), "a short label in the display font")
	var long := Button.new()
	long.text = "Run every week left like this one, and then some"
	OffCage.style_button(long)
	assert_false(long.has_theme_font_override("font"), "a long one stays readable")
	b.free()
	long.free()


func test_a_tab_thats_down_is_lit_and_underlined_and_tick_boxes_keep_their_look() -> void:
	var theme: Theme = OffCage.theme()
	assert_eq(OffCage.theme(), theme, "one theme, made once")
	var down := theme.get_stylebox("pressed", "Button") as StyleBoxFlat
	assert_eq(down.bg_color, OffCage.BUTTON_ON, "lit")
	assert_eq(down.border_width_bottom, OffCage.ON_LINE, "underlined")
	assert_eq(down.border_color, OffCage.EDGE)
	var picker := theme.get_stylebox("normal", "OptionButton") as StyleBoxFlat
	assert_lte(picker.content_margin_top, 4.0, "pickers stay low so the pages still fit")
	var plain: Theme = ThemeDB.get_default_theme()
	assert_eq(theme.get_stylebox("normal", "CheckBox"), plain.get_stylebox("normal", "CheckBox"), "tick boxes as they were")


func test_the_hall_shows_through_a_screen_but_not_through_a_page_laid_over_one() -> void:
	assert_lt(OffCage.hall_panel().bg_color.a, 1.0, "the hall shows through")
	assert_gt(OffCage.hall_panel().bg_color.a, 0.5, "dark enough to read over")
	assert_eq(OffCage.hall_panel(true).bg_color.a, 1.0, "the world pages over the hub are solid")


func test_the_empty_hall_drifts_round_slowly_and_stands_still_without_it() -> void:
	var arena: ArenaView = add_child_autofree(ArenaView.new())
	arena.watch(null)
	arena._process(1.0)
	assert_eq(arena.camera_swing, 0.0, "no drift unless asked")
	arena.hall_drift = true
	arena._process(1.0)
	var first: float = arena.camera_swing
	arena._process(1.0)
	assert_almost_eq(arena.camera_swing - first, ArenaView.HALL_TURN_SPEED, 0.001, "turning slowly round")
	var far: float = Vector2(arena.camera.position.x, arena.camera.position.z).length()
	arena.hall_drift = false
	arena._place_camera(1.0)
	assert_gt(far, Vector2(arena.camera.position.x, arena.camera.position.z).length(), "pulled back to take in the seats")


func test_every_screen_off_the_fight_sits_over_the_empty_hall_and_fades_up() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	add_child_autofree(main)
	main.save_dir = SAVE_DIR
	for screen: Control in [main.setup, main.title, main.new_career, main.childhood, main.gym_screen, main.load_screen,
			main.hub, main.result, main.world_page]:
		assert_eq(screen.theme, OffCage.theme(), "%s has the look" % screen.name)
	main.open_new_career()
	assert_null(main.arena.driver, "the empty cage")
	assert_true(main.arena.hall_drift, "the camera drifting round it")
	assert_eq(main._veil.color.a, 1.0, "the new screen starts in the dark")
	await wait_seconds(OffCage.FADE_SECONDS + 0.15)
	assert_eq(main._veil.color.a, 0.0, "and comes up out of it")
	var s: Dictionary = main.setup.settings()
	s.seed = 3
	main.start_fight(s)
	assert_eq(main.arena.driver, main.driver, "a real fight has the cage")


func test_the_camps_stat_names_fit_whole() -> void:
	var bars: StatBars = add_child_autofree(StatBars.new())
	var rows: Array[Dictionary] = [{ "name": "Submission defense", "value": 30.0, "grade": "D" }]
	bars.show_rows(rows)
	var font: Font = bars.get_theme_default_font()
	var needed: float = font.get_string_size("Submission defense", HORIZONTAL_ALIGNMENT_LEFT, -1, StatBars.FONT_SIZE).x
	assert_gt(bars.name_width(font) - 12.0 - 8.0, needed - 0.5, "the whole name before the bar")
	var short: Array[Dictionary] = [{ "name": "Chin", "value": 30.0, "grade": "D" }]
	bars.show_rows(short)
	assert_eq(bars.name_width(font), StatBars.NAME_W, "short names keep the usual column")
