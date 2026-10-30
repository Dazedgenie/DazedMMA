extends Node3D
## The fight prototype's screen (#19, docs/10 §1, docs/06): pick a fight, then coach
## the red corner through three rounds in the grey-box view (ArenaView) with HUD v0
## (FightHud), the speed controls (FightDriver) and the hotkeys of docs/06 §3. Blue's
## corner is the AI corner (D68). The bell holds the fight between rounds so the
## drilled rules can be changed; the result screen (FightResultCard, D173) offers a rematch.
##
## For the playtest (#20, D118): a playtest fight opens on its tip card and limits the
## call bar to its calls; every fight is saved as a FightRecord in user://fights/ for the
## write-up; `-- --self-check` runs the self-check fight and quits (the export check in CI).
##
## "Training camp first" on the setup opens the camp planner (CampPlanner, D133); its Fight!
## starts the same fight with the fighter as the camp left them (settings.red_profile).
##
## Strike sounds (StrikeSounds, D190) play during the fight at the setup's Sound volume; M mutes them.

## Smallest window the UI still fits in (the game opens windowed and resizable).
const MIN_WINDOW_SIZE := Vector2i(960, 540)
const SETUP := "setup"
const FIGHT := "fight"
const ROUND_BREAK := "round_break"
const OVER := "over"

var arena: ArenaView
var hud: FightHud
var setup: FightSetup
var planner: CampPlanner
## The result screen (D173), over the fight when it's over.
var result: FightResultCard
var overlay: DebugOverlay
var sounds: StrikeSounds
var driver: FightDriver
var state: String = SETUP
var settings: Dictionary = {}
## Where finished fights are saved ("" = don't save).
var record_dir: String = FightRecord.DIR
## The last fight's saved record ("" when it wasn't saved).
var last_record_path: String = ""

var _actions: ActionLibrary
var _roster: FighterLibrary
var _console: DebugConsole
var _break_rules: RuleSlots


func _ready() -> void:
	if "--self-check" in OS.get_cmdline_user_args():
		_self_check.call_deferred()
		return
	get_window().min_size = MIN_WINDOW_SIZE
	DisplayFont.add_symbols_fallback()
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()
	arena = ArenaView.new()
	add_child(arena)
	sounds = StrikeSounds.new()
	add_child(sounds)
	sounds.build_in_background()
	var ui: CanvasLayer = $UI
	hud = FightHud.new()
	hud.visible = false
	hud.call_pressed.connect(make_call)
	hud.control_pressed.connect(_on_control)
	ui.add_child(hud)
	overlay = DebugOverlay.new()
	ui.add_child(overlay)
	setup = FightSetup.new(_roster, _actions)
	setup.start_pressed.connect(start_fight)
	setup.camp_pressed.connect(open_camp)
	ui.add_child(setup)
	result = FightResultCard.new()
	result.visible = false
	ui.add_child(result)
	ui.move_child($UI/Version, -1)  # Over the full-screen setup.
	_console = $UI/DebugConsole
	ui.move_child(_console, -1)
	$UI/Version.text = "%s · fight prototype · Godot %s" % [
		ProjectSettings.get_setting("application/config/name"),
		Engine.get_version_info().string,
	]
	setup.focus_start()


