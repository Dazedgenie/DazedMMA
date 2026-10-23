extends MainLoop
## Headless entry point for the simulation layer. Runs without a scene tree.
##
## Usage:
##   godot --headless --script res://tools/run_sim.gd [-- --seed=123]
##
## Today it runs one placeholder fight (two fighters trading jabs) and prints a
## summary; later it becomes the balance harness (docs/10-prototype-spec.md, issue #18).


func _initialize() -> void:
	var fight_seed: int = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			fight_seed = int(arg.trim_prefix("--seed="))
	var fighters: Array[FighterState] = [
		FighterState.new("Red", { "boxing": 60, "speed": 55, "striking_defense": 50 }),
		FighterState.new("Blue", { "boxing": 50, "speed": 50, "striking_defense": 55 }),
	]
	var sim := FightSim.new(fight_seed, fighters, ActionLibrary.load_dir())
	var clock: FightClock = sim.clock  # Captured instead of sim, so the listener doesn't keep sim alive.
	var started: int = Time.get_ticks_msec()
	sim.event_emitted.connect(func(e: FightEvent) -> void:
		if e.type == FightEvent.ROUND_ENDED:
			print("%s  end of round %d" % [clock.display(), e.round_number]))
	sim.run_to_end()
	print("Seed %d: fight over after %d ticks (%d fight-seconds), %d events, %d ms real time." % [
		fight_seed, sim.now, sim.now / FightClock.TICKS_PER_SECOND, sim.events.size(), Time.get_ticks_msec() - started])
	for f in sim.fighters:
		print("  %-5s landed %3d / %3d jabs, took head damage %d" % [f.name, f.strikes_landed, f.strikes_thrown, f.damage.head])
		print("        " + FightLogFormatter.condition_line(f))


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
