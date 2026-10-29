class_name FightClock
extends RefCounted
## Fight time in fixed simulation ticks (docs/01-fight-engine.md §2).
##
## Simulation layer: pure logic, no Node or scene-tree dependencies, never reads
## real time. Presentation decides how fast ticks are fed in (Normal 2x, Fast 4x,
## slow-mo), so the result is identical at any speed.

const TICK_MS: int = 100
const TICKS_PER_SECOND: int = 1000 / TICK_MS

var round_seconds: int
var rounds: int
var current_round: int = 1
var tick_in_round: int = 0
## Each round's own length in seconds when they differ (PRIDE's 10-minute first round,
## D141); empty = every round is round_seconds.
var round_lengths: Array[int] = []


func _init(p_rounds: int = 3, p_round_seconds: int = 300, p_round_lengths: Array[int] = []) -> void:
	rounds = p_rounds
	round_seconds = p_round_seconds
	round_lengths = p_round_lengths


## The current round's length in ticks.
func ticks_per_round() -> int:
	return ticks_in_round(current_round)


## Round `n`'s length in ticks (1 is the first).
func ticks_in_round(n: int) -> int:
	if n >= 1 and n <= round_lengths.size():
		return round_lengths[n - 1] * TICKS_PER_SECOND
	return round_seconds * TICKS_PER_SECOND


## The fight tick round `n` starts on (round 1 starts on tick 0). Rounds follow each other
## tick after tick: the corner between them takes no fight time.
func round_start_tick(n: int) -> int:
	var out: int = 0
	for r in range(1, n):
		out += ticks_in_round(r)
	return out


## Advances one tick. Returns true when this tick ended the current round.
func tick() -> bool:
	if is_fight_over():
		return false
	tick_in_round += 1
	return is_round_over()


func is_round_over() -> bool:
	return tick_in_round >= ticks_per_round()


func is_fight_over() -> bool:
	return current_round == rounds and is_round_over()


## Moves to the next round after the corner. Does nothing after the last round.
func start_next_round() -> void:
	if current_round < rounds:
		current_round += 1
		tick_in_round = 0


func seconds_remaining() -> int:
	return int(ceil(float(ticks_per_round() - tick_in_round) / TICKS_PER_SECOND))


## Broadcast-style clock, e.g. "R2 3:41".
func display() -> String:
	var remaining: int = seconds_remaining()
	return "R%d %d:%02d" % [current_round, remaining / 60, remaining % 60]
