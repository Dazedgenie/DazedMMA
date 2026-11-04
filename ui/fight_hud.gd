class_name FightHud
extends Control
## The fight screen's HUD (docs/06 §6.17, D460–D466, Kyle's picks; it replaced HUD v0 of #19), laid out like a fight on
## TV: one score bug across the top (each man's body figure (D150), name and stamina, the round, the clock and the
## judges' lean), your corner's card in the top left (the gameplan (D320) and the two drilled rules (D116)), the speed
## and towel buttons in the top right, the calls in one row along the bottom with the voice line on top of them (only
## the calls that work from here, D462), the key moments down the right (D464), the ground position's drawing and the
## grips in the bottom left (D210, D265), and while a submission is locked in, the danger meter over the calls (D126).
## The corners' shouts sit under their own side of the bug. Hold Tab (or press the feed's button) for the details: the
## damage numbers and every line of the feed with its odds (D463, D464). One dialog serves the bell, the result, the
## menu and the towel question; the round break sits down the right (D465). Presentation only: buttons send signals,
## the fight screen acts.
##
## Laid out for 1920×1080; the project's canvas_items stretch scales it to the window.

signal call_pressed(call_id: String)
## "slow", "fast", "pause" or "towel".
signal control_pressed(which: String)

## The see-through backing every piece sits on (the off-fight screens' HALL, a shade more solid over the cage).
const GLASS := Color(0.055, 0.067, 0.086, 0.82)
const PANEL := GLASS
const FIGHTER_COLOURS: Array[Color] = [Color("#ff6b6b"), Color("#5fa8ff")]
const PIP_COLOURS: Array[Color] = [Color("#51cf66"), Color("#fcc419"), Color("#ff6b6b")]
## Small headings and quiet text.
const MUTED := Color("#8a919c")
## A call being acted on: its button's edge and your corner's chip.
const LIVE := Color("#ffc94d")
## The read calls' keys (Q, E).
const READ_COLOUR := Color("#66d9e8")
## The figure's readout, top to bottom (D150): what's left of each area, 1 − hurt. Shown with the details (D463).
## Head is health (D120): at 0 the referee stops it.
const AREAS: Array[String] = ["head", "body", "legs"]
## The score bug: this wide and tall at 1080p, this far down; the figure in it.
const BUG_WIDTH: float = 1200.0
const BUG_HEIGHT: float = 104.0
const BUG_TOP: float = 18.0
const FIGURE_SIZE := Vector2(44.0, 74.0)
## Every piece stays this far in from the edges.
const EDGE: float = 24.0
## The corner card's width, the position card's width and the drawing's height in it (D210).
const CORNER_WIDTH: float = 316.0
const POSITION_WIDTH: float = 300.0
const DIAGRAM_HEIGHT: float = 130.0
## The feed: its width, its bottom (clear of the calls), and its height with and without the details.
const FEED_WIDTH: float = 400.0
const FEED_BOTTOM: float = 150.0
const FEED_HEIGHT: float = 270.0
const FEED_DETAILS_TOP: float = 190.0
## The calls' row: a call button's height and the room on its left for the key.
const CALL_HEIGHT: float = 44.0
const KEY_ROOM: int = 46
## Real seconds the opponent corner's call stays up, a fired rule flashes, the banner shows.
const BUBBLE_SECONDS: float = 3.0
const FLASH_SECONDS: float = 1.2
const BANNER_SECONDS: float = 1.6
## The read-call slots, in order (docs/06 §3).
const READ_KEYS: Array[String] = ["Q", "E"]
## Why a call can't be made that hides its button rather than dimming it (D462): it can't be made from here at all.
const HIDES: Array[String] = ["not from here", "not from the", "not learned"]

var driver: FightDriver
var feed: FightFeed

var _names: Array[Label] = []
var _tags: Array[Label] = []
var _stamina: Array[ProgressBar] = []
var _figures: Array[BodyDamageFigure] = []
var _area_labels: Array = [[], []]  # per fighter: [head, body, legs] Labels
var _readouts: Array[Control] = []
var _rocked: Array[Label] = []
var _round: Label
var _clock: Label
var _speed: Label
var _judges: Label
var _corner: PanelContainer
var _plan_name: Label
var _plan_drift: Label
var _rule_names: Array[Label] = []
var _rule_status: Array[Label] = []
var _rule_sharp: Array[ProgressBar] = []
var _bubble: PanelContainer
var _bubble_label: Label
var _our_call: PanelContainer
var _our_call_label: Label
var _strip: PanelContainer
var _voice: VoiceMeter
var _voice_label: Label
var _call_bar: HBoxContainer
var _read_gap: Control
var _call_buttons: Dictionary = {}  # call id → Button
var _live: Dictionary = {}  # call id → true while its button shows the live edge
var _read_ids: Array[String] = []
var _speed_panel: PanelContainer
var _speed_buttons: Dictionary = {}  # "slow"/"fast"/"pause"/"towel" → Button
var _banner: Label
var _danger_panel: PanelContainer
var _position_panel: PanelContainer
var _position_label: Label
## Who holds what under the position (D265).
var _grips_label: Label
var _diagram: PositionDiagram
var _danger_label: Label
var _danger_at: Label
var _danger: ProgressBar
var _dialog: PanelContainer
var _dialog_title: Label
var _dialog_body: RichTextLabel
var _dialog_extra: VBoxContainer
var _dialog_buttons: HBoxContainer
var _bubble_left: float = 0.0
var _banner_left: float = 0.0
var _flash_left: Array[float] = [0.0, 0.0]  # per rule slot
var _plan_every: float = 0.0
var _details: bool = false
## The calls the call bar offers ([] = all): a playtest fight starts with a few (D118, docs/07 §1).
var allowed_calls: Array = []
## Easy difficulty: the Pause button is live (D50).
var pause_allowed: bool = false:
	set(value):
		pause_allowed = value
		if _speed_buttons.has("pause"):
			_speed_buttons.pause.visible = value


