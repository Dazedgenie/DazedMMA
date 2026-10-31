class_name MirrorCheck
extends RefCounted
## Plays a fight and its mirror tick by tick (D252, D253, docs/01 §2.5): `usual` has red stepping
## first on the first tick, `swapped` the same two fighters in the other corners with blue stepping
## first on it (FightSim.first_step; they take turns after). With no corner built into the engine they're the same fight, each
## fighter's spot turned half way round the cage's centre.


## The first tick the two fights part (positions or events no longer mirror each other),
## or -1 when both play to the end the same. Plays both to that tick.
static func first_difference(usual: FightSim, swapped: FightSim) -> int:
	while not usual.is_over() and not swapped.is_over():
		usual.tick()
		swapped.tick()
		if not mirrored(usual, swapped):
			return usual.now - 1
	return -1 if usual.is_over() == swapped.is_over() and mirrored(usual, swapped) else usual.now - 1


## True when the two fights stand as mirrors right now: each fighter at the other fight's
## spot turned through the centre, and the same events on the latest tick with the actors swapped.
## Events on one tick are compared in any order: notices the sim makes for both fighters at once
## (the cage proximity, FightSim._update_space) come out red first in both fights, which is no
## corner's edge (D290 found it: both changed proximity on one tick).
static func mirrored(usual: FightSim, swapped: FightSim) -> bool:
	if usual.events.size() != swapped.events.size():
		return false
	for i in 2:
		if not usual.fighters[i].pos.is_equal_approx(-swapped.fighters[1 - i].pos):
			return false
	if usual.events.is_empty():
		return true
	return _last_tick(usual, false) == _last_tick(swapped, true)


## The latest tick's events as sorted "type tick actor" lines, with the actors swapped when `swap`.
static func _last_tick(sim: FightSim, swap: bool) -> Array[String]:
	var lines: Array[String] = []
	var tick: int = sim.events[-1].tick
	var k: int = sim.events.size() - 1
	while k >= 0 and sim.events[k].tick == tick:
		var e: FightEvent = sim.events[k]
		var actor: int = e.actor if e.actor < 0 or not swap else 1 - e.actor
		lines.append("%s %d %d" % [e.type, e.tick, actor])
		k -= 1
	lines.sort()
	return lines
