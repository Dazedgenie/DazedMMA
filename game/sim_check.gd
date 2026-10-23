class_name SimCheck
extends RefCounted
## A short self-check fight for the debug console's "Run test fight" button.
##
## Plays one 60-second round with a few scripted commands (one deliberately bad),
## then replays it from seed + command log and checks that the core pieces work:
## data loads, the clock reaches the bell, strikes land and miss, bad commands are
## refused, and the replay is identical (docs/04-tech-and-production.md §2.2).

const ROUND_SECONDS: int = 60

## The fight that was checked, so the console can print its events.
var sim: FightSim
## [{name, passed, detail}] in the order they were checked.
var results: Array[Dictionary] = []
var elapsed_ms: float = 0.0


static func run(fight_seed: int, actions: ActionLibrary = null) -> SimCheck:
	var check := SimCheck.new()
	check._run(fight_seed, actions if actions != null else ActionLibrary.load_dir())
	return check


func passed() -> bool:
	for r in results:
		if not r.passed:
			return false
	return not results.is_empty()


static func default_fighters() -> Array[FighterState]:
	return [
		FighterState.new("Red", { "boxing": 60, "speed": 55, "striking_defense": 50 }),
		FighterState.new("Blue", { "boxing": 50, "speed": 50, "striking_defense": 55 }),
	]


func _run(fight_seed: int, actions: ActionLibrary) -> void:
	_check("Moves load from data/actions", actions.ids().size() > 0, "%d moves" % actions.ids().size())
	if actions.ids().is_empty():
		return

	var started: int = Time.get_ticks_usec()
	sim = FightSim.new(fight_seed, default_fighters(), actions, 1, ROUND_SECONDS)
	sim.submit(FightCommand.queue_action(20, 0, "body_kick"))
	sim.submit(FightCommand.queue_action(40, 1, "double_leg"))
	sim.submit(FightCommand.queue_action(60, 0, "not_a_real_move"))
	sim.run_to_end()
	elapsed_ms = (Time.get_ticks_usec() - started) / 1000.0

	var expected_ticks: int = ROUND_SECONDS * FightClock.TICKS_PER_SECOND
	_check("Fight reaches the final bell", sim.is_over() and sim.now == expected_ticks,
		"%d of %d ticks" % [sim.now, expected_ticks])
	for f in sim.fighters:
		_check("%s throws, lands and misses strikes" % f.name,
			f.strikes_thrown > 0 and f.strikes_landed > 0 and f.strikes_landed < f.strikes_thrown,
			"landed %d of %d" % [f.strikes_landed, f.strikes_thrown])
	_check("Bad command is refused", _count(FightEvent.COMMAND_REJECTED) == 1,
		"%d refused" % _count(FightEvent.COMMAND_REJECTED))

	var replayed: FightSim = FightSim.replay(fight_seed, default_fighters(), actions, sim.command_log_as_dicts(), 1, ROUND_SECONDS)
	_check("Replay from seed + commands is identical",
		JSON.stringify(replayed.events_as_dicts()) == JSON.stringify(sim.events_as_dicts()),
		"%d events compared" % sim.events.size())
	# 60 fight-seconds at 1000x = 60 ms (docs/01 §2).
	_check("Runs over 1000x faster than fight time", elapsed_ms < ROUND_SECONDS,
		"%.1f ms for %d fight-seconds" % [elapsed_ms, ROUND_SECONDS])


func _check(check_name: String, ok: bool, detail: String) -> void:
	results.append({ "name": check_name, "passed": ok, "detail": detail })


func _count(type: String) -> int:
	var n: int = 0
	for e in sim.events:
		if e.type == type:
			n += 1
	return n