func _init() -> void:
	theme = FightTheme.create()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## Starts showing a fight.
func watch(p_driver: FightDriver) -> void:
	driver = p_driver
	feed.clear()
	hide_dialog()
	_bubble.visible = false
	_banner.visible = false
	var sim: FightSim = driver.sim
	for i in 2:
		_names[i].text = sim.fighters[i].name
		_tags[i].text = "YOUR CORNER" if i == driver.player else ""
	sim.event_emitted.connect(_on_event.bind(sim))
	driver.flourish.connect(_on_flourish)
	_build_calls(sim)
	_refresh(0.0)


func _process(delta: float) -> void:
	if driver != null:
		_refresh(delta)


## True while the details are up (D463): Tab held or the feed's button down.
func details_shown() -> bool:
	return _details


## Why the player's corner can't make this call right now, or "" when it can (dims the button).
static func call_problem(sim: FightSim, i: int, call: Dictionary) -> String:
	if sim.is_over():
		return "the fight is over"
	if sim.decisions[i].calls.voice(sim.now) < float(call.get("voice_cost", 0)):
		return "not enough voice"
	var positions: Array = call.get("positions", [])
	if not positions.is_empty() and not positions.has(sim.situation.position):
		return "not from here"
	if call.has("roles") and not call.roles.has(sim.situation.role(i)):
		return "not from the %s" % sim.situation.role(i)
	var technique: Variant = call.get("requires_technique")
	if technique != null and not sim.fighters[i].repertoire.has(technique):
		return "not learned"
	return ""


## Is this call on the call bar in this fight?
func is_allowed(id: String) -> bool:
	return allowed_calls.is_empty() or allowed_calls.has(id)


## The judges' rough score for the round so far (docs/06 §2), e.g. "≈ 10-9 Wrestler".
static func judges_estimate(sim: FightSim) -> String:
	if sim.ruleset.judging == Ruleset.WHOLE_FIGHT:
		var lean: Dictionary = Judging.whole_fight_pick(sim.fight_scores())
		if int(lean.winner) < 0:
			return "Judges: nothing in it yet"
		return "Judges: ≈ %s (%s)" % [sim.fighters[int(lean.winner)].name, FightLogFormatter.JUDGED_ON[lean.on]]
	var points: Array[float] = sim.round_points()
	if points[0] + points[1] < 1.0:
		return "Judges: nothing in it yet"
	var card: Array[int] = Judging.round_card(points, [0, 0], [], sim.round_impact())
	if card[0] == card[1]:
		return "Judges: ≈ even"
	var w: int = 0 if card[0] > card[1] else 1
	return "Judges: ≈ %d-%d %s" % [card[w], card[1 - w], sim.fighters[w].name]


## The submission meter's words (D126), e.g. "Kicker's TRIANGLE CHOKE on Wrestler · danger 60";
## "" when no hold is locked in.
static func danger_text(sim: FightSim) -> String:
	var hold: Dictionary = sim.hold()
	if hold.is_empty():
		return ""
	var a: int = int(hold.attacker)
	var hold_name: String = String(sim.actions.get_action(hold.action_id).name).to_upper()
	return "%s's %s on %s · danger %d" % [sim.fighters[a].name, hold_name, sim.fighters[1 - a].name, roundi(maxf(0.0, float(hold.danger)))]


## One line of the figure's readout, e.g. "HEAD 65%": what's left of that area.
## The ground diagram's caption (D210): the position and who's on top, or the hold and where it was locked from.
static func position_text(sim: FightSim) -> String:
	var where: String = PositionDiagram.position_for(sim)
	if where == "":
		return ""
	var name: String = String(sim.positions.get_position(where).name).to_upper()
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		return "%s FROM %s" % [String(sim.actions.get_action(hold.action_id).name).to_upper(), name]
	var top: int = sim.situation.roles.find(PositionLibrary.TOP)
	if top < 0:
		return name
	return "%s · %s %s" % [name, sim.fighters[top].name.to_upper(), sim.positions.top_label(where).to_upper()]


## The grips readout under the position (D265): who holds what in the clinch or on the ground, e.g.
## "WRESTLER: BODY LOCK · BOXER: OVERHOOK" or "BOXER FRAMES · HOLDS A WRIST"; "" when nobody holds anything.
static func grips_text(sim: FightSim) -> String:
	var parts: Array[String] = []
	if sim.situation.position == PositionLibrary.CLINCH:
		for i in 2:
			var mine: int = sim.underhooks(i)
			var what: String = ""
			if mine == 2:
				what = "BODY LOCK"
			elif mine == 1:
				what = "UNDERHOOK"
			elif sim.underhooks(1 - i) > 0:
				what = "OVERHOOK"
			if sim.fighters[1 - i].tied_up_ticks > 0:
				what = "COLLAR TIE" if what == "" else what + ", COLLAR TIE"
			if what != "":
				parts.append("%s: %s" % [sim.fighters[i].name.to_upper(), what])
		return " · ".join(parts)
	if sim.situation.is_standing() or not sim.hold().is_empty():
		return ""
	var bottom: int = sim.situation.roles.find(PositionLibrary.BOTTOM)
	if bottom < 0:
		return ""
	var g: Dictionary = sim.ground_grips()
	var held: Array[String] = []
	if g.collar:
		held.append("TIES UP THE HEAD")
	if int(g.wrists) > 0:
		held.append("HOLDS BOTH WRISTS" if int(g.wrists) >= 2 else "HOLDS A WRIST")
	if g.frame:
		held.append("FRAMES")
	if g.two_on_one:
		held.append("TWO HANDS ON THE ARM")
	if int(g.half_inside) == bottom:
		held.append("HAS THE UNDERHOOK")
	if sim.situation.position == FightSim.CRUCIFIX:
		parts.append("%s'S ARMS TRAPPED" % sim.fighters[bottom].name.to_upper())
	if not held.is_empty():
		parts.append("%s %s" % [sim.fighters[bottom].name.to_upper(), ", ".join(held)])
	if int(g.half_inside) == 1 - bottom:
		parts.append("%s HAS THE UNDERHOOK" % sim.fighters[1 - bottom].name.to_upper())
	return " · ".join(parts)


