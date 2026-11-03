class_name SprawlReflexScreen
extends Control
## The sprawl reflex minigame on screen (docs/03 §13.5, D411): your fighter and a wrestling partner in the fight screen's
## 3D view, the partner shooting double legs with feints mixed in; Space sprawls. The judging is SprawlReflex
## (sim/world/), with the fight engine as the referee. The drill is drawn in a view of its own (its own 3D world).

## played: false when the player let the session auto-resolve instead.
signal finished(quality: float, played: bool)

const BACKGROUND := Color("#14161b")
const TEXT := Color("#f1f3f5")
const DIM := Color("#8a8f98")
const GOOD := Color("#ffd43b")
const BAD := Color("#ff6b6b")
const FEEDBACK_SECONDS: float = 0.8
const SAYS := {
	SprawlReflex.STUFFED: "Stuffed it!",
	SprawlReflex.TAKEN_DOWN: "Taken down",
	SprawlReflex.BIT: "He sold you the feint",
	SprawlReflex.STRAY: "Nothing there",
}

var drill: SprawlReflex
var driver: FightDriver
var arena: ArenaView
## ready, running, over.
var stage: String = "ready"

var _hint: Label
var _counts: Label
var _feedback: Label
var _feedback_left: float = 0.0
var _skip: Button
var _done: Button


func _init(drill_in: SprawlReflex, title: String) -> void:
	drill = drill_in
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
	FilmStudyScreen._label(box, title, 26, TEXT)
	_hint = FilmStudyScreen._label(box, "", 18, DIM)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0.0, 240.0)
	box.add_child(view)
	var port := SubViewport.new()
	port.own_world_3d = true
	port.handle_input_locally = false
	view.add_child(port)
	arena = ArenaView.new()
	arena.drill = true  # No move names, range tag or referee: reading his level change is the drill.
	port.add_child(arena)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_counts = FilmStudyScreen._label(row, "", 20, TEXT)
	_counts.autowrap_mode = TextServer.AUTOWRAP_OFF
	_feedback = FilmStudyScreen._label(row, "", 22, GOOD)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_OFF
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_skip = CampPlanner._button(buttons, "Skip it (auto, × %.1f)" % TrainingCamp.AUTO_QUALITY, skip)
	_done = CampPlanner._button(buttons, "Done", finish)
	_done.visible = false
	drill.judged.connect(_on_judged)
	_watch()
	_show()


func _ready() -> void:
	arena.watch(driver)
	grab_focus()


## Starts the drill.
func start() -> void:
	if stage != "ready":
		return
	stage = "running"
	_show()


## Lets the session auto-resolve instead (A5: the baseline, never a gate).
func skip() -> void:
	stage = "over"
	finished.emit(TrainingCamp.AUTO_QUALITY, false)


## Hands the session's quality to the camp.
func finish() -> void:
	finished.emit(drill.quality(), true)


## Space: sprawl. True when it went in (not while he's still in one, or getting back up from it).
func sprawl() -> bool:
	return stage == "running" and drill.press()


## The drill's clock ran out.
func end_drill() -> void:
	if stage != "running":
		return
	stage = "over"
	_skip.visible = false
	_done.visible = true
	_done.grab_focus()
	_show()


## Moves the drill on by `delta` real seconds (the screen's frame; tests call it straight).
func run(delta: float) -> void:
	if stage != "running":
		return
	driver.advance(delta * drill.speed / driver.normal_rate)
	if drill.reset_if_due():
		_watch()
		arena.watch(driver)
	if drill.is_over():
		end_drill()
	else:
		_show()


func _watch() -> void:
	driver = FightDriver.new(drill.sim, 0)  # He's red: the sprawl is the player's.
	driver.auto_slow = false
	driver.flourishes = false


func _process(delta: float) -> void:
	run(delta)
	if _feedback_left > 0.0:
		_feedback_left -= delta
		_feedback.modulate.a = clampf(_feedback_left / FEEDBACK_SECONDS, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if key.keycode == KEY_SPACE and stage in ["ready", "running"]:
		if stage == "ready":
			start()
		else:
			sprawl()
		get_viewport().set_input_as_handled()


func _on_judged(what: String) -> void:
	_feedback.text = String(SAYS.get(what, what))
	_feedback.add_theme_color_override("font_color", GOOD if what == SprawlReflex.STUFFED else BAD)
	_feedback.modulate.a = 1.0
	_feedback_left = FEEDBACK_SECONDS


func _show() -> void:
	match stage:
		"ready":
			_hint.text = "Your partner shoots double legs at you, with feints mixed in. Press Space to start, then Space to sprawl as he drops his level for the shot. Sprawl on a feint and he'll shoot while you're still getting back up."
		"running":
			_hint.text = "Space: sprawl. %d s left." % ceili(drill.seconds_left())
		"over":
			_hint.text = "Stuffed %d of %d shots · %d sprawls on nothing · this session counts × %.2f" % [drill.counts[SprawlReflex.STUFFED],
				drill.shots_met(), drill.counts[SprawlReflex.STRAY] + drill.counts[SprawlReflex.BIT], drill.quality()]
	_counts.text = "Stuffed %d · Taken down %d · Bit on a feint %d · Nothing there %d" % [drill.counts[SprawlReflex.STUFFED],
		drill.counts[SprawlReflex.TAKEN_DOWN], drill.counts[SprawlReflex.BIT], drill.counts[SprawlReflex.STRAY]]
