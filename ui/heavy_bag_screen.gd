class_name HeavyBagScreen
extends Control
## The heavy bag minigame on screen (docs/03 §13.6, D412): the bag drawn swinging on its chain, his glove, and the power
## meter beside it. Hold Space to load a shot and let go in the green as the bag comes back to him. A thud on every shot
## that lands and a whoosh on one that finds nothing, made in code. The judging is HeavyBag (sim/world/).

## played: false when the player let the session auto-resolve instead.
signal finished(quality: float, played: bool)

const BACKGROUND := Color("#14161b")
const TEXT := Color("#f1f3f5")
const DIM := Color("#8a8f98")
const BAG := Color("#7a2e22")
const BAG_DARK := Color("#4f1d16")
const CHAIN := Color("#9aa0a8")
const GLOVE := Color("#c92a2a")
const METER := Color("#22262e")
const GREEN_ZONE := Color("#40c057")
const GOOD_ZONE := Color("#fab005")
const WEAK_ZONE := Color("#495057")
const BAD := Color("#ff6b6b")
const FEEDBACK_SECONDS: float = 0.6
## How far the bag swings at the top of a full shot (radians), and how long the glove stays out after a shot.
const SWING_ANGLE: float = 0.55
const PUNCH_SECONDS: float = 0.15
const LEGEND := "Hold Space to load a shot · let go in the green at the top of the meter · meet the bag as it swings back to you"

var drill: HeavyBag
var running: bool = false
var over: bool = false
var now: float = 0.0

var _title: String
var _feedback: String = ""
var _feedback_colour: Color = TEXT
var _feedback_left: float = 0.0
var _punch_left: float = 0.0
var _hint: Label
var _skip: Button
var _done: Button
var _thud: AudioStreamPlayer
var _whoosh: AudioStreamPlayer


func _init(drill_in: HeavyBag, title: String) -> void:
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
	_thud = _player(MittWorkScreen._tone(90.0, 0.14, 0.6, 0.9))
	_whoosh = _player(MittWorkScreen._tone(600.0, 0.12, 0.95, 0.35))
	_show_hint()


func _ready() -> void:
	grab_focus()


## Starts the round.
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


## Moves the round to `at` seconds, ending it at the bell.
func tick(at: float) -> void:
	if not running:
		return
	now = at
	if drill.is_over(now):
		if drill.holding():
			drill.release(now)
		running = false
		over = true
		_skip.visible = false
		_done.visible = true
		_done.grab_focus()
		_show_hint()
	queue_redraw()


## Space goes down: he starts loading.
func load_shot() -> void:
	if running:
		drill.hold(now)
		queue_redraw()


## Space comes up: the shot.
func let_go() -> Dictionary:
	if not running:
		return {}
	var shot: Dictionary = drill.release(now)
	if shot.is_empty():
		return shot
	_punch_left = PUNCH_SECONDS
	match String(shot.result):
		HeavyBag.WHIFF:
			_flash("Nothing there: it's still swinging away", BAD)
			_play(_whoosh)
		HeavyBag.GREEN:
			_flash("Bang!" if shot.met else "Full power, but you missed the swing", GREEN_ZONE if shot.met else GOOD_ZONE)
			_play(_thud)
		HeavyBag.GOOD:
			_flash("Good shot" if shot.met else "Good shot, missed the swing", GOOD_ZONE)
			_play(_thud)
		_:
			_flash("Weak", DIM)
			_play(_thud)
	queue_redraw()
	return shot


func _process(delta: float) -> void:
	if running:
		tick(now + delta)  # Frame time, so a recording at a fixed frame rate keeps time too.
	if _feedback_left > 0.0 or _punch_left > 0.0:
		_feedback_left -= delta
		_punch_left -= delta
		queue_redraw()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or key.keycode != KEY_SPACE or not is_visible_in_tree():
		return
	if key.pressed and not running and not over:
		start()
	elif key.pressed:
		load_shot()
	else:
		let_go()
	get_viewport().set_input_as_handled()


func _show_hint() -> void:
	if over:
		_hint.text = "%d shots: %d in the green, %d good, %d weak, %d found nothing · best chain %d · this session counts × %.2f" % [
			drill.shots.size(), drill.counts[HeavyBag.GREEN], drill.counts[HeavyBag.GOOD], drill.counts[HeavyBag.WEAK],
			drill.counts[HeavyBag.WHIFF], drill.best_chain, drill.quality()]
	elif running:
		_hint.text = ""
	else:
		_hint.text = "Press Space to start. Then hold Space to load a shot and let go in the green as the bag comes back."