static func area_text(f: FighterState, area: String) -> String:
	return "%s %d%%" % [area.to_upper(), roundi((1.0 - f.hurt(area)) * 100.0)]


## The plan panel's first line: the corner's gameplan (D320), and when he's drifting off it (D323).
static func plan_line(plan: Gameplan) -> String:
	if plan == null or plan.is_empty():
		return "[b]PLAN[/b]  [color=#8a8f98]own game[/color]"
	var line: String = "[b]PLAN[/b]  %s" % plan.label
	if plan.last_stick() < 1.0:
		line += "\n[color=#ff8787]drifting off the plan (%d%% of it)[/color]" % roundi(plan.last_stick() * 100.0)
	return line


## The plan panel's text (BBCode): rules, the call being acted on, primed reads.
static func plan_text(sim: FightSim, i: int, flashing: Array[float] = [0.0, 0.0]) -> String:
	var lines: Array[String] = [plan_line(sim.decisions[i].gameplan), "", "[b]Rules[/b]"]
	var rules: DrilledRules = sim.decisions[i].rules
	for n in rules.slots.size():
		var entry: Dictionary = rules.slots[n]
		if entry.is_empty():
			lines.append("%d  [color=#8a8f98]empty[/color]" % (n + 1))
			continue
		var reliability: int = roundi(rules.reliability(sim.views[i], entry) * 100.0)
		var wait: int = int(entry.ready_at) - sim.now
		var timer: String = "ready" if wait <= 0 else "%d s" % ceili(float(wait) / FightClock.TICKS_PER_SECOND)
		var colour: String = "#69db7c" if flashing[n] > 0.0 else "#e9ecef"
		lines.append("[color=%s]%d  %s[/color]" % [colour, n + 1, entry.rule.name])
		lines.append("    %d%% sharp · %s" % [reliability, timer])
	var calls: LiveCalls = sim.decisions[i].calls
	lines.append("")
	lines.append("[b]Calls[/b]")
	var any: bool = false
	for heard: Dictionary in calls.pending:
		lines.append("[color=#ffc94d]%s[/color]  hearing it…" % heard.call.name)
		any = true
	if not calls.attempt.is_empty():
		lines.append("[color=#ffc94d]%s[/color]  going for it" % calls.attempt.call.name)
		any = true
	if not calls.focus.is_empty():
		lines.append("%s  %d s" % [calls.focus.call.name, _seconds_left(sim, int(calls.focus.until))])
		any = true
	for read: Dictionary in calls.reads:
		lines.append("[color=#66d9e8]%s[/color]  primed %d s" % [read.call.name, _seconds_left(sim, int(read.until))])
		any = true
	if not any:
		lines.append("[color=#8a8f98]none[/color]")
	return "\n".join(lines)


static func _seconds_left(sim: FightSim, until: int) -> int:
	return maxi(0, ceili(float(until - sim.now) / FightClock.TICKS_PER_SECOND))


## Can this call be made from here at all (D462)? False when it's for another position or role, or he never learned
## it: its button is hidden. A call that fits but can't be made yet (not enough voice) stays up, dimmed.
static func call_fits(sim: FightSim, i: int, call: Dictionary) -> bool:
	var why: String = call_problem(sim, i, call)
	for hides: String in HIDES:
		if why.begins_with(hides):
			return false
	return true


## Your corner's chip under your name (D460): the calls he's hearing, going for, acting on or primed for, e.g.
## "Pressure! · 12 s" or "Catch the kick! · primed 6 s"; "" when there's none.
static func call_state(sim: FightSim, i: int) -> String:
	var calls: LiveCalls = sim.decisions[i].calls
	var parts: Array[String] = []
	for heard: Dictionary in calls.pending:
		parts.append("%s · hearing it…" % heard.call.name)
	if not calls.attempt.is_empty():
		parts.append("%s · going for it" % calls.attempt.call.name)
	if not calls.focus.is_empty():
		parts.append("%s · %d s" % [calls.focus.call.name, _seconds_left(sim, int(calls.focus.until))])
	for read: Dictionary in calls.reads:
		parts.append("%s · primed %d s" % [read.call.name, _seconds_left(sim, int(read.until))])
	return "    ".join(parts)


## One drilled rule on the corner card (D460): {name, sharp (0–1, how reliably it fires), status ("READY", "8 S" while
## it cools down, "" for an empty slot)}.
static func rule_state(sim: FightSim, i: int, n: int) -> Dictionary:
	var rules: DrilledRules = sim.decisions[i].rules
	if n >= rules.slots.size() or (rules.slots[n] as Dictionary).is_empty():
		return {"name": "empty", "sharp": 0.0, "status": ""}
	var entry: Dictionary = rules.slots[n]
	var wait: int = int(entry.ready_at) - sim.now
	return {"name": String(entry.rule.name), "sharp": rules.reliability(sim.views[i], entry),
		"status": "READY" if wait <= 0 else "%d S" % ceili(float(wait) / FightClock.TICKS_PER_SECOND)}


## The corner card's plan (D460): [its name, and when he's drifting off it how far (D323), else ""].
static func plan_words(plan: Gameplan) -> Array[String]:
	if plan == null or plan.is_empty():
		return [Gameplan.OWN_GAME, ""]
	var drift: String = ""
	if plan.last_stick() < 1.0:
		drift = "drifting off it (%d%% of it)" % roundi(plan.last_stick() * 100.0)
	return [String(plan.label), drift]