## Starts a fight with these settings (FightSetup.settings()). With `red_profile` (a fighter@1
## profile, from the camp planner) the red corner is that fighter instead of `red`'s data file.
func start_fight(p_settings: Dictionary) -> void:
	settings = p_settings
	var fight_seed: int = int(settings.get("seed", -1))
	if fight_seed < 0:
		fight_seed = randi()
	var red: String = settings.red
	if settings.get("red_profile") is Dictionary:
		_roster.add(settings.red_profile)
		red = String(settings.red_profile.id)
	var sim := FightSim.new(fight_seed, _roster.make_pair(red, settings.blue), _actions, Ruleset.load_id(String(settings.get("ruleset", Ruleset.DEFAULT_ID))))
	sim.corners[1] = Corner.new(Corner.AI, fight_seed)
	driver = FightDriver.new(sim, 0)
	driver.normal_rate = float(settings.get("normal_rate", 2.0))
	driver.auto_slow = bool(settings.get("auto_slow", true))
	driver.flourishes = bool(settings.get("flourishes", true))
	for entry: Array in settings.get("rules", []):
		if String(entry[1]) != "":
			driver.set_rule(int(entry[0]), String(entry[1]), float(entry[2]))
	driver.round_over.connect(_on_round_over)
	driver.fight_over.connect(_on_fight_over)
	arena.tell_cues = bool(settings.get("tell_cues", true))
	arena.watch(driver)
	sounds.volume = float(settings.get("sound_volume", 1.0))
	sounds.watch(sim)
	hud.pause_allowed = bool(settings.get("easy", false))
	hud.allowed_calls = Array(settings.get("calls", []))
	hud.watch(driver)
	hud.visible = true
	$UI/Version.visible = false  # The call bar's second row sits where it is.
	overlay.driver = driver
	_console.watch(sim, "%s, seed %d" % [settings.get("label", ""), fight_seed])
	setup.visible = false
	result.visible = false
	_close_camp()
	state = FIGHT
	last_record_path = ""
	if String(settings.get("tip", "")) != "":
		driver.held = true
		hud.show_dialog(String(settings.get("label", "")), String(settings.tip), [["Fight!", _start_after_tip]])
	else:
		hud.show_banner("Round 1")


func _start_after_tip() -> void:
	hud.hide_dialog()
	driver.held = false
	hud.show_banner("Round 1")


func _process(delta: float) -> void:
	if driver != null and state == FIGHT:
		driver.advance(delta)


## The player's corner makes a call (call bar, keys 1–9 and Q/E). Calls go in while paused.
func make_call(id: String) -> void:
	if driver == null or state != FIGHT or not driver.sim.calls.has(id) or not hud.is_allowed(id):
		return
	var why: String = FightHud.call_problem(driver.sim, driver.player, driver.sim.calls.get_call(id))
	if why != "":
		hud.feed.add_line(FightFeed.EXPLANATION, "[color=#8a8f98]Can't call \"%s\" now: %s[/color]" % [driver.sim.calls.get_call(id).name, why])
		return
	driver.make_call(id)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if key == KEY_F3:
		overlay.visible = not overlay.visible
		arena.debug_marks = overlay.visible
		get_viewport().set_input_as_handled()
		return
	if state != FIGHT or hud.dialog_open():
		if key == KEY_ESCAPE and hud.dialog_title() == "Paused":
			_close_menu()
			get_viewport().set_input_as_handled()
		return
	var handled: bool = true
	match key:
		KEY_SPACE:
			driver.toggle_slow()
		KEY_F:
			driver.toggle_fast()
		KEY_P:
			_on_control("pause")
		KEY_T:
			_on_control("towel")
		KEY_M:
			sounds.muted = not sounds.muted
			hud.feed.add_line(FightFeed.EXPLANATION, "[color=#8a8f98]Sound %s (M)[/color]" % ("off" if sounds.muted else "on"))
		KEY_ESCAPE:
			_open_menu()
		KEY_Q:
			make_call(hud.read_call(0))
		KEY_E:
			make_call(hud.read_call(1))
		KEY_R:
			# Calls on a letter key (Cut the cage!, D230).
			handled = false
			for id in driver.sim.calls.ids():
				if driver.sim.calls.get_call(id).get("hotkey") == "R" and hud.is_allowed(id):
					make_call(id)
					handled = true
					break
		_:
			handled = false
			if key >= KEY_0 and key <= KEY_9:
				# Calls can share a key when they're for different positions (1: Pressure!
				# standing, Ground and pound! on top, D121): make the one that works from here.
				var on_key: Array[String] = []
				for id in driver.sim.calls.ids():
					var hotkey: Variant = driver.sim.calls.get_call(id).get("hotkey")
					if hotkey != null and not hotkey is String and int(hotkey) == key - KEY_0 and hud.is_allowed(id):
						on_key.append(id)
				for id in on_key:
					if FightHud.call_problem(driver.sim, driver.player, driver.sim.calls.get_call(id)) == "" or id == on_key[-1]:
						make_call(id)
						handled = true
						break
	if handled:
		get_viewport().set_input_as_handled()


