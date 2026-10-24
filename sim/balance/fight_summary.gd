class_name FightSummary
extends RefCounted
## One fight boiled down to one row of numbers for the balance harness (#18,
## docs/12 §3 item 5, D95): who won and how, when it ended, knockdowns, strikes,
## damage, stamina (at the bell and the lowest it got), 10-10 cards and how often
## an exchange's odds hit the 5–95% clamp. BalanceReport turns rows into the CSV
## and the summary.

## Every key a row has, in CSV column order.
const COLUMNS: Array[String] = [
	"seed", "ruleset", "red", "blue", "winner", "winner_id", "result", "method", "end_round", "end_second",
	"knockdowns_red", "knockdowns_blue", "rocked_red", "rocked_blue",
	"thrown_red", "landed_red", "thrown_blue", "landed_blue",
	"head_damage_red", "body_damage_red", "leg_damage_red", "head_damage_blue", "body_damage_blue", "leg_damage_blue",
	"stamina_end_red", "stamina_low_red", "stamina_end_blue", "stamina_low_blue",
	"round_cards", "even_cards", "exchanges", "clamped", "events",
]
const SIDES: Array[String] = ["red", "blue"]

const METHOD_KO := "ko"
const METHOD_TKO := "tko"
const METHOD_DECISION := "decision"
const METHOD_DRAW := "draw"


## Runs one fight between two data/fighters ids and summarises it. `rules` is
## whatever FightSim takes (a Ruleset, a round count for short tests, or null for pro).
static func run(fight_seed: int, roster: FighterLibrary, actions: ActionLibrary, red_id: String, blue_id: String, rules: Variant = null, round_seconds: int = 300) -> Dictionary:
	var sim := FightSim.new(fight_seed, roster.make_pair(red_id, blue_id), actions, rules, round_seconds)
	var lows: Array[float] = [1.0, 1.0]
	while not sim.is_over():
		sim.tick()
		for i in 2:
			lows[i] = minf(lows[i], sim.fighters[i].stamina_fraction())
	return of(sim, lows)


## The row for a finished fight. `lows` is each fighter's lowest stamina share
## during it (run() tracks it tick by tick; it defaults to the share at the bell).
static func of(sim: FightSim, lows: Array[float] = []) -> Dictionary:
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