## The clock's two halves (D460): "R1 4:25" → ["ROUND 1", "4:25"].
static func clock_parts(display: String) -> Array[String]:
	var parts: PackedStringArray = display.split(" ", false, 1)
	if parts.size() < 2:
		return ["", display]
	return ["ROUND " + parts[0].trim_prefix("R"), parts[1]]


## Shows the dialog in the middle. `buttons`: [[label, Callable], …], the first the main action (solid red); `extra`
## goes under the text. With `side` it sits down the right of the screen (the round break, D391, D465), else centred.
func show_dialog(title: String, body: String, buttons: Array, extra: Control = null, side: bool = false) -> void:
	_place_dialog(side)
	_dialog_title.text = title
	_dialog_body.text = body
	_dialog_body.visible = body != ""
	for c in _dialog_extra.get_children():
		_dialog_extra.remove_child(c)
		c.queue_free()
	if extra != null:
		_dialog_extra.add_child(extra)
	_dialog_extra.visible = extra != null
	for c in _dialog_buttons.get_children():
		_dialog_buttons.remove_child(c)
		c.queue_free()
	for entry: Array in buttons:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(entry[1])
		b.custom_minimum_size = Vector2(200.0, 52.0)
		if _dialog_buttons.get_child_count() == 0:
			CampPlanner.style_fight_button(b, 26)
		else:
			OffCage.style_button(b)
		_dialog_buttons.add_child(b)
	_dialog.visible = true
	_show_play(false)
	if _dialog_buttons.get_child_count() > 0:
		focus_later(_dialog_buttons.get_child(0) as Control)


## Gives a control the keyboard focus after this frame, if it's still on screen then.
static func focus_later(control: Control) -> void:
	var ref: WeakRef = weakref(control)
	(func() -> void:
		var c: Control = ref.get_ref() as Control
		if c != null and c.is_visible_in_tree():
			c.grab_focus()).call_deferred()


## The round break's side panel (D391, D465): this wide (px), this far in from the right edge, this far below the bug.
const SIDE_DIALOG_WIDTH: float = 760.0
const SIDE_DIALOG_MARGIN: float = 24.0
const SIDE_DIALOG_TOP: float = 150.0
## The dialog in the middle: this wide.
const DIALOG_WIDTH: float = 1000.0


func _place_dialog(side: bool) -> void:
	if side:
		_dialog.anchor_left = 1.0
		_dialog.anchor_right = 1.0
		_dialog.anchor_top = 0.0
		_dialog.anchor_bottom = 0.0
		_dialog.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_dialog.grow_vertical = Control.GROW_DIRECTION_END
		_dialog.offset_left = -SIDE_DIALOG_WIDTH - SIDE_DIALOG_MARGIN
		_dialog.offset_right = -SIDE_DIALOG_MARGIN
		_dialog.offset_top = SIDE_DIALOG_TOP
		_dialog.offset_bottom = SIDE_DIALOG_TOP
		return
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.offset_left = -DIALOG_WIDTH / 2.0
	_dialog.offset_right = DIALOG_WIDTH / 2.0
	_dialog.offset_top = 0.0
	_dialog.offset_bottom = 0.0


## True when the dialog sits down the side (the round break).
func dialog_on_side() -> bool:
	return _dialog.visible and _dialog.anchor_left > 0.5


func hide_dialog() -> void:
	_dialog.visible = false
	_show_play(true)


func dialog_open() -> bool:
	return _dialog.visible


func dialog_title() -> String:
	return _dialog_title.text if _dialog.visible else ""