func _on_control(which: String) -> void:
	if driver == null or state != FIGHT:
		return
	match which:
		"slow":
			driver.toggle_slow()
		"fast":
			driver.toggle_fast()
		"pause":
			if hud.pause_allowed:
				driver.paused = not driver.paused
		"towel":
			driver.held = true
			hud.show_dialog("Throw in the towel?", "%s loses by TKO. Only do it to save your fighter." % driver.sim.fighters[driver.player].name,
				[["Throw it in", func() -> void: driver.throw_towel()], ["Keep fighting", _close_menu]])


func _open_menu() -> void:
	driver.held = true
	hud.show_dialog("Paused", "The fight waits for you. (Esc goes back.)",
		[["Resume", _close_menu], ["Restart fight", func() -> void: start_fight(settings)], ["Change setup", _back_to_setup]])


func _close_menu() -> void:
	hud.hide_dialog()
	if state == FIGHT:
		driver.held = false


func _on_round_over(event: FightEvent) -> void:
	state = ROUND_BREAK
	var sim: FightSim = driver.sim
	_break_rules = RuleSlots.new(sim.fighters[driver.player].profile, _actions)
	_break_rules.show_rules(_current_rules())
	var next: int = sim.clock.current_round
	hud.show_dialog("End of round %d" % event.round_number, round_summary(sim, event),
		[["Start round %d" % next, _start_next_round]], _break_rules)


## The bell's text: each judge's card for the round, the totals and how both fighters are.
static func round_summary(sim: FightSim, event: FightEvent) -> String:
	var lines: Array[String] = []
	if not event.data.has("cards"):
		lines.append("No round scores under %s: the judges score the whole fight (the effort to finish, then control, then aggression)." % sim.ruleset.name)
		lines.append("So far: %s" % FightHud.judges_estimate(sim).trim_prefix("Judges: "))
	else:
		var cards: Array[String] = []
		for c: Array in event.data.cards:
			cards.append("%d-%d" % [c[0], c[1]])
		lines.append("Judges this round (%s – %s): %s" % [sim.fighters[0].name, sim.fighters[1].name, ", ".join(cards)])
		var totals: Array[String] = []
		for t: Array in sim.judge_totals:
			totals.append("%d-%d" % [t[0], t[1]])
		lines.append("So far: %s" % ", ".join(totals))
	for f in sim.fighters:
		lines.append("%s: stamina %d/%d, landed %d of %d, damage taken head %d · body %d · legs %d" % [f.name,
			roundi(f.stamina), roundi(f.max_stamina()), f.strikes_landed, f.strikes_thrown, f.damage.head, f.damage.body, f.damage.legs])
	lines.append("")
	lines.append("[color=#adb5bd]Change your drilled rules for the next round if you like.[/color]")
	return "\n".join(lines)


func _start_next_round() -> void:
	var now: Array = _current_rules()
	for entry: Array in _break_rules.picked():
		var slot: int = int(entry[0]) - 1
		var same: bool = slot < now.size() and now[slot][1] == entry[1] and (entry[1] == "" or is_equal_approx(float(now[slot][2]), float(entry[2])))
		if not same:
			driver.set_rule(int(entry[0]), String(entry[1]), float(entry[2]))
	hud.hide_dialog()
	state = FIGHT
	driver.resume()
	hud.show_banner("Round %d" % driver.sim.clock.current_round)


