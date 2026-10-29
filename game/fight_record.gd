class_name FightRecord
extends RefCounted
## What a fight on the fight screen leaves behind for the playtest write-up (#20, D118):
## the replay (seed + fighters + every command, FightSim.record), the settings it was
## played with, how it ended, and the coaching numbers docs/10 §2 asks about (well-timed
## takedowns, perfect calls, calls ignored). Saved as one JSON file per fight in
## user://fights/; tools/playtest_report.gd adds a folder of them up. A fighter who
## came out of the camp planner (D133) is kept whole in `profiles`, so the fight still replays.

const SCHEMA := "fight_record@1"
const DIR := "user://fights/"
## The settings worth keeping with the fight (FightSetup.settings()).
const KEPT_SETTINGS: Array[String] = ["label", "step", "tester", "normal_rate", "easy", "tell_cues", "auto_slow", "flourishes", "camp"]


## The record of a finished (or towelled) fight, as plain data.
static func build(sim: FightSim, settings: Dictionary, player: int = 0) -> Dictionary:
	var kept := {}
	for key in KEPT_SETTINGS:
		if settings.has(key):
			kept[key] = settings[key]
	var fighters: Array = []
	for f in sim.fighters:
		fighters.append({ "id": f.id, "name": f.name, "strikes_landed": f.strikes_landed, "strikes_thrown": f.strikes_thrown,
			"takedowns_landed": f.takedowns_landed, "takedowns_tried": f.takedowns_tried, "damage": f.damage.duplicate() })
	var ended: Dictionary = {}
	if not sim.events.is_empty() and sim.events[-1].type == FightEvent.FIGHT_ENDED:
		ended = sim.events[-1].data.duplicate(true)
	var profiles: Dictionary = {}
	if settings.get("red_profile") is Dictionary:
		profiles[settings.red_profile.id] = settings.red_profile
	return {
		"schema": SCHEMA,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": "%s %s" % [ProjectSettings.get_setting("application/config/name"), Engine.get_version_info().string],
		"settings": kept,
		"player": player,
		"result": ended,
		"won": int(ended.get("winner", -1)) == player,
		"rounds_played": sim.clock.current_round,
		"stats": coaching_stats(sim, player),
		"fighters": fighters,
		"replay": _replay(sim),
		"profiles": profiles,
	}


## sim.record() plus how many ticks the fight lasted, so a replay can be checked against it.
static func _replay(sim: FightSim) -> Dictionary:
	var rec: Dictionary = sim.record()
	rec.ticks = sim.now
	return rec


## The coaching numbers for one corner: calls made and ignored, perfect calls, and takedowns
## that worked split by who chose them (the player's call, a drilled rule, the fighter's own AI).
static func coaching_stats(sim: FightSim, player: int) -> Dictionary:
	var started_by: Array[String] = ["", ""]
	var calls := {}
	var out := { "calls_made": 0, "calls_ignored": 0, "calls_by_id": calls, "perfect_calls": 0,
		"takedowns_by_call": 0, "takedowns_by_rule": 0, "takedowns_own": 0, "catch_kicks_landed": 0, "rules_fired": 0 }
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph":
			started_by[e.actor] = String(e.data.get("by", ""))
		if e.actor != player:
			continue
		match e.type:
			FightEvent.CALL_HEARD:
				out.calls_made += 1
				calls[e.data.call_id] = int(calls.get(e.data.call_id, 0)) + 1
			FightEvent.CALL_ANSWERED:
				if e.data.outcome == LiveCalls.IGNORED:
					out.calls_ignored += 1
			FightEvent.RULE_ANSWERED:
				if e.data.outcome == DrilledRules.FIRED:
					out.rules_fired += 1
			FightEvent.GRAPPLE_WON, FightEvent.STRIKE_LANDED:
				if FightDriver.counts_as_perfect(e, started_by[player], sim.actions):
					out.perfect_calls += 1
				if e.type == FightEvent.GRAPPLE_WON and e.data.result == PositionLibrary.SUCCESS \
						and sim.actions.has(e.data.action_id) and sim.actions.get_action(e.data.action_id).category == "takedown":
					match started_by[player]:
						DecisionLayer.CALL:
							out.takedowns_by_call += 1
						DecisionLayer.RULE:
							out.takedowns_by_rule += 1
						_:
							out.takedowns_own += 1
					if e.data.action_id == "catch_kick_single":
						out.catch_kicks_landed += 1
	return out


## Saves a record as JSON in `dir`; returns the file's path ("" if it couldn't be written).
static func save(record: Dictionary, dir: String = DIR) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp: String = String(record.get("saved_at", "")).replace(":", "-").replace("T", "_")
	var who: String = String(record.settings.get("tester", "")).strip_edges().to_lower().replace(" ", "-").validate_filename()
	var what: String = String(record.settings.get("step", "")) if record.settings.get("step", "") != "" else "free"
	var name: String = "%s_%s%s_seed%d.json" % [stamp, (who + "_") if who != "" else "", what, int(record.replay.seed)]
	var path: String = dir.path_join(name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	return path