## A big line in the middle of the screen for a moment ("PERFECT CALL", "Round 2").
func show_banner(text: String, colour: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.modulate = colour
	_banner.visible = true
	_banner_left = BANNER_SECONDS


## The call bar's button for a call (tests).
func call_button(id: String) -> Button:
	return _call_buttons.get(id)


func read_call(slot: int) -> String:
	return _read_ids[slot] if slot < _read_ids.size() else ""


## The pieces you play with (the calls, your corner, the feed, the chips, the position and the danger meter) are
## down while a dialog is up: nothing on them can be pressed then. The score bug and the speed buttons stay.
func _show_play(on: bool) -> void:
	for c: Control in [_strip, _corner, feed]:
		c.visible = on
	if not on:
		for c: Control in [_bubble, _our_call, _position_panel, _danger_panel]:
			c.visible = false


func _refresh(delta: float) -> void:
	var sim: FightSim = driver.sim
	var details: bool = feed.pinned or (Input.is_physical_key_pressed(KEY_TAB) and DisplayServer.get_name() != "headless")
	if details != _details:
		_details = details
		feed.details = details
		feed.offset_top = -(1080.0 - FEED_DETAILS_TOP) if details else -FEED_BOTTOM - FEED_HEIGHT
	for i in 2:
		var f: FighterState = sim.fighters[i]
		_stamina[i].max_value = f.max_stamina()
		_stamina[i].value = f.stamina
		_figures[i].show_fighter(f)
		var tip: Array[String] = []
		for a in AREAS.size():
			var label: Label = _area_labels[i][a]
			label.text = area_text(f, AREAS[a])
			label.add_theme_color_override("font_color", BodyDamageFigure.damage_colour(f.hurt(AREAS[a])))
			tip.append(label.text)
		_figures[i].tooltip_text = " · ".join(tip)
		_readouts[i].visible = _details
		_rocked[i].visible = f.is_rocked()
	var clock: Array[String] = clock_parts(sim.clock.display())
	_round.text = clock[0]
	_clock.text = clock[1]
	_speed.text = "▶ " + driver.label().get_slice(" ", 0)  # "2×", "4×", "0.5×" or "paused".
	_judges.text = judges_estimate(sim).trim_prefix("Judges: ")
	var calls: LiveCalls = sim.decisions[driver.player].calls
	_voice.value = calls.voice(sim.now)
	_voice_label.text = "%d" % roundi(_voice.value)
	var reads_up: bool = false
	for id: String in _call_buttons:
		var b: Button = _call_buttons[id]
		var call: Dictionary = sim.calls.get_call(id)
		var why: String = call_problem(sim, driver.player, call)
		b.visible = call_fits(sim, driver.player, call)
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else String(call.name)
		reads_up = reads_up or (b.visible and _read_ids.has(id))
		var live: bool = (not calls.focus.is_empty() and calls.focus.call.id == id) \
			or (not calls.attempt.is_empty() and calls.attempt.call.id == id)
		for read: Dictionary in calls.reads:
			live = live or read.call.id == id
		if live != _live.has(id):
			b.add_theme_stylebox_override("normal", _call_box("normal", live))
			if live:
				_live[id] = true
			else:
				_live.erase(id)
	_read_gap.visible = reads_up
	var playing: bool = not _dialog.visible
	var hold: Dictionary = sim.hold()
	_danger_panel.visible = playing and not hold.is_empty()
	if not hold.is_empty():
		_danger.value = clampf(float(hold.danger), 0.0, FightSim.SUB_TAP)
		_danger_label.text = danger_text(sim).get_slice(" · ", 0)
		_danger_at.text = "danger %d" % roundi(maxf(0.0, float(hold.danger)))
	_diagram.show_fight(sim, FIGHTER_COLOURS)
	var clinch: bool = sim.situation.position == PositionLibrary.CLINCH and hold.is_empty()
	var grips: String = grips_text(sim)
	_diagram.visible = _diagram.where != ""
	_position_panel.visible = playing and (_diagram.where != "" or (clinch and grips != ""))
	if _position_panel.visible:
		_position_label.text = "CLINCH" if clinch else position_text(sim)
		_grips_label.text = grips
		_grips_label.visible = grips != ""
	_speed_buttons.slow.button_pressed = driver.speed == FightDriver.SLOW
	_speed_buttons.fast.button_pressed = driver.speed == FightDriver.FAST
	_speed_buttons.pause.button_pressed = driver.paused
	_bubble_left = maxf(0.0, _bubble_left - delta)
	_bubble.visible = playing and _bubble_left > 0.0
	_banner_left = maxf(0.0, _banner_left - delta)
	_banner.visible = _banner_left > 0.0
	for n in _flash_left.size():
		_flash_left[n] = maxf(0.0, _flash_left[n] - delta)
	_plan_every -= delta
	if _plan_every <= 0.0:
		_plan_every = 0.1
		_refresh_corner(sim)


## The corner card and your call's chip (D460), ten times a second.
func _refresh_corner(sim: FightSim) -> void:
	var i: int = driver.player
	var plan: Array[String] = plan_words(sim.decisions[i].gameplan)
	_plan_name.text = plan[0]
	_plan_drift.text = plan[1]
	_plan_drift.visible = plan[1] != ""
	for n in _rule_names.size():
		var rule: Dictionary = rule_state(sim, i, n)
		_rule_names[n].text = String(rule.name)
		var empty: bool = String(rule.status) == ""
		_rule_names[n].add_theme_color_override("font_color", PIP_COLOURS[0] if _flash_left[n] > 0.0 else (MUTED if empty else OffCage.TEXT))
		_rule_status[n].text = String(rule.status)
		_rule_status[n].add_theme_color_override("font_color", PIP_COLOURS[0] if rule.status == "READY" else MUTED)
		_rule_sharp[n].value = float(rule.sharp) * 100.0
		_rule_sharp[n].visible = not empty
		_rule_sharp[n].tooltip_text = "%d%% sharp: how often he does it when it comes up" % roundi(float(rule.sharp) * 100.0)
	var state: String = call_state(sim, i)
	_our_call_label.text = state
	_our_call.visible = state != "" and not _dialog.visible


func _on_event(event: FightEvent, sim: FightSim) -> void:
	feed.add_event(event, sim)
	match event.type:
		FightEvent.STRIKE_LANDED:
			_figures[1 - event.actor].flash(String(event.data.target), int(event.data.get("leg", -1)))
		FightEvent.CALL_HEARD:
			if event.actor != driver.player:
				_bubble_label.text = "%s's corner: “%s”" % [sim.fighters[event.actor].name, String(sim.calls.get_call(event.data.call_id).name) if sim.calls.has(event.data.call_id) else event.data.call_id]
				_bubble_left = BUBBLE_SECONDS
			elif event.data.get("spam", false):
				_voice.shake()
		FightEvent.RULE_ANSWERED:
			if event.actor == driver.player and event.data.outcome == DrilledRules.FIRED:
				var slot: int = int(event.data.get("slot", 1)) - 1
				if slot >= 0 and slot < _flash_left.size():
					_flash_left[slot] = FLASH_SECONDS
					_plan_every = 0.0


func _on_flourish(event: FightEvent) -> void:
	show_banner("PERFECT CALL", Color("#ffe066"))
	var sim: FightSim = driver.sim
	var move: String = String(sim.actions.get_action(event.data.action_id).name) if sim.actions.has(event.data.action_id) else ""
	feed.add_line(FightFeed.KEY_MOMENT, "[color=#ffe066][b]Perfect call![/b] The %s landed right in the opening.[/color]" % move.to_lower())


## The call row (D462): every call on its key, the read calls (Q, E) after a gap; _refresh shows only the ones that
## work from here.
func _build_calls(sim: FightSim) -> void:
	for c in _call_bar.get_children():
		_call_bar.remove_child(c)
		c.queue_free()
	_call_buttons.clear()
	_live.clear()
	_read_ids.clear()
	for id in sim.calls.ids():
		if not is_allowed(id):
			continue
		var call: Dictionary = sim.calls.get_call(id)
		if call.get("kind", "now") == LiveCalls.READ:
			_read_ids.append(id)
			continue
		var key: Variant = call.get("hotkey")
		var label: String = String(call.name).trim_suffix("!")
		_add_call_button(id, str(key) if key is String else ("%d" % int(key) if key != null else ""), label)
	_read_gap = ColorRect.new()
	(_read_gap as ColorRect).color = Color(1, 1, 1, 0.12)
	_read_gap.custom_minimum_size = Vector2(1.0, 0.0)
	_call_bar.add_child(_read_gap)
	for n in mini(READ_KEYS.size(), _read_ids.size()):
		_add_call_button(_read_ids[n], READ_KEYS[n], String(sim.calls.get_call(_read_ids[n]).name).trim_suffix("!"), true)


## A call's box: the off-fight button (D435) with room on the left for its key, edged in amber while it's being acted on.
func _call_box(state: String, live: bool = false) -> StyleBoxFlat:
	var box: StyleBoxFlat = OffCage.button_box(state)
	box.content_margin_left = KEY_ROOM
	box.content_margin_right = 12
	if live:
		box.bg_color = Color("#33301f")
		box.border_color = LIVE
		box.set_border_width_all(2)
	return box


func _add_call_button(id: String, key: String, label: String, read: bool = false) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, CALL_HEIGHT)
	for state: String in OffCage.STATES:
		b.add_theme_stylebox_override(state, _call_box(state))
	b.add_theme_color_override("font_disabled_color", OffCage.TEXT_DISABLED)
	DisplayFont.apply(b, 21)
	b.pressed.connect(func() -> void: call_pressed.emit(id))
	var cap := Label.new()
	cap.text = key
	DisplayFont.apply(cap, 19)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keycap := StyleBoxFlat.new()
	keycap.bg_color = Color("#0f1216")
	keycap.border_color = Color(READ_COLOUR, 0.6) if read else Color("#3a414c")
	keycap.set_border_width_all(1)
	keycap.set_corner_radius_all(4)
	cap.add_theme_stylebox_override("normal", keycap)
	cap.add_theme_color_override("font_color", Color("#9be7f1") if read else Color("#cfd4da"))
	cap.position = Vector2(7.0, 7.0)
	cap.size = Vector2(30.0, 30.0)
	b.add_child(cap)
	_call_bar.add_child(b)
	_call_buttons[id] = b


