extends MainLoop
## Headless entry point for the simulation layer. Runs without a scene tree.
##
## Usage:
##   godot --headless --script res://tools/run_sim.gd
##
## Today it runs a full 3-round fight clock; later it becomes the balance
## harness (docs/10-prototype-spec.md, issue #18).


func _initialize() -> void:
	var clock := FightClock.new()
	var ticks: int = 0
	while not clock.is_fight_over():
		if clock.tick():
			print("%s  end of round (%d ticks)" % [clock.display(), ticks + 1])
			clock.start_next_round()
		ticks += 1
	print("Fight over after %d ticks (%d fight-seconds)." % [ticks, ticks / FightClock.TICKS_PER_SECOND])


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
