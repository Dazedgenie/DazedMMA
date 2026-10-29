class_name Judging
extends RefCounted
## Simple 10-point must scoring with three judges (docs/01-fight-engine.md §11,
## issue #13). A round goes to whoever did more effective striking: damage landed
## (head counts most), plus big moments (rocking or dropping the opponent). When
## that's even, the judges look at aggression, then cage control, and only call it
## 10-10 when nothing separates the fighters (D97).
## Each judge sees the round slightly differently, so close fights can be split.
## Grappling counts in the same points (#15): a takedown (ending up on top) and every
## second held in a position that scores control (full guard top, docs/01 §21).
## Judge personalities come with D20.

const JUDGES: int = 3
## Points per point of damage landed on each target.
const TARGET_WEIGHTS := { "head": 1.0, "body": 0.8, "legs": 0.6 }
const ROCKED_POINTS: float = 8.0
const KNOCKDOWN_POINTS: float = 20.0
## Grappling (#15): a takedown, and per second × the position's control score for the role
## (full guard: top 1.0, bottom 0.2, data/positions).
const TAKEDOWN_POINTS: float = 6.0
const CONTROL_POINTS_PER_S: float = 0.15
## Getting to a better position on top (D130): this much per point of control score gained, so
## passing full guard (1.0) to side control (1.5) is 3, like half a takedown (0 to 1.0 control).
const ADVANCE_POINTS_PER_CONTROL: float = 6.0
## Locking in a submission (D126), like a near takedown; the hold then scores control as any position.
const SUB_LOCK_POINTS: float = 4.0
## How differently judges see the same round: each fighter's points ×(1 ± up to 15%).
const JUDGE_NOISE: float = 0.15
## Effective striking this close (within 5%) is even: aggression decides, then cage control.
const EVEN_WITHIN: float = 0.05
## Aggression: attacks thrown, plus this much per metre walked toward the opponent.
const AGGRESSION_PER_METRE: float = 1.0
## 10-8: two more knockdowns, or out-landed over 4 to 1 in a busy round (D110) with real
## damage done: the winner rocked or dropped the loser at least once (impact, D120).
const DOMINANT_KNOCKDOWNS: int = 2
const DOMINANT_SHARE: float = 0.25
const DOMINANT_MIN_POINTS: float = 60.0

const UNANIMOUS := "unanimous decision"
const SPLIT := "split decision"
const MAJORITY := "majority decision"
const DRAW := "draw"


## One judge's card for one round, e.g. [10, 9]. `tie_breaks` are what the judge
## looks at, in order, when effective striking is even: [[aggression red, blue],
## [cage control red, blue]]. `impact` is each fighter's rocks and knockdowns scored this
## round (FightSim.round_impact); without it, out-landing alone can make a 10-8.
static func round_card(points: Array[float], knockdowns: Array[int], tie_breaks: Array = [], impact: Array = []) -> Array[int]:
	var best: float = maxf(points[0], points[1])
	var w: int = -1
	if best > 0.0 and absf(points[0] - points[1]) > EVEN_WITHIN * best:
		w = 0 if points[0] > points[1] else 1
	else:
		for pair: Array in tie_breaks:
			if pair[0] != pair[1]:
				w = 0 if pair[0] > pair[1] else 1
				break
	if w < 0:
		return [10, 10]
	var l: int = 1 - w
	var dominant: bool = knockdowns[w] - knockdowns[l] >= DOMINANT_KNOCKDOWNS \
		or (points[w] >= DOMINANT_MIN_POINTS and points[l] < DOMINANT_SHARE * points[w] and (impact.is_empty() or int(impact[w]) > 0))
	var card: Array[int] = [0, 0]
	card[w] = 10
	card[l] = 8 if dominant else 9
	return card


## The verdict from each judge's totals ([[29, 28], [28, 29], [29, 28]]):
## {result, winner (fighter index, or -1 for a draw)}.
static func decision(totals: Array) -> Dictionary:
	var wins: Array[int] = [0, 0]
	for t: Array in totals:
		if t[0] > t[1]:
			wins[0] += 1
		elif t[1] > t[0]:
			wins[1] += 1
	var draws: int = totals.size() - wins[0] - wins[1]
	for w in 2:
		var l: int = 1 - w
		if wins[w] == totals.size():
			return { "result": UNANIMOUS, "winner": w }
		if wins[w] >= 2 and wins[l] == 1:
			return { "result": SPLIT, "winner": w }
		if wins[w] >= 2 and draws >= 1:
			return { "result": MAJORITY, "winner": w }
	return { "result": DRAW, "winner": -1 }


# --- Whole-fight judging (PRIDE rules, D141, docs/01 §33) ---------------------------

## What the judges look at, in order, for a whole-fight verdict: the effort to finish (damage
## landed, rocks, knockdowns, slams and submissions locked in), then control (takedowns,
## better positions, time on top and pinning him on the fence), then aggression.
const FINISH := "finish"
const CONTROL := "control"
const AGGRESSION := "aggression"
const WHOLE_FIGHT_ORDER: Array[String] = [FINISH, CONTROL, AGGRESSION]
## A judge only looks past the effort to finish when it's this close (within 10%), and past
## control when that's this close too. Aggression decides anything closer.
const WHOLE_FIGHT_EVEN_WITHIN := { "finish": 0.10, "control": 0.10, "aggression": 0.0 }
## Pinning him on the fence counts toward control at this much a second (like full guard top).
const FENCE_CONTROL_PER_S: float = CONTROL_POINTS_PER_S


## Who one judge gives the whole fight to, and why: {winner (-1 = nothing between them),
## on (FINISH, CONTROL or AGGRESSION; "" for nothing)}. `seen` is that judge's view of the
## fight: {finish: [red, blue], control: [...], aggression: [...]}.
static func whole_fight_pick(seen: Dictionary) -> Dictionary:
	for what in WHOLE_FIGHT_ORDER:
		var pair: Array = seen[what]
		var best: float = maxf(float(pair[0]), float(pair[1]))
		if best > 0.0 and absf(float(pair[0]) - float(pair[1])) > float(WHOLE_FIGHT_EVEN_WITHIN[what]) * best:
			return { "winner": 0 if pair[0] > pair[1] else 1, "on": what }
	return { "winner": -1, "on": "" }


## The verdict from each judge's pick ([0, 0, 1]): {result, winner}, as decision() words it.
## A judge who sees nothing between them counts as a draw on that card.
static func whole_fight_decision(picks: Array) -> Dictionary:
	var totals: Array = []
	for w: int in picks:
		totals.append([1 if w == 0 else 0, 1 if w == 1 else 0])
	return decision(totals)