## A thin meter, filling from the fighter's own side: from the left for the red corner, from the right for the blue.
func _bar(i: int, height: float, colour: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = max_value
	bar.value = max_value
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(roundi(height / 2.0))
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.09)
	back.set_corner_radius_all(roundi(height / 2.0))
	bar.add_theme_stylebox_override("background", back)
	return bar


## A small heading in the display font, spaced out ("PLAN", "DRILLED RULES").
static func _heading(text: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	DisplayFont.apply(label, size)
	label.add_theme_color_override("font_color", MUTED)
	return label


## A chip under one side of the bug: a corner's shout.
static func _chip(fill: Color, edge: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	chip.add_theme_stylebox_override("panel", box)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


func _build() -> void:
	_build_bug()
	_build_corner()
	_build_speed()

	# The corners' shouts, under their own side of the bug (D460): theirs in blue, yours (the call being acted on) in amber.
	_bubble = _chip(Color(0.09, 0.17, 0.29, 0.9), Color(FIGHTER_COLOURS[1], 0.45))
	_place_under_bug(_bubble, 1)
	_bubble_label = Label.new()
	DisplayFont.apply(_bubble_label, 22)
	_bubble_label.add_theme_color_override("font_color", Color("#cfe3ff"))
	_bubble.add_child(_bubble_label)
	_bubble.visible = false
	_our_call = _chip(Color(0.24, 0.18, 0.05, 0.9), Color(LIVE, 0.5))
	_place_under_bug(_our_call, 0)
	_our_call_label = Label.new()
	DisplayFont.apply(_our_call_label, 22)
	_our_call_label.add_theme_color_override("font_color", Color("#ffe6a3"))
	_our_call.add_child(_our_call_label)
	_our_call.visible = false

	# The ground position's drawing and the grips (bottom left, D210, D265): only on the ground, or in a clinch
	# where somebody holds something.
	_position_panel = _glass()
	_position_panel.anchor_top = 1.0
	_position_panel.anchor_bottom = 1.0
	_position_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_position_panel.offset_left = EDGE
	_position_panel.offset_right = EDGE + POSITION_WIDTH
	_position_panel.offset_top = -EDGE
	_position_panel.offset_bottom = -EDGE
	_position_panel.visible = false
	add_child(_position_panel)
	var position_column := VBoxContainer.new()
	position_column.add_theme_constant_override("separation", 6)
	_position_panel.add_child(position_column)
	_position_label = _heading("", 16)
	_position_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	position_column.add_child(_position_label)
	_diagram = PositionDiagram.new()
	_diagram.custom_minimum_size = Vector2(0.0, DIAGRAM_HEIGHT)
	position_column.add_child(_diagram)
	_grips_label = Label.new()
	_grips_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grips_label.add_theme_font_size_override("font_size", 16)
	_grips_label.add_theme_color_override("font_color", Color("#ffd43b"))
	_grips_label.visible = false
	position_column.add_child(_grips_label)

	# The key moments (right, above the calls; D464). With the details up it runs up to under the speed buttons.
	feed = FightFeed.new()
	feed.add_theme_stylebox_override("panel", _glass_style(Color(GLASS, 0.72)))
	feed.anchor_left = 1.0
	feed.anchor_right = 1.0
	feed.anchor_top = 1.0
	feed.anchor_bottom = 1.0
	feed.offset_left = -EDGE - FEED_WIDTH
	feed.offset_right = -EDGE
	feed.offset_top = -FEED_BOTTOM - FEED_HEIGHT
	feed.offset_bottom = -FEED_BOTTOM
	add_child(feed)

	# The calls (bottom middle, D462): the voice line on top, then one row of the calls that work from here.
	_strip = _glass()
	_strip.anchor_left = 0.5
	_strip.anchor_right = 0.5
	_strip.anchor_top = 1.0
	_strip.anchor_bottom = 1.0
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_strip.offset_top = -EDGE
	_strip.offset_bottom = -EDGE
	_strip.custom_minimum_size = Vector2(560.0, 0.0)
	add_child(_strip)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_strip.add_child(column)
	var voice_row := HBoxContainer.new()
	voice_row.add_theme_constant_override("separation", 12)
	column.add_child(voice_row)
	voice_row.add_child(_heading("VOICE"))
	_voice = VoiceMeter.new()
	_voice.custom_minimum_size = Vector2(0.0, 12.0)
	_voice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_voice.tooltip_text = "Every call costs voice; under 30 your calls come out garbled"
	voice_row.add_child(_voice)
	_voice_label = _heading("100")
	voice_row.add_child(_voice_label)
	_call_bar = HBoxContainer.new()
	_call_bar.add_theme_constant_override("separation", 6)
	_call_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_call_bar)

	# The banner (middle, under the bug).
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 250.0
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(_banner, 76)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	add_child(_banner)

	# The submission danger meter (D126), just over the calls while a hold is locked in, with the tap end marked.
	_danger_panel = _glass(Color(0.11, 0.05, 0.06, 0.86))
	_danger_panel.anchor_left = 0.5
	_danger_panel.anchor_right = 0.5
	_danger_panel.anchor_top = 1.0
	_danger_panel.anchor_bottom = 1.0
	_danger_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_danger_panel.offset_left = -360.0
	_danger_panel.offset_right = 360.0
	_danger_panel.offset_top = -FEED_BOTTOM
	_danger_panel.offset_bottom = -FEED_BOTTOM
	add_child(_danger_panel)
	var danger_column := VBoxContainer.new()
	danger_column.add_theme_constant_override("separation", 6)
	_danger_panel.add_child(danger_column)
	_danger_label = Label.new()
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(_danger_label, 26)
	danger_column.add_child(_danger_label)
	_danger = _bar(0, 16.0, PIP_COLOURS[2], FightSim.SUB_TAP)
	_danger.value = 0.0
	_danger.tooltip_text = "submission danger: at 100 he taps, at 0 he's out of it"
	danger_column.add_child(_danger)
	var ends := HBoxContainer.new()
	danger_column.add_child(ends)
	for text: String in ["0 · out of it", "", "100 · tap"]:
		var end: Label = _heading(text, 15)
		end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		end.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][ends.get_child_count()]
		ends.add_child(end)
	_danger_at = ends.get_child(1) as Label
	_danger_panel.visible = false

	_dialog = _glass(Color(0.055, 0.067, 0.086, 0.94))
	_dialog.add_theme_stylebox_override("panel", _glass_style(Color(0.055, 0.067, 0.086, 0.94), 24))
	_place_dialog(false)
	add_child(_dialog)
	var dialog_column := VBoxContainer.new()
	dialog_column.add_theme_constant_override("separation", 16)
	_dialog.add_child(dialog_column)
	_dialog_title = Label.new()
	DisplayFont.apply(_dialog_title, 44)
	dialog_column.add_child(_dialog_title)
	_dialog_body = RichTextLabel.new()
	_dialog_body.bbcode_enabled = true
	_dialog_body.fit_content = true
	_dialog_body.scroll_active = false
	_dialog_body.add_theme_font_size_override("normal_font_size", 20)
	_dialog_body.add_theme_font_size_override("bold_font_size", 20)
	dialog_column.add_child(_dialog_body)
	_dialog_extra = VBoxContainer.new()
	dialog_column.add_child(_dialog_extra)
	_dialog_buttons = HBoxContainer.new()
	_dialog_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog_buttons.add_theme_constant_override("separation", 16)
	dialog_column.add_child(_dialog_buttons)
	_dialog.visible = false


