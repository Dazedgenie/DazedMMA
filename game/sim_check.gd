class_name SimCheck
extends RefCounted
## A short self-check fight for the debug console's "Run test fight" button.
##
## Plays one 60-second round with a few scripted commands (one deliberately bad),
## then replays it from seed + command log and checks that the core pieces work:
## data loads, the clock reaches the bell, strikes land and miss, bad commands are
## refused, and the replay is identical (docs/04-tech-and-production.md §2.2).

const ROUND_SECONDS: int = 60
## A shared machine can stall for a moment, so a fight over the time budget is
## simulated again, up to this many runs in all, and the fastest counts: a slow
## sim is slow every time (D105, docs/01 §2.1). Keep in step with test_fight_sim.gd.
const TIMING_TRIES: int = 3
## GitHub's shared test machines run up to about 1.6× slower than usual, so on CI (the
## CI environment variable is "true") a timed fight may take this much longer than
## its budget. A sim that really got 50% slower still fails (D105, docs/01 §2.1).
const CI_MARGIN: float = 1.5

## The fight that was checked, so the console can print its events.
var sim: FightSim
## [{name, passed, detail}] in the order they were checked.
var results: Array[Dictionary] = []
var elapsed_ms: float = 0.0
## How many runs the timing took (more than 1 only when the first was over budget).
var timing_runs: int = 1


static func run(fight_seed: int, actions: ActionLibrary = null) -> SimCheck:
	var check := SimCheck.new()
	check._run(fight_seed, actions if actions != null else ActionLibrary.load_dir())
	return check


func passed() -> bool:
	for r in results:
		if not r.passed:
			return false
	return not results.is_empty()


## Two plain jabbers (data/fighters/check_red.json, check_blue.json).
static func default_fighters() -> Array[FighterState]:
	return FighterLibrary.load_dir().make_pair("check_red", "check_blue")


## A kicker who likes range against a boxer who walks forward: shows the standing
## game (range, cage pressure, rocked and knockdowns) with the fighter AI.
static func showcase_fighters() -> Array[FighterState]:
	return FighterLibrary.load_dir().make_pair("kicker", "boxer")


func _run(fight_seed: int, actions: ActionLibrary) -> void:
	_check("Moves load from data/actions", actions.ids().size() > 0, "%d moves" % actions.ids().size())
	if actions.ids().is_empty():
		return

	var started: int = Time.get_ticks_usec()
	sim = _scripted_fight(fight_seed, actions)
	elapsed_ms = (Time.get_ticks_usec() - started) / 1000.0

	var expected_ticks: int = ROUND_SECONDS * FightClock.TICKS_PER_SECOND
	_check("Fight reaches the final bell", sim.is_over() and sim.now == expected_ticks,
		"%d of %d ticks" % [sim.now, expected_ticks])
	for f in sim.fighters:
		_check("%s throws, lands and misses strikes" % f.name,
			f.strikes_thrown > 0 and f.strikes_landed > 0 and f.strikes_landed < f.strikes_thrown,
			"landed %d of %d" % [f.strikes_landed, f.strikes_thrown])
	_check("Fighters walk into punching range", _count(FightEvent.RANGE_CHANGED) > 0,
		"%d range changes" % _count(FightEvent.RANGE_CHANGED))
	var cards: Array = sim.events[-1].data.get("cards", [])
	_check("Three judges score the fight", cards.size() == Judging.JUDGES,
		FightLogFormatter.result_text(sim.events[-1], sim))
	_check("Bad command is refused", _count(FightEvent.COMMAND_REJECTED) == 1,
		"%d refused" % _count(FightEvent.COMMAND_REJECTED))

	var saved: Variant = JSON.parse_string(JSON.stringify(sim.record()))
	var replayed: FightSim = FightSim.from_record(saved, FighterLibrary.load_dir(), actions)
	_check("Replay from seed + fighter ids + commands is identical",
		JSON.stringify(replayed.events_as_dicts()) == JSON.stringify(sim.events_as_dicts()),
		"%d events compared" % sim.events.size())
	# 60 fight-seconds at 1000x = 60 ms (docs/01 §2).
	var budget: float = budget_ms(ROUND_SECONDS)
	while elapsed_ms >= budget and timing_runs < TIMING_TRIES:
		started = Time.get_ticks_usec()
		_scripted_fight(fight_seed, actions)
		elapsed_ms = minf(elapsed_ms, (Time.get_ticks_usec() - started) / 1000.0)
		timing_runs += 1
	_check("Runs over 1000x faster than fight time", elapsed_ms < budget,
		"%.1f ms for %d fight-seconds%s%s" % [elapsed_ms, ROUND_SECONDS, " (fastest of %d runs)" % timing_runs if timing_runs > 1 else "",
		" (CI budget %.0f ms)" % budget if budget > ROUND_SECONDS else ""])


## A timing budget for this machine: as given, or CI_MARGIN times it on CI.
static func budget_ms(ms: float) -> float:
	return ms * (CI_MARGIN if OS.get_environment("CI") == "true" else 1.0)


## The check fight: one 60-second round with a few commands, one of them bad.
func _scripted_fight(fight_seed: int, actions: ActionLibrary) -> FightSim:
	var fight := FightSim.new(fight_seed, default_fighters(), actions, 1, ROUND_SECONDS)
	fight.submit(FightCommand.queue_action(20, 0, "body_kick"))
	fight.submit(FightCommand.queue_action(40, 1, "double_leg"))
	fight.submit(FightCommand.queue_action(60, 0, "not_a_real_move"))
	fight.run_to_end()
	return fight


func _check(check_name: String, ok: bool, detail: String) -> void:
	results.append({ "name": check_name, "passed": ok, "detail": detail })


func _count(type: String) -> int:
	var n: int = 0
	for e in sim.events:
		if e.type == type:
			n += 1
	return n
