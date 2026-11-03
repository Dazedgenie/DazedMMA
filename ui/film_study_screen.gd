class_name FilmStudyScreen
extends Control
## The film study minigame on screen (docs/03 §13.4, D410): a minute of the man's tape in the fight screen's 3D view,
## sped up, with Space marking each time you think his habit just went off; then his habit named from three. The
## judging is FilmStudy (sim/world/). The tape is drawn in a view of its own (its own 3D world), with no tell cues.

## played: false when the player let the session auto-resolve instead. found: the habit's key it found, or "".
signal finished(quality: float, played: bool, found: String)

const BACKGROUND := Color("#14161b")
const TEXT := Color("#f1f3f5")
const DIM := Color("#8a8f98")
const HIT := Color("#ffd43b")
const STRAY := Color("#ff6b6b")
const NEAR := Color("#4dabf7")
const FEEDBACK_SECONDS: float = 0.7

var study: FilmStudy
var sim: FightSim
var driver: FightDriver
var arena: ArenaView
## watching (the tape), naming (pick his habit), over (the score).
var stage: String = "ready"

var _title: Label
var _hint: Label
var _marks: Label
var _feedback: Label
var _feedback_left: float = 0.0
var _view: SubViewportContainer
var _names: VBoxContainer
var _skip: Button
var _done: Button


func _init(study_in: FilmStudy, title: String, roster: FighterLibrary = null, actions: ActionLibrary = null) -> void:
	study = study_in
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24.0
	box.offset_right = -24.0
	box.offset_top = 16.0
	box.offset_bottom = -16.0
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = _label(box, title, 26, TEXT)
	_hint = _label(box, "", 18, DIM)
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(0.0, 240.0)
	box.add_child(_view)
	var port := SubViewport.new()
	port.own_world_3d = true
	port.handle_input_locally = false
	_view.add_child(port)
	sim = study.make_sim(roster, actions)
	while sim.now < study.start and not sim.is_over():
		sim.tick()
	driver = FightDriver.new(sim, 1)  # He's red; nothing is the player's to call.
	arena = ArenaView.new()
	port.add_child(arena)
	arena.tell_watch = Scouting.Watch.new([])  # No cues: spotting it is the game.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_marks = _label(row, "", 20, TEXT)
	_marks.autowrap_mode = TextServer.AUTOWRAP_OFF
	_feedback = _label(row, "", 22, HIT)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_OFF
	_names = VBoxContainer.new()
	_names.add_theme_constant_override("separation", 6)
	_names.visible = false
	box.add_child(_names)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_skip = CampPlanner._button(buttons, "Skip it (auto, × %.1f)" % TrainingCamp.AUTO_QUALITY, skip)
	_done = CampPlanner._button(buttons, "Done", finish)
	_done.visible = false
	_show()


func _ready() -> void:
	arena.watch(driver)
	grab_focus()


## Starts the tape.
func start() -> void:
	if stage != "ready":
		return
	stage = "watching"
	_show()


## Lets the session auto-resolve instead (A5: the baseline, never a gate).
func skip() -> void:
	stage = "over"
	finished.emit(TrainingCamp.AUTO_QUALITY, false, "")


## Hands the session's quality, and the habit it found, to the camp.
func finish() -> void:
	finished.emit(study.quality(), true, study.found_key())


## Space: he's just done it.
func mark() -> Dictionary:
	if stage != "watching":
		return {}
	var judged: Dictionary = study.press(sim.now)
	match String(judged.result):
		"hit":
			_flash("That's it!", HIT)
		"near":
			_flash("One of his habits, not this one", NEAR)
		_:
			_flash("Nothing there", STRAY)
	_show()
	return judged


## Names his habit as choice `index`.
func name_it(index: int) -> void:
	if stage != "naming":
		return
	var right: bool = study.name_it(index)
	stage = "over"
	_names.visible = false
	_skip.visible = false
	_done.visible = true
	_done.grab_focus()
	_flash("Right: that's his habit." if right else "Not that one: it was %s." % habit_text(study.habit), HIT if right else STRAY)
	_show()


## The tape has run out: name his habit.
func end_tape() -> void:
	if stage != "watching":
		return
	stage = "naming"
	for c in _names.get_children():
		c.queue_free()
	_label(_names, "What's his habit?", 20, TEXT)
	for i in study.choices.size():
		var n: int = i
		var b: Button = CampPlanner._button(_names, "%d. %s" % [i + 1, habit_text(study.choices[i])], func() -> void: name_it(n))
		b.add_theme_font_size_override("font_size", 20)
	_names.visible = true
	_show()


## A habit in words without its numbers: "When his jab is blocked, he throws a body kick".
static func habit_text(tell: Dictionary) -> String:
	return Scouting.tell_text(tell).split(" (")[0]


func _process(delta: float) -> void:
	if stage == "watching":
		driver.advance(delta * FilmStudy.SPEED / driver.normal_rate)  # SPEED × fight time, slow-mo on a big shot kept.
		if sim.now >= study.end or sim.is_over():
			end_tape()
		else:
			_show()
	if _feedback_left > 0.0:
		_feedback_left -= delta
		_feedback.modulate.a = clampf(_feedback_left / FEEDBACK_SECONDS, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if key.keycode == KEY_SPACE and stage in ["ready", "watching"]:
		if stage == "ready":
			start()
		else:
			mark()
		get_viewport().set_input_as_handled()
	elif stage == "naming" and key.keycode in [KEY_1, KEY_2, KEY_3]:
		name_it(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()


func _show() -> void:
	match stage:
		"ready":
			_hint.text = "%s against a %s. Press Space to start the tape, then Space each time you think his habit just went off: a move he always throws after the same moment." % [
				String(study.him.get("name", "Him")), String(study.stand_in).replace("_", " ")]
		"watching":
			var left: float = maxf(0.0, float(study.end - sim.now) / FightClock.TICKS_PER_SECOND / FilmStudy.SPEED)
			_hint.text = "Space: he just did it. %d s of tape left." % ceili(left)
		"naming":
			_hint.text = "Pick his habit (1–3)."
		"over":
			_hint.text = "Caught %d of %d · %d stray · %s: this session counts × %.2f%s" % [study.caught(), study.fires.size(),
				study.strays(), "named it" if study.named_right() else "named it wrong", study.quality(),
				" · habit found" if study.found_key() != "" else ""]
	_marks.text = "Marked: %d" % (study.caught() + study.strays())


func _flash(text: String, colour: Color) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", colour)
	_feedback.modulate.a = 1.0
	_feedback_left = FEEDBACK_SECONDS


static func _label(parent: Control, text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	parent.add_child(l)
	return l