## The score bug (D460): each man's side (his figure, his name, his stamina, a stripe in his corner's colour) either
## side of the round, the clock and the judges' lean.
func _build_bug() -> void:
	var bug: PanelContainer = _glass(GLASS, 0)
	bug.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bug.offset_left = -BUG_WIDTH / 2.0
	bug.offset_right = BUG_WIDTH / 2.0
	bug.offset_top = BUG_TOP
	bug.offset_bottom = BUG_TOP + BUG_HEIGHT
	add_child(bug)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	bug.add_child(row)
	for i in 2:
		if i == 1:
			row.add_child(_centre_block())
		row.add_child(_bug_side(i))


func _bug_side(i: int) -> Control:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 0)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	side.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
	margin.add_child(row)
	var figure := BodyDamageFigure.new()
	figure.custom_minimum_size = FIGURE_SIZE
	figure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_figures.append(figure)
	var readout := VBoxContainer.new()
	readout.alignment = BoxContainer.ALIGNMENT_CENTER
	readout.add_theme_constant_override("separation", 0)
	readout.visible = false
	for area in AREAS:
		var line := Label.new()
		line.add_theme_font_size_override("font_size", 15)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		readout.add_child(line)
		_area_labels[i].append(line)
	_readouts.append(readout)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 4)
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
	tag_row.add_theme_constant_override("separation", 10)
	tag_row.custom_minimum_size = Vector2(0.0, 20.0)
	var tag: Label = _heading("", 15)
	tag.add_theme_color_override("font_color", FIGHTER_COLOURS[i])
	_tags.append(tag)
	var rocked := Label.new()
	rocked.text = "ROCKED"
	DisplayFont.apply(rocked, 16)
	rocked.add_theme_color_override("font_color", Color("#1a0606"))
	var rocked_box := StyleBoxFlat.new()
	rocked_box.bg_color = PIP_COLOURS[2]
	rocked_box.set_corner_radius_all(4)
	rocked_box.content_margin_left = 8
	rocked_box.content_margin_right = 8
	rocked.add_theme_stylebox_override("normal", rocked_box)
	rocked.visible = false
	_rocked.append(rocked)
	tag_row.add_child(tag if i == 0 else rocked)
	tag_row.add_child(rocked if i == 0 else tag)
	who.add_child(tag_row)
	var name_label := Label.new()
	DisplayFont.apply(name_label, 38)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	name_label.clip_text = true
	who.add_child(name_label)
	_names.append(name_label)
	var gas: ProgressBar = _bar(i, 9.0, Color(OffCage.TEXT, 0.85), 100.0)
	gas.tooltip_text = "stamina"
	who.add_child(gas)
	_stamina.append(gas)
	for c: Control in ([figure, readout, who] if i == 0 else [who, readout, figure]):
		row.add_child(c)
	var stripe := ColorRect.new()
	stripe.color = FIGHTER_COLOURS[i]
	stripe.custom_minimum_size = Vector2(0.0, 4.0)
	side.add_child(stripe)
	return side


