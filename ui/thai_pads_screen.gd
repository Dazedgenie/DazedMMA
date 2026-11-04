class_name ThaiPadsScreen
extends Control
## The Thai pads minigame on screen (docs/03 §13.7, D413): the pad holder drawn facing him, his pads moving to where he
## wants each strike, and a ring round the pad running down until he drops it. Keys 1–5 throw the strike the pad asks for
## (1 head kick, 2 elbow, 3 body kick, 4 knee, 5 low kick) and Space checks his kick back. A smack on every strike that
## lands and a whoosh on one that doesn't, made in code. The judging is ThaiPads (sim/world/).

## played: false when the player let the session auto-resolve instead.
signal finished(quality: float, played: bool)

const KEYS := {
	KEY_1: ThaiPads.HEAD_KICK, KEY_2: ThaiPads.ELBOW, KEY_3: ThaiPads.BODY_KICK, KEY_4: ThaiPads.KNEE, KEY_5: ThaiPads.LOW_KICK,
	KEY_KP_1: ThaiPads.HEAD_KICK, KEY_KP_2: ThaiPads.ELBOW, KEY_KP_3: ThaiPads.BODY_KICK, KEY_KP_4: ThaiPads.KNEE,
	KEY_KP_5: ThaiPads.LOW_KICK, KEY_SPACE: ThaiPads.CHECK,
}
## The key shown beside each pad's place.
const LABELS := { "head_kick": "1", "elbow": "2", "body_kick": "3", "knee": "4", "low_kick": "5", "check": "Space" }
const LEGEND := "1 head kick · 2 elbow · 3 body kick · 4 knee · 5 low kick · Space check his kick · quicker is better"

const BACKGROUND := Color("#14161b")
const TEXT := Color("#f1f3f5")
const DIM := Color("#8a8f98")
const SKIN := Color("#b98a6a")
const SHORTS := Color("#1c7ed6")
const SHIRT := Color("#343a40")
const PAD := Color("#c92a2a")
const PAD_IDLE := Color("#5c2b2b")
const PERFECT_COLOUR := Color("#ffd43b")
const GOOD_COLOUR := Color("#69db7c")
const BAD := Color("#ff6b6b")
const FEEDBACK_SECONDS: float = 0.6
const HIT_SECONDS: float = 0.18

var drill: ThaiPads
var running: bool = false
var over: bool = false
var now: float = 0.0

var _title: String
var _feedback: String = ""
var _feedback_colour: Color = TEXT
var _feedback_left: float = 0.0
var _hit_left: float = 0.0
var _hit_at: Vector2 = Vector2.ZERO
var _hint: Label
var _skip: Button
var _done: Button
var _smack: AudioStreamPlayer
var _whoosh: AudioStreamPlayer


func _init(drill_in: ThaiPads, title: String) -> void:
	drill = drill_in
	_title = title
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-500.0, 96.0)
	_hint.size = Vector2(1000.0, 32.0)
	add_child(_hint)
	var buttons := HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.position = Vector2(-560.0, -72.0)
	buttons.size = Vector2(520.0, 48.0)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	_skip = CampPlanner._button(buttons, "Skip it (auto, × %.1f)" % TrainingCamp.AUTO_QUALITY, skip)
	_done = CampPlanner._button(buttons, "Done", finish)
	_done.visible = false
	_smack = _player(MittWorkScreen._tone(160.0, 0.08, 0.8, 0.85))
	_whoosh = _player(MittWorkScreen._tone(600.0, 0.12, 0.95, 0.35))
	_show_hint()


func _ready() -> void:
	grab_focus()


## Starts the round (the count-in first).
func start() -> void:
	if running or over:
		return
	running = true
	_show_hint()
	tick(0.0)


## Lets the session auto-resolve instead (A5: the baseline, never a gate).
func skip() -> void:
	running = false
	over = true
	finished.emit(TrainingCamp.AUTO_QUALITY, false)


## Hands the round's quality to the camp.
func finish() -> void:
	finished.emit(drill.quality(), true)


## Moves the round to `at` seconds: a pad he drops unhit is a miss, and the round ends as the last one drops.
func tick(at: float) -> void:
	if not running:
		return
	now = at
	if drill.miss_late(now) > 0:
		_flash("Too slow: he dropped it", BAD)
	if drill.is_over(now):
		running = false
		over = true
		_skip.visible = false
		_done.visible = true
		_done.grab_focus()
		_show_hint()
	queue_redraw()


