class_name MittWorkScreen
extends Control
## The mitt work minigame on screen (docs/02 §3.9, D137): the coach's two mitts, the call
## he shouts ("1-2-3!"), and a beat track with each hit sliding in to the hit line. Keys 1–6
## throw boxing's numbered punches, ← slips and ↓ rolls. A click on every beat and a smack on
## every hit are made in code (no audio files yet). The judging is MittWork (sim/world/).

## played: false when the player let the session auto-resolve instead.
signal finished(quality: float, played: bool)

const KEYS := {
	KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4", KEY_5: "5", KEY_6: "6",
	KEY_KP_1: "1", KEY_KP_2: "2", KEY_KP_3: "3", KEY_KP_4: "4", KEY_KP_5: "5", KEY_KP_6: "6",
	KEY_LEFT: MittWork.SLIP, KEY_A: MittWork.SLIP, KEY_DOWN: MittWork.ROLL, KEY_S: MittWork.ROLL,
}
## What each key shows on its note.
const LABELS := { "1": "1", "2": "2", "3": "3", "4": "4", "5": "5", "6": "6", "slip": "←", "roll": "↓" }
const LEGEND := "1 jab · 2 cross · 3 lead hook · 4 rear hook · 5 lead uppercut · 6 rear uppercut · ← slip · ↓ roll"

const BACKGROUND := Color("#14161b")
const LANE := Color("#22262e")
const TICK := Color("#3a404a")
const LEAD := Color("#4dabf7")  # Odd numbers: the lead hand.
const REAR := Color("#ff922b")  # Even numbers: the rear hand.
const DEFENCE := Color("#69db7c")
const PERFECT := Color("#ffd43b")
const MISSED := Color("#ff6b6b")
const MITT := Color("#c92a2a")
const TEXT := Color("#f1f3f5")
const DIM := Color("#8a8f98")
## How fast notes slide in, and where the hit line sits on the track.
const PIXELS_PER_SECOND: float = 360.0
const HIT_LINE_X: float = 160.0
const NOTE_RADIUS: float = 26.0
const FEEDBACK_SECONDS: float = 0.5
## A mitt lights up this many beats before it wants hitting.
const MITT_LEAD_BEATS: float = 0.75

var drill: MittWork
var running: bool = false
var over: bool = false
var now: float = 0.0  # Seconds since the start (the count-in included).

var _title: String
var _start_usec: int = 0
var _beats_clicked: int = -1
var _feedback: String = ""
var _feedback_colour: Color = TEXT
var _feedback_left: float = 0.0
var _hint: Label
var _skip: Button
var _done: Button
var _click: AudioStreamPlayer
var _smack: AudioStreamPlayer


func _init(drill_in: MittWork, title: String) -> void:
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
	_click = _player(_tone(1500.0, 0.03, 0.0, 0.35))
	_smack = _player(_tone(180.0, 0.07, 0.8, 0.8))
	_show_hint()


func _ready() -> void:
	grab_focus()


## Starts the round: four beats of count-in, then the coach's first call.
func start() -> void:
	if running or over:
		return
	running = true
	_hint.text = ""
	_start_usec = Time.get_ticks_usec()
	tick(0.0)


## Lets the session auto-resolve instead (A5: the baseline, never a gate).
func skip() -> void:
	running = false
	over = true
	finished.emit(TrainingCamp.AUTO_QUALITY, false)


## Hands the round's quality to the camp.
func finish() -> void:
	finished.emit(drill.quality(), true)


## Moves the round to `at` seconds: clicks the beats, misses what went by, ends it after the last note.
func tick(at: float) -> void:
	if not running:
		return
	now = at
	var beat_index: int = floori(now / drill.beat)
	if beat_index > _beats_clicked:
		_beats_clicked = beat_index
		_play(_click)
	if drill.miss_late(now) > 0:
		_flash("Miss", MISSED)
	if now >= drill.length():
		running = false
		over = true
		_skip.visible = false
		_done.visible = true
		_done.grab_focus()
		_show_hint()
	queue_redraw()


## A key press (MittWork key) at the current time.
func hit(key: String) -> Dictionary:
	var judged: Dictionary = drill.press(key, now)
	match String(judged.result):
		MittWork.PERFECT:
			_flash("Perfect!", PERFECT)
			_play(_smack)
		MittWork.GOOD:
			_flash("Good", TEXT)
			_play(_smack)
		MittWork.MISS:
			_flash("Wrong one", MISSED)
		_:
			_flash("Nothing there", DIM)
	queue_redraw()
	return judged


func _process(delta: float) -> void:
	if running:
		tick((Time.get_ticks_usec() - _start_usec) / 1000000.0)
	if _feedback_left > 0.0:
		_feedback_left -= delta
		queue_redraw()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if not running and not over and key.keycode == KEY_SPACE:
		start()
		get_viewport().set_input_as_handled()
	elif running and KEYS.has(key.keycode):
		hit(KEYS[key.keycode])
		get_viewport().set_input_as_handled()


func _show_hint() -> void:
	if over:
		_hint.text = "Accuracy %d%% (perfect %d, good %d, missed %d, stray %d): this session counts × %.2f" % [
			roundi(100.0 * drill.accuracy()), drill.counts[MittWork.PERFECT], drill.counts[MittWork.GOOD],
			drill.counts[MittWork.MISS], drill.counts.stray, drill.quality()]
	else:
		_hint.text = "Press Space to start. Hit each call on the beat as it reaches the line."


