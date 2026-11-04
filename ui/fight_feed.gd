class_name FightFeed
extends PanelContainer
## The fight screen's event feed (docs/06 §2): play-by-play, key moments, and the
## explanation lines that say why a move or call worked or didn't (A16). Lines are FightLogFormatter's,
## stamped with the round clock as the top bar shows it ("3:44").
##
## Two ways to read it (D464, Kyle's pick): the key moments in plain words while you watch, and everything with the
## odds behind each move ("55% (base 50 · stats +5)") while Tab is held or the header's button is down (`details`).

const ALL := 0
const KEY := 1
const EXPLAIN := 2
const FILTER_NAMES: Array[String] = ["All", "Key moments", "Explanations"]

## What kind of line an event makes (kind_of).
const NONE := ""
const PLAY := "play"
const KEY_MOMENT := "key"
const EXPLANATION := "explain"
## A line the screen adds for you ("Can't call Pass! now", "Sound off"): shows whatever the filter.
const NOTE := "note"

const MAX_LINES: int = 200
## A landed strike this heavy (or any counter) is a key moment.
const KEY_DAMAGE: int = 10
## The odds FightLogFormatter puts after a move, in its dim colour: " 55% (base 50 · stats +5)".
const ODDS_PATTERN := " \\[color=%s\\]\\d+%%[^\\[]*\\[/color\\]"

var filter: int = KEY:
	set(value):
		filter = value
		_redraw()

## Everything with the odds (true), or the key moments in plain words (false).
var details: bool = false:
	set(value):
		if value == details:
			return
		details = value
		filter = ALL if details else KEY
		_title.text = "EVERYTHING" if details else "KEY MOMENTS"
## The header's button is down: details stay up without Tab.
var pinned: bool = false

var _lines: Array[Dictionary] = []  # {kind, text}
var _log: RichTextLabel
var _title: Label
var _pin: Button
static var _odds: RegEx


func _init() -> void:
	custom_minimum_size = Vector2(400.0, 0.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_title = Label.new()
	_title.text = "KEY MOMENTS"
	DisplayFont.apply(_title, 16)
	_title.add_theme_color_override("font_color", FightHud.MUTED)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_pin = Button.new()
	_pin.text = "ALL · TAB"
	_pin.toggle_mode = true
	_pin.focus_mode = Control.FOCUS_NONE
	_pin.tooltip_text = "Hold Tab (or press this) for every line, the odds behind each move and the damage numbers"
	OffCage.style_button(_pin)
	DisplayFont.apply(_pin, 15)
	_pin.toggled.connect(func(on: bool) -> void: pinned = on)
	head.add_child(_pin)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 17)
	_log.add_theme_font_size_override("bold_font_size", 17)
	_log.focus_mode = Control.FOCUS_NONE
	column.add_child(_log)


## A feed line without the odds after its move: what the key moments show.
static func strip_odds(text: String) -> String:
	if _odds == null:
		_odds = RegEx.create_from_string(ODDS_PATTERN % FightLogFormatter.DIM_COLOUR)
	return _odds.sub(text, "", true)


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
		FightEvent.RESET:
			return PLAY
		FightEvent.ROCKED, FightEvent.KNOCKDOWN, FightEvent.LIVER_SHOT, FightEvent.STANCE_SWITCHED, FightEvent.GOT_UP, FightEvent.GRAPPLE_WON, FightEvent.POSITION_CHANGED, \
				FightEvent.SUBMISSION_LOCKED, FightEvent.SUBMISSION_ESCAPED, FightEvent.ROUND_ENDED, FightEvent.FIGHT_ENDED:
			return KEY_MOMENT
		FightEvent.SPRAWLED, FightEvent.STRIKE_DEFENDED:
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
	if kind == NOTE:
		return true
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
		_log.append_text(_shown(text) + "\n")


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
			_log.append_text(_shown(String(line.text)) + "\n")


func _shown(text: String) -> String:
	return text if details else strip_odds(text)
