class_name FightSummary
extends RefCounted
## One fight boiled down to one row of numbers for the balance harness (#18,
## docs/12 §3 item 5, D95): who won and how, when it ended, knockdowns, strikes,
## damage, stamina (at the bell and the lowest it got), 10-10 cards, how often
## an exchange's odds hit the 5–95% clamp, and how the fighters moved (time on the
## fence, who held the centre, how much of it was a chase). BalanceReport turns
## rows into the CSV and the summary.

## Every key a row has, in CSV column order.
const COLUMNS: Array[String] = [
	"seed", "ruleset", "red", "blue", "winner", "winner_id", "result", "method", "end_round", "end_second",
	"knockdowns_red", "knockdowns_blue", "rocked_red", "rocked_blue",
	"thrown_red", "landed_red", "thrown_blue", "landed_blue",
	"head_damage_red", "body_damage_red", "leg_damage_red", "head_damage_blue", "body_damage_blue", "leg_damage_blue",
	"stamina_end_red", "stamina_low_red", "stamina_end_blue", "stamina_low_blue",
	"round_cards", "even_cards", "exchanges", "clamped", "events",
	"fence_red", "pinned_red", "centre_red", "fence_blue", "pinned_blue", "centre_blue", "chase",
]
const SIDES: Array[String] = ["red", "blue"]

const METHOD_KO := "ko"
const METHOD_TKO := "tko"
const METHOD_DECISION := "decision"
const METHOD_DRAW := "draw"
## Movement is counted on standing ticks with both fighters up. A chase tick: one
## fighter steps back at least this far (metres in a tick) while the other steps in.
const CHASE_STEP: float = 0.01


## Runs one fight between two data/fighters ids and summarises it. `rules` is
## whatever FightSim takes (a Ruleset, a round count for short tests, or null for pro).
static func run(fight_seed: int, roster: FighterLibrary, actions: ActionLibrary, red_id: String, blue_id: String, rules: Variant = null, round_seconds: int = 300) -> Dictionary:
	var sim := FightSim.new(fight_seed, roster.make_pair(red_id, blue_id), actions, rules, round_seconds)
	var lows: Array[float] = [1.0, 1.0]
	var moves := { "standing": 0, "chase": 0, "fence": [0, 0], "pinned": [0, 0], "centre": [0, 0] }
	while not sim.is_over():
		var before: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
		var round_before: int = sim.clock.current_round
		sim.tick()
		for i in 2:
			lows[i] = minf(lows[i], sim.fighters[i].stamina_fraction())
		if sim.clock.current_round == round_before:  # Not the tick they went back to their corners.
			count_movement(sim, before, moves)
	return of(sim, lows, moves)


## Adds one tick to the movement counts: `before` is where the fighters stood before it.
static func count_movement(sim: FightSim, before: Array[Vector2], moves: Dictionary) -> void:
	if sim.is_over() or not sim.situation.is_standing() or sim.fighters[0].is_down() or sim.fighters[1].is_down():
		return
	moves.standing += 1
	var steps: Array[float] = []
	for i in 2:
		var proximity: String = sim.cage_proximity(i)
		if proximity != Octagon.CAGE_CENTRE:
			moves.fence[i] += 1
		if proximity == Octagon.CAGE_PINNED:
			moves.pinned[i] += 1
		var to_other: Vector2 = before[1 - i] - before[i]
		steps.append((sim.fighters[i].pos - before[i]).dot(to_other.normalized()) if to_other.length() > 0.0 else 0.0)
	var from_centre: Array[float] = [sim.fighters[0].pos.length(), sim.fighters[1].pos.length()]
	if from_centre[0] < from_centre[1]:
		moves.centre[0] += 1
	elif from_centre[1] < from_centre[0]:
		moves.centre[1] += 1
	if (steps[0] < -CHASE_STEP and steps[1] > CHASE_STEP) or (steps[1] < -CHASE_STEP and steps[0] > CHASE_STEP):
		moves.chase += 1


## The row for a finished fight. `lows` is each fighter's lowest stamina share
## during it (run() tracks it tick by tick; it defaults to the share at the bell).
## `moves` is run()'s movement counts (count_movement); without them the movement columns are 0.
static func of(sim: FightSim, lows: Array[float] = [], moves: Dictionary = {}) -> Dictionary:
	assert(sim.is_over(), "summarise a fight once it's over")
	var end: FightEvent = sim.events[-1]
	var winner: int = end.data.winner
	var row := {
		"seed": sim.fight_seed, "ruleset": sim.ruleset.id,
		"red": sim.fighters[0].id, "blue": sim.fighters[1].id,
		"winner": "draw" if winner < 0 else SIDES[winner],
		"winner_id": "" if winner < 0 else sim.fighters[winner].id,
		"result": end.data.result, "method": method_of(end.data.result),
		"end_round": end.round_number, "end_second": sim.clock.tick_in_round / FightClock.TICKS_PER_SECOND,
		"round_cards": 0, "even_cards": 0, "exchanges": 0, "clamped": 0, "events": sim.events.size(),
	}
	var standing: int = moves.get("standing", 0)
	row.chase = _share_of(moves.get("chase", 0), standing)
	for i in 2:
		var f: FighterState = sim.fighters[i]
		var side: String = SIDES[i]
		row["knockdowns_" + side] = f.knockdowns
		row["rocked_" + side] = 0
		row["thrown_" + side] = f.strikes_thrown
		row["landed_" + side] = f.strikes_landed
		row["head_damage_" + side] = f.damage.head
		row["body_damage_" + side] = f.damage.body
		row["leg_damage_" + side] = f.damage.legs
		row["stamina_end_" + side] = snappedf(f.stamina_fraction(), 0.001)
		row["stamina_low_" + side] = snappedf(minf(lows[i] if i < lows.size() else 1.0, f.stamina_fraction()), 0.001)
		for key: String in ["fence", "pinned", "centre"]:
			row[key + "_" + side] = _share_of(moves.get(key, [0, 0])[i], standing)
	for e in sim.events:
		match e.type:
			FightEvent.ROCKED:
				row["rocked_" + SIDES[e.actor]] += 1
			FightEvent.ROUND_ENDED:
				for card: Array in e.data.cards:
					row.round_cards += 1
					if card[0] == card[1]:
						row.even_cards += 1
			FightEvent.STRIKE_LANDED, FightEvent.STRIKE_MISSED:
				if e.data.has("odds"):
					row.exchanges += 1
					if e.data.odds.get("clamped", false):
						row.clamped += 1
	return row


## "ko", "tko", "decision" or "draw" from a fight_ended result.
static func method_of(result: String) -> String:
	match result:
		FightSim.RESULT_KO:
			return METHOD_KO
		FightSim.RESULT_TKO:
			return METHOD_TKO
		Judging.DRAW:
			return METHOD_DRAW
	return METHOD_DECISION


## Ticks as a share of standing ticks, rounded for the CSV.
static func _share_of(ticks: int, standing: int) -> float:
	return snappedf(float(ticks) / standing, 0.001) if standing > 0 else 0.0