func _centre_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.custom_minimum_size = Vector2(200.0, 0.0)
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 0)
	_round = _heading("", 16)
	_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(_round)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(_clock, 48)
	block.add_child(_clock)
	_judges = Label.new()
	_judges.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judges.add_theme_font_size_override("font_size", 15)
	_judges.add_theme_color_override("font_color", Color("#aeb4bd"))
	_judges.tooltip_text = "the judges' rough score for the round so far"
	block.add_child(_judges)
	return block


## Your corner's card (top left, D460): the gameplan, and each drilled rule with how sharp it is and whether it's ready.
func _build_corner() -> void:
	_corner = _glass()
	_corner.offset_left = EDGE
	_corner.offset_top = BUG_TOP
	_corner.offset_right = EDGE + CORNER_WIDTH
	add_child(_corner)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_corner.add_child(column)
	column.add_child(_heading("PLAN"))
	_plan_name = Label.new()
	DisplayFont.apply(_plan_name, 26)
	column.add_child(_plan_name)
	_plan_drift = Label.new()
	_plan_drift.add_theme_font_size_override("font_size", 15)
	_plan_drift.add_theme_color_override("font_color", Color("#ff9b9b"))
	_plan_drift.visible = false
	column.add_child(_plan_drift)
	var rules_heading: Label = _heading("DRILLED RULES")
	rules_heading.custom_minimum_size = Vector2(0.0, 26.0)
	rules_heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	column.add_child(rules_heading)
	for n in DrilledRules.MAX_SLOTS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		column.add_child(line)
		var rule_name := Label.new()
		rule_name.add_theme_font_size_override("font_size", 16)
		rule_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(rule_name)
		_rule_names.append(rule_name)
		var status: Label = _heading("", 14)
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(status)
		_rule_status.append(status)
		var sharp: ProgressBar = _bar(0, 5.0, Color("#9aa3ad"), 100.0)
		column.add_child(sharp)
		_rule_sharp.append(sharp)


## Slow-mo, fast, pause and the towel (top right, D460), with the speed now beside them.
func _build_speed() -> void:
	_speed_panel = _glass()
	_speed_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_speed_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_speed_panel.offset_left = -EDGE
	_speed_panel.offset_right = -EDGE
	_speed_panel.offset_top = BUG_TOP
	_speed_panel.add_theme_stylebox_override("panel", _glass_style(GLASS, 8))
	add_child(_speed_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_speed_panel.add_child(row)
	_speed = _heading("", 20)
	_speed.add_theme_color_override("font_color", Color("#cfd4da"))
	_speed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed.custom_minimum_size = Vector2(70.0, 0.0)
	row.add_child(_speed)
	for entry: Array in [["slow", "½×", "Slow-mo [Space]"], ["fast", "4×", "Fast 4× [F]"], ["pause", "II", "Pause [P]"],
			["towel", "TOWEL", "Throw in the towel [T]"]]:
		var b := Button.new()
		b.text = entry[1]
		b.tooltip_text = entry[2]
		b.toggle_mode = entry[0] != "towel"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(50.0, 50.0)
		for state: String in OffCage.STATES:
			var box: StyleBoxFlat = OffCage.button_box(state, true)
			box.content_margin_left = 8
			box.content_margin_right = 8
			b.add_theme_stylebox_override(state, box)
		DisplayFont.apply(b, 19 if entry[0] != "towel" else 16)
		var which: String = entry[0]
		b.pressed.connect(func() -> void: control_pressed.emit(which))
		row.add_child(b)
		_speed_buttons[which] = b
	_speed_buttons.pause.visible = pause_allowed


## A chip just under the bug, against its side's outer edge: `i` 0 the red (left) side, 1 the blue.
func _place_under_bug(chip: Control, i: int) -> void:
	chip.anchor_left = 0.5
	chip.anchor_right = 0.5
	chip.offset_top = BUG_TOP + BUG_HEIGHT + 10.0
	if i == 0:
		chip.offset_left = -BUG_WIDTH / 2.0
		chip.offset_right = -BUG_WIDTH / 2.0
		chip.grow_horizontal = Control.GROW_DIRECTION_END
	else:
		chip.offset_left = BUG_WIDTH / 2.0
		chip.offset_right = BUG_WIDTH / 2.0
		chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(chip)


## The see-through box every piece of the HUD sits on (D460): rounded, a faint edge, `margin` inside.
static func _glass_style(colour: Color = GLASS, margin: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(8)
	style.border_color = Color(1, 1, 1, 0.07)
	style.set_border_width_all(1)
	style.set_content_margin_all(margin)
	return style


static func _glass(colour: Color = GLASS, margin: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _glass_style(colour, margin))
	return p


## The off-fight screens' backing (OffCage.hall_panel): flat, square-ish, a line along the top.
static func _panel_style(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(2)
	style.border_color = Color(0.4, 0.48, 0.57, 0.25)
	style.border_width_top = 1
	style.set_content_margin_all(12)
	return style


static func _panel(colour: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style(colour))
	return p
