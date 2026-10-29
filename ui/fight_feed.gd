class_name FightFeed
extends PanelContainer
## The fight screen's event feed (docs/06 §2): play-by-play, key moments, and the
## explanation lines that say why a move or call worked or didn't (A16), with a
## filter: all / key moments / explanations only. Lines are FightLogFormatter's,
## stamped with the round clock as the top bar shows it ("3:44").

const ALL := 0
const KEY := 1
const EXPLAIN := 2
const FILTER_NAMES: Array[String] = ["All", "Key moments", "Explanations"]

## What kind of line an event makes (kind_of).
const NONE := ""
const PLAY := "play"
const KEY_MOMENT := "key"
const EXPLANATION := "explain"

const MAX_LINES: int = 200
## A landed strike this heavy (or any counter) is a key moment.
const KEY_DAMAGE: int = 10

var filter: int = ALL:
	set(value):
		filter = value
		_redraw()

var _lines: Array[Dictionary] = []  # {kind, text}
var _log: RichTextLabel
var _picker: OptionButton


func _init() -> void:
	custom_minimum_size = Vector2(460.0, 0.0)
	var column := VBoxContainer.new()
	add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "FEED"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_picker = OptionButton.new()
	_picker.focus_mode = Control.FOCUS_NONE
	for n in FILTER_NAMES:
		_picker.add_item(n)
	_picker.item_selected.connect(func(index: int) -> void: filter = index)
	head.add_child(_picker)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 17)
	_log.add_theme_font_size_override("bold_font_size", 17)
	_log.focus_mode = Control.FOCUS_NONE
	column.add_child(_log)


## Which kind of line this event makes, or NONE when the feed skips it (move phases,
## strikes out of range). Key moments: knockdowns, rocks, heavy or counter shots,
## position changes, a submission locking in or escaped (each beat of it is play), a call
## or rule going off, the bell. Explanations: why a
## takedown, call or rule didn't work.
static func kind_of(event: FightEvent) -> String:
	match event.type:
		FightEvent.ACTION_PHASE, FightEvent.ACTION_ENDED:
			return NONE
		FightEvent.STRIKE_LANDED:
			if event.data.get("counter", false) or int(event.data.get("damage", 0)) >= KEY_DAMAGE or event.data.has("into"):
				return KEY_MOMENT
			return PLAY
		FightEvent.STRIKE_MISSED:
			return NONE if event.data.has("reason") else PLAY
		FightEvent.FEINTED:
			return NONE if event.data.has("reason") else PLAY
		FightEvent.ROCKED, FightEvent.KNOCKDOWN, FightEvent.LIVER_SHOT, FightEvent.STANCE_SWITCHED, FightEvent.GOT_UP, FightEvent.GRAPPLE_WON, FightEvent.POSITION_CHANGED, \
				FightEvent.SUBMISSION_LOCKED, FightEvent.SUBMISSION_ESCAPED, FightEvent.ROUND_ENDED, FightEvent.FIGHT_ENDED:
			return KEY_MOMENT
		FightEvent.SPRAWLED:
			return KEY_MOMENT if event.data.get("worked", false) else EXPLANATION
		FightEvent.GRAPPLE_STOPPED, FightEvent.COMMAND_REJECTED:
			return EXPLANATION
		FightEvent.CALL_ANSWERED:
			match event.data.get("outcome", ""):
				LiveCalls.FIRED:
					return KEY_MOMENT
				LiveCalls.ACCEPTED:
					return PLAY
			return EXPLANATION
		FightEvent.RULE_ANSWERED:
			match event.data.get("outcome", ""):
				DrilledRules.FIRED:
					return KEY_MOMENT
				DrilledRules.SET:
					return PLAY
			return EXPLANATION
	return PLAY


## Does a line of this kind show under the current filter?
static func shows(kind: String, p_filter: int) -> bool:
	match p_filter:
		KEY:
			return kind == KEY_MOMENT
		EXPLAIN:
			return kind == EXPLANATION
	return kind != NONE


## "3:44": time left in the event's round, as the top bar's clock shows it.
static func clock_label(event: FightEvent, sim: FightSim) -> String:
	var per_round: int = sim.clock.ticks_in_round(event.round_number)
	var in_round: int = event.tick - sim.clock.round_start_tick(event.round_number)
	var left: int = int(ceil(float(per_round - in_round) / FightClock.TICKS_PER_SECOND))
	return "%d:%02d" % [left / 60, left % 60]


func add_event(event: FightEvent, sim: FightSim) -> void:
	var kind: String = kind_of(event)
	if kind == NONE:
		return
	add_line(kind, "[color=%s]%s[/color]  %s" % [FightLogFormatter.DIM_COLOUR, clock_label(event, sim), FightLogFormatter.describe(event, sim)])


func add_line(kind: String, text: String) -> void:
	_lines.append({ "kind": kind, "text": text })
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
		_redraw()
	elif shows(kind, filter):
		_log.append_text(text + "\n")


func clear() -> void:
	_lines.clear()
	_log.clear()


## The feed's text as shown (for tests and bug reports).
func text() -> String:
	return _log.get_parsed_text()


func _redraw() -> void:
	if _log == null:
		return
	_log.clear()
	for line: Dictionary in _lines:
		if shows(line.kind, filter):
			_log.append_text(line.text + "\n")