## A strike (a ThaiPads.STRIKES id or CHECK) thrown now.
func strike(key: String) -> Dictionary:
	if not running:
		return {}
	var pad: Dictionary = drill.pad_at(now)
	var out: Dictionary = drill.press(key, now)
	match String(out.result):
		ThaiPads.PERFECT:
			_flash("Perfect!" if key != ThaiPads.CHECK else "Checked!", PERFECT_COLOUR)
		ThaiPads.GOOD:
			_flash("Good, a touch slow", GOOD_COLOUR)
		ThaiPads.MISS:
			_flash("Wrong one: he wanted %s" % _wanted(String(pad.key)), BAD)
		_:
			_flash("Nothing there", DIM)
	if String(out.result) in [ThaiPads.PERFECT, ThaiPads.GOOD]:
		_hit_left = HIT_SECONDS
		_hit_at = _spot(key)
		_play(_smack)
	else:
		_play(_whoosh)
	queue_redraw()
	return out


func _process(delta: float) -> void:
	if running:
		tick(now + delta)  # Frame time, so a recording at a fixed frame rate keeps time too.
	if _feedback_left > 0.0 or _hit_left > 0.0:
		_feedback_left -= delta
		_hit_left -= delta
		queue_redraw()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree() or not KEYS.has(key.keycode):
		return
	if not running and not over:
		if key.keycode == KEY_SPACE:
			start()
	else:
		strike(KEYS[key.keycode])
	get_viewport().set_input_as_handled()


func _wanted(key: String) -> String:
	return "a check" if key == ThaiPads.CHECK else ("an elbow" if key == ThaiPads.ELBOW else "a " + String(ThaiPads.NAMES[key]))


func _show_hint() -> void:
	if over:
		_hint.text = "%d pads: %d perfect, %d good, %d missed, %d thrown at nothing · this session counts × %.2f" % [
			drill.pads.size(), drill.counts[ThaiPads.PERFECT], drill.counts[ThaiPads.GOOD], drill.counts[ThaiPads.MISS],
			drill.counts.stray, drill.quality()]
	elif running:
		_hint.text = ""
	else:
		_hint.text = "Press Space to start. Then throw what each pad asks for before he drops it."


func _flash(text: String, colour: Color) -> void:
	_feedback = text
	_feedback_colour = colour
	_feedback_left = FEEDBACK_SECONDS


## The holder's middle (between his hips) on screen, and how big he's drawn (his drawing is made for a 720-high
## screen and scaled to this one).
func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.55)


func _scale() -> float:
	return size.y / 720.0


