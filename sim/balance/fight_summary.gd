class_name FightSummary
extends RefCounted
## One fight boiled down to one row of numbers for the balance harness (#18,
## docs/12 §3 item 5, D95): who won and how, when it ended, knockdowns, strikes,
## damage, stamina (at the bell and the lowest it got), 10-10 cards, how often
## an exchange's odds hit the 5–95% clamp, how the fighters moved (time on the
## fence, who held the centre, how much of it was a chase, how long each one circled
## and cut off the cage, D119), and the grappling
## (takedowns tried and landed, time in the clinch, on the ground and on top, #15;
## submissions tried and locked in, D126, and the leg locks among them and fights they ended, D132; time in each ground position, passes and escapes, D130;
## feints thrown and bitten on, and shots taken blind and how many still worked, D131),
## each corner's coaching bot and how many calls it made (Corner, D12, D68), and each
## fighter's drilled rules and how often they fired (DrilledRules, #17).
## BalanceReport turns rows into the CSV and the summary.

## Every key a row has, in CSV column order.
const COLUMNS: Array[String] = [
	"seed", "ruleset", "red", "blue", "corner_red", "corner_blue", "rules_red", "rules_blue", "winner", "winner_id", "result", "method", "end_round", "end_second", "fight_seconds",
	"knockdowns_red", "knockdowns_blue", "rocked_red", "rocked_blue",
	"thrown_red", "landed_red", "thrown_blue", "landed_blue",
	"head_damage_red", "body_damage_red", "leg_damage_red", "head_damage_blue", "body_damage_blue", "leg_damage_blue",
	"stamina_end_red", "stamina_low_red", "stamina_end_blue", "stamina_low_blue",
	"round_cards", "even_cards", "exchanges", "clamped", "events",
	"fence_red", "pinned_red", "centre_red", "fence_blue", "pinned_blue", "centre_blue", "chase",
	"circling_red", "cutting_red", "circling_blue", "cutting_blue",
	"shots_red", "takedowns_red", "shots_blue", "takedowns_blue", "clinch", "ground", "top_red", "top_blue",
	"subs_red", "locked_red", "subs_blue", "locked_blue",
	"leg_locks_red", "leg_locked_red", "leg_locks_blue", "leg_locked_blue", "leg_lock_finish",
	"throws_red", "throws_landed_red", "throws_blue", "throws_landed_blue",
	"collar_ties_red", "collar_ties_won_red", "clinch_knees_red", "tied_knees_red",
	"collar_ties_blue", "collar_ties_won_blue", "clinch_knees_blue", "tied_knees_blue",
	"full_guard", "half_guard", "side_control", "mount", "back_control", "advances_red", "escapes_red", "advances_blue", "escapes_blue",
	"feints_red", "feints_bit_red", "blind_red", "blind_landed_red", "feints_blue", "feints_bit_blue", "blind_blue", "blind_landed_blue",
	"calls_red", "calls_blue", "fired_red", "fired_blue",
]
const SIDES: Array[String] = ["red", "blue"]
## The ground positions whose share of the fight each row reports (D130).
const GROUND_POSITIONS: Array[String] = ["full_guard", "half_guard", "side_control", "mount", "back_control"]

const METHOD_KO := "ko"
const METHOD_TKO := "tko"
const METHOD_SUB := "submission"
const METHOD_DECISION := "decision"
const METHOD_DRAW := "draw"
## Movement is counted on standing ticks with both fighters up. A chase tick: one
## fighter steps back at least this far (metres in a tick) while the other steps in.
const CHASE_STEP: float = 0.01


## Runs one fight between two data/fighters ids and summarises it. `rules` is
## whatever FightSim takes (a Ruleset, a round count for short tests, or null for pro).
## `corners` is each corner's coaching bot, a Corner style ([] or "none" = no calls).
## `drilled` is each fighter's drilled rules, slot 1 first, as "rule_id@percent" ([] = none).
static func run(fight_seed: int, roster: FighterLibrary, actions: ActionLibrary, red_id: String, blue_id: String, rules: Variant = null, round_seconds: int = 300, corners: Array[String] = [], drilled: Array = []) -> Dictionary:
	return play(setup(fight_seed, roster, actions, red_id, blue_id, rules, round_seconds, corners, drilled))


## The fight run() plays, set up but not started: the same arguments as run().
## The golden fights (GoldenFights, D122) use it to keep the finished fight.
static func setup(fight_seed: int, roster: FighterLibrary, actions: ActionLibrary, red_id: String, blue_id: String, rules: Variant = null, round_seconds: int = 300, corners: Array[String] = [], drilled: Array = []) -> FightSim:
	var sim := FightSim.new(fight_seed, roster.make_pair(red_id, blue_id), actions, rules, round_seconds)
	for i in drilled.size():
		var slot: int = 1
		for entry: String in drilled[i]:
			var parts: PackedStringArray = entry.split("@")
			sim.submit(FightCommand.set_rule(0, i, slot, parts[0], float(parts[1]) if parts.size() > 1 else 100.0))
			slot += 1
	for i in corners.size():
		if corners[i] != Corner.NONE:
			sim.corners[i] = Corner.new(corners[i], corner_seed(fight_seed, i))
	return sim


## Plays a set-up fight to the end, tracking stamina lows and movement tick by
## tick, and summarises it.
static func play(sim: FightSim) -> Dictionary:
	var lows: Array[float] = [1.0, 1.0]
	var moves := { "standing": 0, "chase": 0, "fence": [0, 0], "pinned": [0, 0], "centre": [0, 0],
		"ticks": 0, "clinch": 0, "ground": 0, "top": [0, 0] }
	while not sim.is_over():
		var before: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
		var round_before: int = sim.clock.current_round
		sim.tick()
		for i in 2:
			lows[i] = minf(lows[i], sim.fighters[i].stamina_fraction())
		if sim.clock.current_round == round_before:  # Not the tick they went back to their corners.
			count_movement(sim, before, moves)
	return of(sim, lows, moves)


