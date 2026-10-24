extends MainLoop
## Headless entry point for the simulation layer. Runs without a scene tree.
##
## Usage:
##   godot --headless --script res://tools/run_sim.gd [-- --seed=123 --fights=100 --fighters=kicker,boxer]
##
## Runs one placeholder fight between two fighters from data/fighters (default:
## the showcase kicker and boxer) and prints a summary; with --fights=N it runs N
## seeds and prints how they ended.
## Later it becomes the balance harness (docs/10-prototype-spec.md, issue #18).


func _initialize() -> void:
	var fight_seed: int = 1
	var fights: int = 1
	var pair: PackedStringArray = ["kicker", "boxer"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			fight_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--fights="):
			fights = int(arg.trim_prefix("--fights="))
		elif arg.begins_with("--fighters="):
			pair = arg.trim_prefix("--fighters=").split(",")
	var actions := ActionLibrary.load_dir()
	var roster := FighterLibrary.load_dir()
	for id in pair:
		if not roster.has(id):
			printerr("No fighter '%s' in data/fighters (have: %s)" % [id, ", ".join(roster.ids())])
			return
	if fights > 1:
		_many(fight_seed, fights, actions, roster, pair)
		return
	var sim := FightSim.new(fight_seed, roster.make_pair(pair[0], pair[1]), actions)
	var clock: FightClock = sim.clock  # Captured instead of sim, so the listener doesn't keep sim alive.
	var started: int = Time.get_ticks_msec()
	var counts: Dictionary = {}
	sim.event_emitted.connect(func(e: FightEvent) -> void:
		counts[e.type] = counts.get(e.type, 0) + 1
		if e.type in [FightEvent.ROUND_ENDED, FightEvent.ROCKED, FightEvent.KNOCKDOWN]:
			print("%s  %s %s %s" % [clock.display(), e.type, e.actor, JSON.stringify(e.data)]))
	sim.run_to_end()
	print("Seed %d: fight over after %d ticks (%d fight-seconds), %d events, %d ms real time." % [
		fight_seed, sim.now, sim.now / FightClock.TICKS_PER_SECOND, sim.events.size(), Time.get_ticks_msec() - started])
	print("  " + _plain(FightLogFormatter.result_text(sim.events[-1], sim)))
	print("  events: " + JSON.stringify(counts))
	for f in sim.fighters:
		print("  %-6s landed %3d / %3d strikes, damage taken: head %d, body %d, legs %d" % [
			f.name, f.strikes_landed, f.strikes_thrown, f.damage.head, f.damage.body, f.damage.legs])
		print("         " + FightLogFormatter.condition_line(f))


## N fights on consecutive seeds: how often each fighter wins, and how.
func _many(first_seed: int, fights: int, actions: ActionLibrary, roster: FighterLibrary, pair: PackedStringArray) -> void:
	var tally: Dictionary = {}
	for n in fights:
		var sim := FightSim.new(first_seed + n, roster.make_pair(pair[0], pair[1]), actions)
		sim.run_to_end()
		var end: FightEvent = sim.events[-1]
		var key: String = "%s by %s" % ["draw" if end.data.winner < 0 else sim.fighters[end.data.winner].name, end.data.result]
		tally[key] = tally.get(key, 0) + 1
	print("%d fights from seed %d:" % [fights, first_seed])
	var keys: Array = tally.keys()
	keys.sort()
	for key: String in keys:
		print("  %-30s %d" % [key, tally[key]])


func _plain(bbcode: String) -> String:
	return RegEx.create_from_string("\\[[^\\]]*\\]").sub(bbcode, "", true)


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
