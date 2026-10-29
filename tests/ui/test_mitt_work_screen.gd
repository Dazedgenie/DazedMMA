extends GutTest
## The mitt work screen (ui/mitt_work_screen.gd, D137): Space starts it, the keys hit the
## calls, it ends after the last note and hands its quality on (or the auto score if skipped).

var _screen: MittWorkScreen
var _result: Array = []


func before_each() -> void:
	_result = []
	_screen = MittWorkScreen.new(MittWork.new(50.0, 0.0, 1), "Mitt work")
	_screen.finished.connect(func(quality: float, played: bool) -> void: _result = [quality, played])
	add_child_autofree(_screen)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_screen._input(event)


func test_space_starts_the_count_in() -> void:
	assert_false(_screen.running)
	_key(KEY_SPACE)
	assert_true(_screen.running)


func test_number_keys_throw_the_numbered_punches_and_arrows_defend() -> void:
	assert_eq(MittWorkScreen.KEYS[KEY_3], "3")
	assert_eq(MittWorkScreen.KEYS[KEY_LEFT], MittWork.SLIP)
	assert_eq(MittWorkScreen.KEYS[KEY_DOWN], MittWork.ROLL)
	_screen.start()
	var note: Dictionary = _screen.drill.notes[0]
	_screen.tick(float(note.t))
	var keycode: Key = MittWorkScreen.KEYS.find_key(String(note.key))
	_key(keycode)
	assert_eq(_screen.drill.notes[0].result, MittWork.PERFECT)


func test_it_ends_after_the_last_note_and_hands_on_its_quality() -> void:
	_screen.start()
	_screen.tick(_screen.drill.length())
	assert_true(_screen.over)
	assert_true(_screen._done.visible)
	_screen.finish()
	assert_eq(_result, [TrainingCamp.PLAYED_MIN, true], "nothing hit: the bottom score")


func test_skipping_gives_the_auto_score() -> void:
	_screen.skip()
	assert_eq(_result, [TrainingCamp.AUTO_QUALITY, false])


func test_the_sounds_are_made_in_code() -> void:
	var tone := MittWorkScreen._tone(440.0, 0.05, 0.0, 0.5)
	assert_gt(tone.data.size(), 0)