func _flash(text: String, colour: Color) -> void:
	_feedback = text
	_feedback_colour = colour
	_feedback_left = FEEDBACK_SECONDS


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_string(font, Vector2(40.0, 56.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, TEXT)
	draw_string(font, Vector2(40.0, 88.0), "%d beats a minute · %d calls" % [roundi(drill.tempo), drill.calls.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	_draw_mitts(font)
	_draw_call(font)
	_draw_track(font)
	draw_string(font, Vector2(40.0, size.y - 104.0), LEGEND, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	if _feedback_left > 0.0:
		var colour := _feedback_colour
		colour.a = clampf(_feedback_left / FEEDBACK_SECONDS, 0.0, 1.0)
		draw_string(font, Vector2(0.0, size.y * 0.5 + 40.0), _feedback, HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, colour)


## The coach's mitts: the lead mitt (left) wants odd numbers, the rear one even; a defence swings the rear mitt at you.
func _draw_mitts(font: Font) -> void:
	var centre := Vector2(size.x * 0.5, size.y * 0.36)
	var next: Dictionary = _next_note()
	for side in 2:
		var at := centre + Vector2(-110.0 if side == 0 else 110.0, 0.0)
		var colour: Color = MITT.darkened(0.45)
		if not next.is_empty() and float(next.t) - now <= drill.beat * MITT_LEAD_BEATS:
			var key: String = String(next.key)
			var wants_lead: bool = key in ["1", "3", "5"]
			if (side == 0) == wants_lead or (side == 1 and key in [MittWork.SLIP, MittWork.ROLL]):
				colour = MITT
				if key in [MittWork.SLIP, MittWork.ROLL]:
					at += Vector2(-60.0, 0.0) if key == MittWork.SLIP else Vector2(0.0, 40.0)
					draw_string(font, at + Vector2(-60.0, 90.0), "SLIP ←" if key == MittWork.SLIP else "ROLL ↓",
						HORIZONTAL_ALIGNMENT_CENTER, 120.0, 22, DEFENCE)
		draw_circle(at, 52.0, colour)
		draw_circle(at, 30.0, colour.lightened(0.25))


## The call the coach is shouting, its keys lighting up as they're hit.
func _draw_call(font: Font) -> void:
	var c: Dictionary = drill.call_at(now) if running else {}
	if c.is_empty():
		if running and now < drill.calls[0].t:
			var count: int = MittWork.COUNT_IN_BEATS - floori(now / drill.beat)
			draw_string(font, Vector2(0.0, size.y * 0.18), str(count), HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, DIM)
		return
	# Each key of the call, dimmed once it's been hit (or missed).
	var widths: Array[float] = []
	var total: float = 0.0
	for i in int(c.count):
		var text: String = String(LABELS[drill.notes[int(c.first) + i].key]) + ("!" if i == int(c.count) - 1 else "")
		widths.append(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 56).x + 28.0)
		total += widths[-1]
	var x: float = (size.x - total) * 0.5
	for i in int(c.count):
		var note: Dictionary = drill.notes[int(c.first) + i]
		var text: String = String(LABELS[note.key]) + ("!" if i == int(c.count) - 1 else "")
		var colour: Color = TEXT if note.result == "" else (MISSED if note.result == MittWork.MISS else DIM)
		draw_string(font, Vector2(x, size.y * 0.18), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 56, colour)
		x += widths[i]


func _draw_track(font: Font) -> void:
	var lane := Rect2(40.0, size.y - 220.0, size.x - 80.0, 96.0)
	draw_rect(lane, LANE)
	var hit_x: float = lane.position.x + HIT_LINE_X
	var mid_y: float = lane.position.y + lane.size.y * 0.5
	var first_beat: int = maxi(0, floori(now / drill.beat) - 1)
	for b in range(first_beat, first_beat + 40):
		var x: float = hit_x + (b * drill.beat - now) * PIXELS_PER_SECOND
		if x > lane.end.x:
			break
		if x >= lane.position.x:
			draw_line(Vector2(x, lane.position.y + 8.0), Vector2(x, lane.end.y - 8.0), TICK, 2.0)
	draw_line(Vector2(hit_x, lane.position.y - 6.0), Vector2(hit_x, lane.end.y + 6.0), TEXT, 3.0)
	for note in drill.notes:
		var x: float = hit_x + (float(note.t) - now) * PIXELS_PER_SECOND
		if x < lane.position.x - NOTE_RADIUS:
			continue
		if x > lane.end.x + NOTE_RADIUS:
			break
		var key: String = String(note.key)
		var colour: Color = DEFENCE if key in [MittWork.SLIP, MittWork.ROLL] else (LEAD if key in ["1", "3", "5"] else REAR)
		match String(note.result):
			MittWork.PERFECT, MittWork.GOOD:
				colour = PERFECT if note.result == MittWork.PERFECT else colour.lightened(0.4)
				colour.a = 0.35
			MittWork.MISS:
				colour = MISSED
				colour.a = 0.5
		draw_circle(Vector2(x, mid_y), NOTE_RADIUS, colour)
		draw_string(font, Vector2(x - NOTE_RADIUS, mid_y + 10.0), String(LABELS[key]), HORIZONTAL_ALIGNMENT_CENTER,
			NOTE_RADIUS * 2.0, 28, BACKGROUND)


## The next note still to hit, or {}.
func _next_note() -> Dictionary:
	for note in drill.notes:
		if note.result == "":
			return note
	return {}


func _play(player: AudioStreamPlayer) -> void:
	if player.is_inside_tree():
		player.play()


func _player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	return player


## A short sound made in code: a sine at `pitch` mixed with `noise` (0–1) of white noise, fading out over `seconds`.
static func _tone(pitch: float, seconds: float, noise: float, volume: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch)
	for i in count:
		var fade: float = 1.0 - float(i) / count
		var sample: float = (1.0 - noise) * sin(TAU * pitch * i / rate) + noise * rng.randf_range(-1.0, 1.0)
		data.encode_s16(i * 2, int(clampf(sample * fade * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
