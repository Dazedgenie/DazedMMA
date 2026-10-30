class_name MirrorCheck
extends RefCounted
## Plays a fight and its mirror tick by tick (D252, docs/01 §2.5): `usual` has red stepping
## first, `swapped` the same two fighters in the other corners with blue stepping first
## (FightSim.step_order). With no corner built into the engine they're the same fight, each
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
## spot turned through the centre, and the same events with the actors swapped.
static func mirrored(usual: FightSim, swapped: FightSim) -> bool:
	if usual.events.size() != swapped.events.size():
		return false
	for i in 2:
		if not usual.fighters[i].pos.is_equal_approx(-swapped.fighters[1 - i].pos):
			return false
	if usual.events.is_empty():
		return true
	var a: FightEvent = usual.events[-1]
	var b: FightEvent = swapped.events[-1]
	return a.type == b.type and a.tick == b.tick and (a.actor < 0 and b.actor < 0 or a.actor == 1 - b.actor)
