class_name DebugOverlay
extends PanelContainer
## The fight screen's debug overlay (F3, #19, docs/10 §1): the raw numbers behind
## what's on screen, for tuning and bug reports. It takes over the text of the old
## top-down cage view (D106): each fighter's wanted distance, circling and cutting
## off (docs/01 §20.2), with the cage lines and wanted-distance rings drawn in the
## 3D view while it's open. Presentation only.

var driver: FightDriver
var _text: RichTextLabel
var _every: float = 0.0


func _init() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16.0
	offset_right = 760.0
	offset_top = -560.0
	offset_bottom = -164.0
	add_theme_stylebox_override("panel", FightHud._panel_style(Color(0.0, 0.0, 0.0, 0.78)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 15)
	_text.add_theme_font_size_override("bold_font_size", 15)
	add_child(_text)
	visible = false


func _process(delta: float) -> void:
	_every -= delta
	if not visible or driver == null or _every > 0.0:
		return
	_every = 0.1
	_text.text = text_for(driver)


## Everything the overlay shows, as BBCode.
static func text_for(d: FightDriver) -> String:
	var sim: FightSim = d.sim
	var lines: Array[String] = [
		"[b]seed %d[/b] · tick %d · %s · %.1f fight s per real s · %d fps" % [sim.fight_seed, sim.now, sim.clock.display(), d.rate(), Engine.get_frames_per_second()],
		"distance %.2f m · range %s · position %s · roles %s" % [sim.distance(), sim.band(), sim.situation.position, ", ".join(sim.situation.roles)],
	]
	for i in sim.fighters.size():
		var f: FighterState = sim.fighters[i]
		lines.append("")
		lines.append("[color=%s][b]%s[/b][/color]  %s" % [FightLogFormatter.FIGHTER_COLOURS[i], f.name,
			"%s (%s, %d ticks left)" % [f.action_id, f.phase, f.phase_ticks_left] if f.action_id != "" else "free"])
		lines.append("  stamina %d/%d · damage head %d body %d legs %d · hurt %.2f/%.2f/%.2f" % [roundi(f.stamina), roundi(f.max_stamina()),
			f.damage.head, f.damage.body, f.damage.legs, f.hurt("head"), f.hurt("body"), f.hurt("legs")])
		lines.append("  wants %.1f m · circling %d%% · cutting off %d%% · cage %s · flags %s" % [sim.last_wanted_distance(i),
			roundi(sim.last_circling(i) * 100.0), roundi(sim.last_cutting(i) * 100.0), sim.cage_proximity(i), ", ".join(sim.active_flags(i))])
		var calls: LiveCalls = sim.decisions[i].calls
		lines.append("  voice %d · trust %d · attention %.2f · calls waiting %d · reads %d" % [roundi(calls.voice(sim.now)), roundi(calls.trust),
			calls.attention, calls.pending.size(), calls.reads.size()])
		lines.append("  [color=#8a8f98]%s[/color]" % FightLogFormatter.condition_line(f))
	return "\n".join(lines)
