class_name VerdictBanner
extends Control
## The verdict over the cage before the result's sheet (docs/06 §6.16, D436; Kyle's picks on the D436 cards): when a
## fight ends, a band across the cage reads it out like the announcer, with the fight still behind it (the hand being
## raised, or the finish again in slow motion, FinishReplay). A finish: the winner's name and how and when. A decision:
## each judge's score in turn, then the winner. A key or a click shows it all at once, and another goes on to the sheet;
## left alone it goes on by itself a few seconds after the last line.

signal finished

## The band's colour, where it sits (shares of the screen's height: the lower third, under the men), the gap between the judges' scores and how long it stays up
## after the last line (seconds).
const BAND := Color(0.04, 0.05, 0.07, 0.86)
const BAND_TOP: float = 0.64
const BAND_BOTTOM: float = 0.94
const READ_GAP: float = 1.1
const STAY_FOR: float = 3.5
const NAME_SIZE: int = 96
const LINE_SIZE: int = 30
const REPLAY_SIZE: int = 26
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const REPLAY_RED := Color("#ff6b6b")

## The lines to read out in order: [text, colour, size]. The last is the winner.
var lines: Array[Array] = []
## How many are showing.
var shown: int = 0
var _time: float = 0.0
## A decision's last line (how it was decided) comes up with the winner's name.
var _with_last: bool = false
var _box: VBoxContainer
var _replay: Label
var _labels: Array[Label] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var band := ColorRect.new()
	band.color = BAND
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = BAND_TOP
	band.anchor_bottom = BAND_BOTTOM
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(_box)
	_replay = Label.new()
	_replay.text = "● REPLAY"
	DisplayFont.apply(_replay, REPLAY_SIZE)
	_replay.add_theme_color_override("font_color", REPLAY_RED)
	_replay.position = Vector2(40.0, 36.0)
	_replay.visible = false
	add_child(_replay)


## Sets it up for a finished fight. `replay` shows the REPLAY tag in the corner (the finish playing again behind it).
func begin(sim: FightSim, replay: bool = false) -> void:
	lines = read_out(sim)
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for line: Array in lines:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		DisplayFont.apply(label, int(line[2]))
		label.add_theme_color_override("font_color", line[1])
		label.text = String(line[0])
		label.modulate.a = 0.0
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(label)
		_labels.append(label)
	_replay.visible = replay
	shown = 0
	_time = 0.0
	visible = true
	_with_last = lines.size() >= 2 and int(lines[-2][2]) == NAME_SIZE
	_show_up_to(1)


## The lines in order. A finish: "WINNER" with how and when, then his name. A decision: how it went to the cards, each
## judge's score one at a time, then his name. A draw: the scores, then DRAW.
static func read_out(sim: FightSim) -> Array[Array]:
	var out: Array[Array] = []
	var ended: Dictionary = sim.events[-1].data if not sim.events.is_empty() else {}
	var winner: int = int(ended.get("winner", -1))
	var by: String = FightResultCard.verdict_line(sim)
	if ended.has("cards"):
		out.append(["After %d rounds, to the judges' scorecards" % sim.clock.current_round, DIM, LINE_SIZE])
		var cards: Array = ended.cards
		for j in cards.size():
			var r: int = int(cards[j][0])
			var b: int = int(cards[j][1])
			var colour: Color = FightResultCard.CORNERS[0] if r > b else (FightResultCard.CORNERS[1] if b > r else TEXT)
			var lead: int = 0 if r >= b else 1
			out.append(["Judge %d scores it %d–%d %s" % [j + 1, maxi(r, b), mini(r, b),
				sim.fighters[lead].name if r != b else "even"], colour, LINE_SIZE])
	else:
		out.append([by, TEXT, LINE_SIZE])
	if winner >= 0:
		out.append(["%s WINS" % sim.fighters[winner].name.to_upper(), FightResultCard.CORNERS[winner], NAME_SIZE])
	else:
		out.append(["DRAW", TEXT, NAME_SIZE])
	if ended.has("cards"):
		out.append([by, DIM, LINE_SIZE])
	return out


func all_shown() -> bool:
	return shown >= lines.size()


## A key or click: everything at once; once it's all up, on to the sheet.
func skip() -> void:
	if not visible:
		return
	if not all_shown():
		_show_up_to(lines.size())
		_time = 0.0
	else:
		_finish()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if not all_shown():
		if _time >= READ_GAP:
			_time = 0.0
			_show_up_to(shown + (2 if _with_last and shown == lines.size() - 2 else 1))
	elif _time >= STAY_FOR:
		_finish()
	for i in _labels.size():
		var want: float = 1.0 if i < shown else 0.0
		_labels[i].modulate.a = move_toward(_labels[i].modulate.a, want, delta * 4.0)


func _show_up_to(n: int) -> void:
	shown = clampi(n, 0, lines.size())


func _finish() -> void:
	visible = false
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo():
		skip()
		get_viewport().set_input_as_handled()
