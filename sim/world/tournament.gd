class_name Tournament
extends RefCounted
## The one-day amateur tournament (docs/03 §11.5, D315; `08` §2: "a one-day bracket of 2–3 short fights, with damage
## carrying over between them"). Every few months, while he's amateur, one offer in a set is a tournament instead of a
## single fight: a small local open (SIZES[0], four men: semi-final and final) or a bigger regional one (SIZES[1], eight
## men: quarter-final, semi-final and final). The men he'd meet if he keeps winning are made when it's offered, one a
## round, each harder than the last. On fight night he fights them one after another: each win takes him to the next
## round carrying what the last fight did to him (CARRY_HURT of his damage, his gas tank TANK_PER_FIGHT smaller); a
## loss or a draw (amateur tournaments need a winner) puts him out. A medal goes on his card: gold for winning it,
## silver for losing the final, bronze for losing a semi-final he won a quarter-final to reach (both of an eight-man
## bracket's semi-final losers get one; a four-man open's semi-final losers go home with nothing, or every man would
## have a medal).
##
## Pure data and rules; Career keeps the tournament on `booked.tournament` and Matchmaker makes the offer.

## How many men: a local open, a regional championship.
const SIZES: Array[int] = [4, 8]
## The chance an offered tournament is the bigger one.
const BIG_CHANCE: float = 0.5
## The first tournament comes this many weeks into a career, then one every GAP_MIN–GAP_MAX weeks (3 to 4 months).
const FIRST_WEEK: int = 12
const GAP_MIN: int = 13
const GAP_MAX: int = 17
## The men in the bracket, round by round, get harder (Matchmaker's DIFFICULTY_LEVELS).
const DIFFICULTIES: Array[String] = ["easier", "even", "harder"]
## Between fights he gets back some of it: this share of each area's damage carries into the next fight …
const CARRY_HURT: float = 0.7
## … and his gas tank is this much smaller for each fight he's had that day (never under TrainingCamp.TANK_FLOOR).
const TANK_PER_FIGHT: float = 0.1
## The men he meets later in the day have had fights too: their gas tank at each round (first round fresh).
const OPPONENT_TANK: Array[float] = [1.0, 0.92, 0.85]
## The rounds' names, from the end: the last is the final.
const STAGE_NAMES: Array[String] = ["Quarter-final", "Semi-final", "Final"]
## Medals.
const GOLD := "gold"
const SILVER := "silver"
const BRONZE := "bronze"
const CARDS_SMALL := "res://data/cards/open.json"
const CARDS_BIG := "res://data/cards/championship.json"


## How many fights a bracket of this size is for the winner (4 → 2, 8 → 3).
static func rounds(size: int) -> int:
	return maxi(1, roundi(log(float(size)) / log(2.0)))


## A round's name in a bracket of this size: "Semi-final" for the first of a four-man bracket's two.
static func stage_name(size: int, stage: int) -> String:
	var n: int = rounds(size)
	var from_end: int = n - 1 - stage
	return STAGE_NAMES[STAGE_NAMES.size() - 1 - from_end] if from_end < STAGE_NAMES.size() else "Round %d" % (stage + 1)


## The medal for going out at `stage` (or winning the last), "" for none.
static func medal(size: int, stage: int, won: bool) -> String:
	var last: int = rounds(size) - 1
	if stage == last:
		return GOLD if won else SILVER
	if not won and stage == last - 1 and stage > 0:
		return BRONZE  # Only when he won a round to get there: in a four-man open every man would get a medal.
	return ""


## What he carries into the next fight: his damage at the end of the last (area → 0–1, as FighterState.hurt reads it)
## and the gas tank he went in with. Returns a fighter@1 `condition`: { tank, hurt }.
static func carry_over(tank_before: float, hurt_after: Dictionary) -> Dictionary:
	var hurt: Dictionary = {}
	for area: String in hurt_after:
		var h: float = clampf(float(hurt_after[area]) * CARRY_HURT, 0.0, 1.0)
		if h > 0.0:
			hurt[area] = snappedf(h, 0.001)
	return { "tank": snappedf(maxf(TrainingCamp.TANK_FLOOR, tank_before - TANK_PER_FIGHT), 0.001), "hurt": hurt }


## The card data for a tournament of this size (data/cards/open.json or championship.json, docs/09 cards@1).
static func cards(size: int) -> Dictionary:
	var path: String = CARDS_BIG if size > SIZES[0] else CARDS_SMALL
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