## The player's rules as they stand: [[slot, rule id, drilled 0–100], …].
func _current_rules() -> Array:
	var out: Array = []
	var rules: DrilledRules = driver.sim.decisions[driver.player].rules
	for n in rules.slots.size():
		var entry: Dictionary = rules.slots[n]
		out.append([n + 1, "" if entry.is_empty() else String(entry.rule.id), 80.0 if entry.is_empty() else float(entry.drilled) * 100.0])
	return out


func _on_fight_over(_event: FightEvent) -> void:
	state = OVER
	var sim: FightSim = driver.sim
	var record: Dictionary = FightRecord.build(sim, settings, driver.player)
	if record_dir != "":
		last_record_path = FightRecord.save(record, record_dir)
	var notes: Array[String] = []
	var injury: Dictionary = TrainingCamp.after_fight(settings.get("camp", {}), sim.fight_seed)
	if not injury.is_empty():
		notes.append(("[color=#ff8787]Fighting hurt made the %s injury worse: out %d days.[/color]" if injury.worse
			else "The %s injury held up: %d more days to heal.") % [injury.area, injury.days_out])
	notes.append("Seed %d (type it in the setup to replay this fight's start)" % sim.fight_seed)
	if last_record_path != "":
		notes.append("Saved for the playtest notes: %s" % ProjectSettings.globalize_path(last_record_path))
	var buttons: Array = []
	var next: Dictionary = Playtest.next_step(String(settings.get("step", ""))) if settings.get("step", "") != "" else {}
	if not next.is_empty():
		buttons.append(["Next: %s" % next.name, func() -> void: start_fight(Playtest.settings_for(next, settings))])
	buttons.append(["Fight again", func() -> void: start_fight(settings)])
	buttons.append(["Change setup", _back_to_setup])
	if last_record_path != "":
		buttons.append(["Open saved fights", func() -> void: OS.shell_open(ProjectSettings.globalize_path(record_dir))])
	hud.hide_dialog()
	result.show_result(sim, driver.player, record.stats, notes, buttons)


## `-- --self-check`: the self-check fight from the debug console, printed, then quit with
## 0 when it passed (CI runs it on the exported build to prove data/ shipped, #35).
func _self_check() -> void:
	var check: SimCheck = SimCheck.run(1)
	print("Self-check: %d moves, %d fighters, %d calls, %d playtest fights loaded" % [ActionLibrary.load_dir().ids().size(),
		FighterLibrary.load_dir().ids().size(), CallLibrary.load_dir().ids().size(), Playtest.steps().size()])
	for r in check.results:
		print("%s %s (%s)" % ["PASS" if r.passed else "FAIL", r.name, r.detail])
	get_tree().quit(0 if check.passed() and Playtest.steps().size() > 0 else 1)


## Opens the camp planner for these settings' red fighter (from the setup's "Training camp first").
func open_camp(p_settings: Dictionary) -> void:
	settings = p_settings
	_close_camp()
	planner = CampPlanner.new(_roster.profile(settings.red), randi())
	planner.opponent_name = String(_roster.profile(settings.blue).get("name", ""))
	planner.fight_pressed.connect(_fight_after_camp)
	planner.back_pressed.connect(_back_to_setup)
	$UI.add_child(planner)
	$UI.move_child(_console, -1)
	setup.visible = false
	planner.focus_run()


func _fight_after_camp(profile: Dictionary) -> void:
	var s: Dictionary = settings.duplicate(true)
	s.red_profile = profile
	s.camp = planner.summary()
	s.label = "%s after camp" % settings.get("label", "")
	start_fight(s)


func _close_camp() -> void:
	if planner != null:
		planner.queue_free()
		planner = null


func _back_to_setup() -> void:
	_close_camp()
	hud.hide_dialog()
	hud.visible = false
	result.visible = false
	state = SETUP
	if driver != null:
		driver.held = true
	setup.show_settings(settings)
	setup.visible = true
	$UI/Version.visible = true
	setup.focus_start()