## Where each pad is held (and where a strike at it lands), from the holder's middle, in his drawing's units.
func _spot(key: String) -> Vector2:
	var c := Vector2.ZERO
	match key:
		ThaiPads.HEAD_KICK:
			return c + Vector2(-95.0, -210.0)
		ThaiPads.ELBOW:
			return c + Vector2(0.0, -205.0)
		ThaiPads.BODY_KICK:
			return c + Vector2(-85.0, -95.0)
		ThaiPads.KNEE:
			return c + Vector2(0.0, -30.0)
		ThaiPads.LOW_KICK:
			return c + Vector2(-38.0, 70.0)
		_:
			return c + Vector2(70.0, 60.0)  # His kick back comes off his rear leg.


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_string(font, Vector2(40.0, 56.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, TEXT)
	var left: float = maxf(0.0, drill.length() - now) if running else (drill.length() if not over else 0.0)
	draw_string(font, Vector2(40.0, 88.0), "Kicking %d · a pad stays up %.2f s%s · %d s left" % [roundi(drill.kicking),
		drill.open, " · combinations of up to %d" % drill.most_in_a_set() if drill.most_in_a_set() > 1 else "",
		ceili(left)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	var pad: Dictionary = drill.pad_at(now) if running else {}
	_draw_holder(font, pad)
	var line: String = "Perfect %d · good %d · missed %d · thrown at nothing %d" % [drill.counts[ThaiPads.PERFECT],
		drill.counts[ThaiPads.GOOD], drill.counts[ThaiPads.MISS], drill.counts.stray]
	draw_string(font, Vector2(40.0, size.y - 140.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, TEXT)
	draw_string(font, Vector2(40.0, size.y - 104.0), LEGEND, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	if running and now < ThaiPads.COUNT_IN:
		draw_string(font, Vector2(0.0, _centre().y - 300.0 * _scale()), "Ready…", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, TEXT)
	if _feedback_left > 0.0:
		var colour := _feedback_colour
		colour.a = clampf(_feedback_left / FEEDBACK_SECONDS, 0.0, 1.0)
		draw_string(font, _centre() + Vector2(170.0, -150.0) * _scale(), _feedback, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, colour)


## The holder facing him: his body, his pads where the pad up wants them (held at his chest between pads), his rear
## leg coming up when he kicks back, the faint key beside each pad's place, and the ring running down on the pad up.
func _draw_holder(font: Font, pad: Dictionary) -> void:
	draw_set_transform(_centre(), 0.0, Vector2.ONE * _scale())
	var c := Vector2.ZERO
	var key: String = String(pad.get("key", ""))
	var kicking_back: bool = key == ThaiPads.CHECK
	# Legs: the lead leg (screen left) planted; the rear leg up and out when he kicks back.
	draw_line(c + Vector2(-25.0, 0.0), c + Vector2(-45.0, 165.0), SKIN, 30.0)
	if kicking_back:
		draw_line(c + Vector2(25.0, 0.0), c + Vector2(95.0, 70.0), SKIN, 30.0)
		draw_line(c + Vector2(95.0, 70.0), c + Vector2(80.0, 150.0), SKIN, 26.0)
	else:
		draw_line(c + Vector2(25.0, 0.0), c + Vector2(45.0, 165.0), SKIN, 30.0)
	draw_rect(Rect2(c + Vector2(-50.0, -20.0), Vector2(100.0, 60.0)), SHORTS)
	draw_rect(Rect2(c + Vector2(-55.0, -170.0), Vector2(110.0, 155.0)), SHIRT)
	draw_circle(c + Vector2(0.0, -205.0), 34.0, SKIN)
	# Each place a pad can go, with its key, faint.
	for k: String in ThaiPads.STRIKES + [ThaiPads.CHECK]:
		var at: Vector2 = _spot(k)
		var label_at: Vector2 = at + (Vector2(-75.0, 6.0) if at.x <= c.x else Vector2(75.0, 6.0))
		draw_string(font, label_at, LABELS[k], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM if k != key else TEXT)
	# The pads: both at his chest when none is up, else where this one wants the strike.
	var rest_l := c + Vector2(-40.0, -120.0)
	var rest_r := c + Vector2(40.0, -120.0)
	var colour: Color = PAD if key != "" else PAD_IDLE
	# Each hand's pad: where it is, how big, and whether it's the one asking for a strike.
	var left := [rest_l, Vector2(40.0, 70.0), PAD_IDLE]
	var right := [rest_r, Vector2(40.0, 70.0), PAD_IDLE]
	match key:
		ThaiPads.HEAD_KICK:
			left = [_spot(key), Vector2(46.0, 90.0), colour]
		ThaiPads.ELBOW:
			left = [_spot(key) + Vector2(0.0, 10.0), Vector2(90.0, 46.0), colour]
			right = [rest_r + Vector2(0.0, 30.0), Vector2(40.0, 70.0), PAD_IDLE]
		ThaiPads.BODY_KICK:
			left = [_spot(key), Vector2(46.0, 90.0), colour]
		ThaiPads.KNEE:
			left = [_spot(key) + Vector2(-26.0, 0.0), Vector2(44.0, 80.0), colour]
			right = [_spot(key) + Vector2(26.0, 0.0), Vector2(44.0, 80.0), colour]
	draw_line(c + Vector2(-52.0, -160.0), left[0], SKIN, 16.0)
	draw_line(c + Vector2(52.0, -160.0), right[0], SKIN, 16.0)
	_pad(left[0], left[1], left[2])
	_pad(right[0], right[1], right[2])
	if key == ThaiPads.LOW_KICK:
		_pad(_spot(key), Vector2(44.0, 70.0), colour)  # The thigh pad strapped on his lead leg.
	if kicking_back:
		draw_string(font, _spot(key) + Vector2(75.0, -30.0), "Check!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, BAD)
	# The ring running down on the pad up: gold while a strike would be perfect, green after.
	if key != "":
		var share: float = clampf((now - float(pad.t)) / (float(pad.until) - float(pad.t)), 0.0, 1.0)
		var ring: Color = PERFECT_COLOUR if share <= ThaiPads.PERFECT_SHARE else GOOD_COLOUR
		draw_arc(_spot(key), 62.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - share), 40, ring, 6.0)
	if _hit_left > 0.0:
		var a: float = clampf(_hit_left / HIT_SECONDS, 0.0, 1.0)
		draw_circle(_hit_at, 30.0 + 30.0 * (1.0 - a), Color(1.0, 0.95, 0.7, 0.6 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pad(at: Vector2, extent: Vector2, colour: Color) -> void:
	draw_rect(Rect2(at - extent * 0.5, extent), colour)
	draw_rect(Rect2(at - extent * 0.5, extent), colour.darkened(0.4), false, 3.0)


func _play(player: AudioStreamPlayer) -> void:
	if player.is_inside_tree():
		player.play()


func _player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	return player