## The seed of a coaching bot's own RNG: fixed by the fight's seed and its corner.
static func corner_seed(fight_seed: int, side: int) -> int:
	return hash([fight_seed, side, "corner"])


## Adds one tick to the movement counts: `before` is where the fighters stood before it.
## Tied-up ticks count toward the clinch, ground and top shares instead.
static func count_movement(sim: FightSim, before: Array[Vector2], moves: Dictionary) -> void:
	if sim.is_over():
		return
	moves.ticks = moves.get("ticks", 0) + 1
	if not sim.situation.is_standing():
		var key: String = "clinch" if sim.situation.phase == PositionLibrary.CLINCH else "ground"
		moves[key] = moves.get(key, 0) + 1
		if GROUND_POSITIONS.has(sim.situation.position):
			moves[sim.situation.position] = moves.get(sim.situation.position, 0) + 1
		for i in 2:
			if sim.role(i) == PositionLibrary.TOP:
				moves.top[i] += 1
		return
	if sim.fighters[0].is_down() or sim.fighters[1].is_down():
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
		"corner_red": _style(sim.corners[0]), "corner_blue": _style(sim.corners[1]), "calls_red": 0, "calls_blue": 0,
		"rules_red": "", "rules_blue": "", "fired_red": 0, "fired_blue": 0,
		"winner": "draw" if winner < 0 else SIDES[winner],
		"winner_id": "" if winner < 0 else sim.fighters[winner].id,
		"result": end.data.result, "method": method_of(end.data.result),
		"end_round": end.round_number, "end_second": sim.clock.tick_in_round / FightClock.TICKS_PER_SECOND,
		"fight_seconds": _seconds(sim.now),
		"round_cards": 0, "even_cards": 0, "exchanges": 0, "clamped": 0, "events": sim.events.size(),
		"leg_lock_finish": 1 if end.data.result == FightSim.RESULT_SUB and sim.actions.has(String(end.data.get("why", ""))) \
			and ActionLibrary.is_leg_lock(sim.actions.get_action(end.data.why)) else 0,
	}
	var standing: int = moves.get("standing", 0)
	row.chase = _share_of(moves.get("chase", 0), standing)
	var ticks: int = moves.get("ticks", 0)
	row.clinch = _share_of(moves.get("clinch", 0), ticks)
	row.ground = _share_of(moves.get("ground", 0), ticks)
	for id: String in GROUND_POSITIONS:
		row[id] = _share_of(moves.get(id, 0), ticks)
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
		row["shots_" + side] = f.takedowns_tried
		row["takedowns_" + side] = f.takedowns_landed
		row["subs_" + side] = f.subs_tried
		row["locked_" + side] = f.subs_locked
		row["leg_locks_" + side] = f.leg_locks_tried
		row["leg_locked_" + side] = f.leg_locks_locked
		row["throws_" + side] = f.throws_tried
		row["throws_landed_" + side] = f.throws_landed
		row["collar_ties_" + side] = f.collar_ties_tried
		row["collar_ties_won_" + side] = f.collar_ties_won
		row["clinch_knees_" + side] = f.clinch_knees_landed
		row["tied_knees_" + side] = f.tied_knees_landed
		row["advances_" + side] = f.advances
		row["escapes_" + side] = f.escapes
		row["feints_" + side] = f.feints_tried
		row["feints_bit_" + side] = f.feints_bit
		row["blind_" + side] = f.blind_shots
		row["blind_landed_" + side] = f.blind_landed
		row["top_" + side] = _share_of(moves.get("top", [0, 0])[i], ticks)
		row["circling_" + side] = _seconds(sim.circling_ticks[i])
		row["cutting_" + side] = _seconds(sim.cutting_ticks[i])
		for key: String in ["fence", "pinned", "centre"]:
			row[key + "_" + side] = _share_of(moves.get(key, [0, 0])[i], standing)
	for e in sim.events:
		match e.type:
			FightEvent.ROCKED:
				row["rocked_" + SIDES[e.actor]] += 1
			FightEvent.CALL_HEARD:
				row["calls_" + SIDES[e.actor]] += 1
			FightEvent.RULE_ANSWERED:
				var side: String = SIDES[e.actor]
				if e.data.outcome == DrilledRules.SET:
					row["rules_" + side] += ("+" if row["rules_" + side] != "" else "") + "%s@%d" % [e.data.rule_id, e.data.drilled]
				elif e.data.outcome == DrilledRules.FIRED:
					row["fired_" + side] += 1
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


## "ko", "tko", "submission", "decision" or "draw" from a fight_ended result.
static func method_of(result: String) -> String:
	match result:
		FightSim.RESULT_KO:
			return METHOD_KO
		FightSim.RESULT_TKO:
			return METHOD_TKO
		FightSim.RESULT_SUB:
			return METHOD_SUB
		Judging.DRAW:
			return METHOD_DRAW
	return METHOD_DECISION


static func _style(corner: Corner) -> String:
	return corner.style if corner != null else Corner.NONE


## Ticks as fight seconds, to a tenth.
static func _seconds(ticks: int) -> float:
	return snappedf(float(ticks) / FightClock.TICKS_PER_SECOND, 0.1)


## Ticks as a share of standing (or all) ticks, rounded for the CSV.
static func _share_of(ticks: int, standing: int) -> float:
	return snappedf(float(ticks) / standing, 0.001) if standing > 0 else 0.0