func _flash(text: String, colour: Color) -> void:
	_feedback = text
	_feedback_colour = colour
	_feedback_left = FEEDBACK_SECONDS


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_string(font, Vector2(40.0, 56.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, TEXT)
	draw_string(font, Vector2(40.0, 88.0), "Power %d · the meter tops out in %.1f s · %d s left" % [roundi(drill.power),
		drill.load_seconds, ceili(maxf(0.0, HeavyBag.ROUND_SECONDS - now))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	_draw_bag()
	_draw_meter(font)
	var line: String = "Chain ×%d · best %d · green %d · good %d · weak %d · found nothing %d" % [drill.chain, drill.best_chain,
		drill.counts[HeavyBag.GREEN], drill.counts[HeavyBag.GOOD], drill.counts[HeavyBag.WEAK], drill.counts[HeavyBag.WHIFF]]
	draw_string(font, Vector2(40.0, size.y - 140.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, TEXT)
	draw_string(font, Vector2(40.0, size.y - 104.0), LEGEND, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	if _feedback_left > 0.0:
		var colour := _feedback_colour
		colour.a = clampf(_feedback_left / FEEDBACK_SECONDS, 0.0, 1.0)
		draw_string(font, Vector2(0.0, size.y * 0.5 + 150.0), _feedback, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, colour)


## The bag on its chain, swinging away from him (to the right) after a shot, and his glove on the left.
func _draw_bag() -> void:
	var anchor := Vector2(size.x * 0.45, 130.0)
	var chain_len: float = 70.0
	var bag_size := Vector2(110.0, 260.0)
	var angle: float = -drill.bag_at(now) * SWING_ANGLE
	var down := Vector2(0.0, 1.0).rotated(angle)
	var top: Vector2 = anchor + down * chain_len
	draw_line(anchor, top, CHAIN, 4.0)
	draw_circle(anchor, 6.0, CHAIN)
	draw_set_transform(top, angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-bag_size.x * 0.5, 0.0), bag_size), BAG)
	draw_rect(Rect2(Vector2(-bag_size.x * 0.5, 0.0), Vector2(bag_size.x, 18.0)), BAG_DARK)
	draw_rect(Rect2(Vector2(-bag_size.x * 0.5, bag_size.y - 18.0), Vector2(bag_size.x, 18.0)), BAG_DARK)
	draw_rect(Rect2(Vector2(-bag_size.x * 0.5, bag_size.y * 0.45), Vector2(bag_size.x, 10.0)), BAG_DARK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# His glove: drawn back while loading (further the fuller the meter), out on the bag for a moment after a shot.
	var rest := Vector2(anchor.x - bag_size.x * 0.5 - 40.0, top.y + bag_size.y * 0.4)
	var glove: Vector2 = rest - Vector2(60.0 * drill.load_at(now), 0.0)
	if _punch_left > 0.0:
		glove = rest + Vector2(28.0, 0.0)
	draw_line(Vector2(glove.x - 160.0, glove.y + 40.0), glove, GLOVE.darkened(0.5), 18.0)
	draw_circle(glove, 34.0, GLOVE)
	draw_circle(glove + Vector2(10.0, -6.0), 14.0, GLOVE.lightened(0.2))


## The power meter: green at the top, good below it, weak under that; the fill shows where it is now.
func _draw_meter(font: Font) -> void:
	var r := Rect2(size.x * 0.72, 150.0, 56.0, 320.0)
	draw_rect(r, METER)
	var zone := func(from: float, to: float, colour: Color) -> void:
		var c := colour
		c.a = 0.35
		draw_rect(Rect2(r.position.x, r.end.y - r.size.y * to, r.size.x, r.size.y * (to - from)), c)
	var good_from: float = maxf(0.0, 1.0 - drill.green - HeavyBag.GOOD_BAND)
	zone.call(0.0, good_from, WEAK_ZONE)
	zone.call(good_from, 1.0 - drill.green, GOOD_ZONE)
	zone.call(1.0 - drill.green, 1.0, GREEN_ZONE)
	var load: float = drill.load_at(now)
	var fill: Color = GREEN_ZONE if load >= 1.0 - drill.green else (GOOD_ZONE if load >= good_from else WEAK_ZONE.lightened(0.3))
	draw_rect(Rect2(r.position.x + 10.0, r.end.y - r.size.y * load, r.size.x - 20.0, r.size.y * load), fill)
	draw_rect(r, DIM, false, 2.0)
	draw_string(font, Vector2(r.position.x - 30.0, r.end.y + 30.0), "Power", HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 60.0, 18, DIM)
	# When the bag comes back: a mark that fills as it swings in.
	if running and drill.shots.size() > 0:
		var left: float = drill.back_at() - now
		if left > -HeavyBag.MEET_WINDOW and left < HeavyBag.SWING_SECONDS:
			var share: float = clampf(1.0 - left / HeavyBag.SWING_SECONDS, 0.0, 1.0)
			var c: Color = GREEN_ZONE if absf(left) <= HeavyBag.MEET_WINDOW else DIM
			draw_arc(Vector2(r.position.x + r.size.x * 0.5, r.position.y - 40.0), 22.0, -PI * 0.5, -PI * 0.5 + TAU * share, 32, c, 6.0)


func _play(player: AudioStreamPlayer) -> void:
	if player.is_inside_tree():
		player.play()


func _player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	return player
