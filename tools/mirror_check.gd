extends MainLoop
## Checks a fight has no corner built into it (D252, docs/01 §2.5): plays --red vs --blue on
## --seed with red stepping first, as every real fight does, and the same two fighters in the
## other corners with blue stepping first. Those two should be the same fight mirrored through
## the cage's centre. Prints the first tick where they part, with each one's last events, or
## that they never did.
##
##   godot --headless --script res://tools/mirror_check.gd -- --red=kicker --blue=boxer --seed=1 [--seconds=300] [--rounds=3]


func _initialize() -> void:
	var red: String = "boxer"
	var blue: String = "boxer"
	var fight_seed: int = 1
	var seconds: int = 300
	var rounds: int = 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--red="):
			red = arg.trim_prefix("--red=")
		elif arg.begins_with("--blue="):
			blue = arg.trim_prefix("--blue=")
		elif arg.begins_with("--seed="):
			fight_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--seconds="):
			seconds = int(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
	var actions := ActionLibrary.load_dir()
	var roster := FighterLibrary.load_dir()
	for id in [red, blue]:
		if not roster.has(id):
			printerr("No fighter '%s' in data/fighters" % id)
			return
	var usual: FightSim = FightSummary.setup(fight_seed, roster, actions, red, blue, rounds, seconds)
	var swapped: FightSim = FightSummary.setup(fight_seed, roster, actions, blue, red, rounds, seconds)
	swapped.step_order = [1, 0]
	var tick: int = MirrorCheck.first_difference(usual, swapped)
	if tick < 0:
		print("%s vs %s, seed %d: the same fight both ways round, %d ticks, %d events." % [red, blue, fight_seed, usual.now, usual.events.size()])
		return
	print("%s vs %s, seed %d: the fights part on tick %d (%.1f s in)." % [red, blue, fight_seed, tick, float(tick) / FightClock.TICKS_PER_SECOND])
	print("Red stepping first, last events:")
	for e in usual.events.slice(-6):
		print("  ", e.to_dict())
	print("Corners swapped, blue stepping first, last events (red and blue are the other way round):")
	for e in swapped.events.slice(-6):
		print("  ", e.to_dict())


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
