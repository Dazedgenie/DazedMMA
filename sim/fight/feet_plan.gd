class_name FeetPlan
extends RefCounted
## One fighter's footwork for a tick (docs/01 §3, D107): how far apart they want to be,
## how much they circle and which way, and how hard they cut the cage off. The decision
## step fills it on every free standing tick (DecisionLayer.plan_feet) and the sim's
## feet carry it out. One per fighter, reused, so the hot loop doesn't allocate.

## Metres apart.
var want: float = 0.0
## How much they circle while they move: 0 = straight in or out, 1 = all they can.
var circle: float = 0.0
## Which way they circle: 0 = the side toward the middle, ±1 = one way or the other
## round the opponent (FightSim.way_toward_middle).
var way: int = 0
## How hard they cut the cage off: 0 = not at all, 1 = all their feet allow.
var cut: float = 0.0
## Cut the cage! (D230): cut off the exits even out in open space (FightSim.CUT_CALLED_FROM),
## not just as the fence closes in.
var anywhere: bool = false
