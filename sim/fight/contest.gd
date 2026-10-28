class_name Contest
extends RefCounted
## The one odds formula every contested moment uses: strikes, takedowns,
## sprawls, and later clinch fights, sub lock-ins and scrambles
## (docs/11-attributes-and-traits.md §3.1):
##
##   chance = action base + (attack stats − defense stats) / 100 + situation bonuses
##
## clamped to 5–95%, so stats tilt the odds and never guarantee (docs/11 §1).
## Stats here are effective stats (FighterState.effective_stat), so a tired or
## hurt fighter contests below their numbers.

const MIN_CHANCE: float = 0.05
const MAX_CHANCE: float = 0.95
## Strikes have no base in their data; a jab between equal fighters lands half the time.
const STRIKE_BASE: float = 0.5


static func chance(base: float, attack: float, defense: float, bonus: float = 0.0) -> float:
	return clampf(base + (attack - defense) / 100.0 + bonus, MIN_CHANCE, MAX_CHANCE)


## The action's starting odds before stats: strike 50%, takedowns and defenses from their data.
static func base_for(action: Dictionary) -> float:
	match action.category:
		"takedown", "defense", "clinch", "ground", "submission":
			return float(action[action.category].base_success)
	return STRIKE_BASE
