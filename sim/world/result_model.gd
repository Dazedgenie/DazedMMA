class_name ResultModel
extends RefCounted
## The quick result model for the world's other fights (docs/03 §12.3, D350, D353): the fight engine takes about 0.6 s a
## fight, too slow for 600 men fighting 3 times a year, so their fights are rolled from a table the engine made
## (data/world/matchups.json, docs/09 matchups@1, rebuilt by tools/matchups.gd). His own fights stay on the engine.
##
## Who wins: the chance a beats b is the logistic of the styles' edge at an even level (`edges`, each pair of styles)
## plus `per_point` for every point of average stat a is better, plus the nudges the world adds (age, form, rust).
## A draw is `draw` of fights. How it ends: the winner's style's share of wins by each method and the loser's style's
## share of losses by each, averaged. Which round: the method's share in each round (a decision goes the distance).
##
## Pure: the table and the dice it's given.

const PATH := "res://data/world/matchups.json"
const METHODS: Array[String] = ["ko", "submission", "decision"]
## In fit(): how hard each pair's edge is pulled toward even (a few fights a pair can't say much), and how many fights'
## worth of the overall method shares each style's own are mixed with.
const EDGE_PRIOR: float = 0.5
const METHOD_PRIOR: float = 10.0
## In check(): the 95% range (Wilson) the model's share must sit inside.
const Z95: float = 1.96

static var _shared: Dictionary = {}


## The shipped table, loaded once.
static func table() -> Dictionary:
	if _shared.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_shared = parsed
	return _shared


## The styles' edge for a against b at an even level (logit): + favours a.
static func edge(a: String, b: String, t: Dictionary = {}) -> float:
	var tab: Dictionary = t if not t.is_empty() else table()
	if a == b:
		return 0.0
	var edges: Dictionary = tab.get("edges", {})
	if edges.has("%s:%s" % [a, b]):
		return float(edges["%s:%s" % [a, b]])
	if edges.has("%s:%s" % [b, a]):
		return -float(edges["%s:%s" % [b, a]])
	return 0.0


## The chance a (style, average stat) beats b, a draw left aside; `nudge` is added to the logit (+ helps a).
static func win_chance(a_style: String, a_avg: float, b_style: String, b_avg: float, nudge: float = 0.0, t: Dictionary = {}) -> float:
	var tab: Dictionary = t if not t.is_empty() else table()
	var x: float = edge(a_style, b_style, tab) + float(tab.get("per_point", 0.15)) * (a_avg - b_avg) + nudge
	return 1.0 / (1.0 + exp(-x))


## A fight between a and b, rolled: { winner ("a", "b" or "draw"), method ("ko", "submission", "decision" or "draw"),
## round (1 to `rounds`) }.
static func decide(a_style: String, a_avg: float, b_style: String, b_avg: float, rng: RandomNumberGenerator, rounds: int = 3,
		nudge: float = 0.0, t: Dictionary = {}) -> Dictionary:
	var tab: Dictionary = t if not t.is_empty() else table()
	if rng.randf() < float(tab.get("draw", 0.0)):
		return { "winner": "draw", "method": "draw", "round": rounds }
	var a_wins: bool = rng.randf() < win_chance(a_style, a_avg, b_style, b_avg, nudge, tab)
	var w: String = a_style if a_wins else b_style
	var l: String = b_style if a_wins else a_style
	var method: String = roll_method(w, l, rng, tab)
	return { "winner": "a" if a_wins else "b", "method": method, "round": roll_round(method, rng, rounds, tab) }


## How the winner's win ends, from his style's wins and the loser's style's losses.
static func roll_method(winner_style: String, loser_style: String, rng: RandomNumberGenerator, t: Dictionary = {}) -> String:
	var tab: Dictionary = t if not t.is_empty() else table()
	var wins: Dictionary = tab.get("wins", {}).get(winner_style, {})
	var losses: Dictionary = tab.get("losses", {}).get(loser_style, {})
	var roll: float = rng.randf()
	for m: String in METHODS:
		roll -= (float(wins.get(m, 1.0 / 3.0)) + float(losses.get(m, 1.0 / 3.0))) / 2.0
		if roll < 0.0:
			return m
	return "decision"


## The round a finish comes in (a decision: the last). A finish in a longer fight (a title fight's 5 rounds) spreads the
## table's last round's share over the extra rounds.
static func roll_round(method: String, rng: RandomNumberGenerator, rounds: int = 3, t: Dictionary = {}) -> int:
	if method == "decision" or method == "draw":
		return rounds
	var tab: Dictionary = t if not t.is_empty() else table()
	var shares: Array = tab.get("rounds", {}).get(method, [0.5, 0.3, 0.2])
	var roll: float = rng.randf()
	for i in shares.size():
		var share: float = float(shares[i])
		if i == shares.size() - 1 and rounds > shares.size():
			var r: int = shares.size() + int(roll / maxf(0.0001, share) * float(rounds - shares.size() + 1))
			return clampi(r, 1, rounds)
		roll -= share
		if roll < 0.0:
			return mini(i + 1, rounds)
	return mini(shares.size(), rounds)


## The table from the engine's fights (tools/matchups.gd): rows of { a, b, avg_a, avg_b, winner ("a", "b", "draw"),
## method, round }. Fits each pair's edge and the worth of a point (a logistic fit, each edge pulled toward even by
## EDGE_PRIOR), and counts the methods and rounds.
static func fit(rows: Array) -> Dictionary:
	var by_pair: Dictionary = {}
	var draws: int = 0
	for r: Dictionary in rows:
		if String(r.winner) == "draw":
			draws += 1
			continue
		by_pair.get_or_add("%s:%s" % [r.a, r.b], []).append(r)
	var edges: Dictionary = {}
	for key: String in by_pair:
		edges[key] = 0.0
	var k: float = 0.1
	for sweep in 40:
		for key: String in by_pair:
			edges[key] = _newton_edge(by_pair[key], float(edges[key]), k)
		k = _newton_slope(by_pair, edges, k)
	for key: String in edges:
		edges[key] = snappedf(float(edges[key]), 0.001)
	var overall: Dictionary = { "ko": 0.0, "submission": 0.0, "decision": 0.0 }
	var wins: Dictionary = {}
	var losses: Dictionary = {}
	var rounds: Dictionary = { "ko": [0.0, 0.0, 0.0], "submission": [0.0, 0.0, 0.0] }
	for r: Dictionary in rows:
		if String(r.winner) == "draw":
			continue
		var m: String = _method(String(r.method))
		var w: String = String(r.a) if String(r.winner) == "a" else String(r.b)
		var l: String = String(r.b) if String(r.winner) == "a" else String(r.a)
		overall[m] += 1.0
		var wm: Dictionary = wins.get_or_add(w, { "ko": 0.0, "submission": 0.0, "decision": 0.0 })
		wm[m] += 1.0
		var lm: Dictionary = losses.get_or_add(l, { "ko": 0.0, "submission": 0.0, "decision": 0.0 })
		lm[m] += 1.0
		if rounds.has(m):
			var at: int = clampi(int(r.round), 1, 3) - 1
			rounds[m][at] += 1.0
	var total: float = maxf(1.0, overall.ko + overall.submission + overall.decision)
	var base: Dictionary = {}
	for m: String in METHODS:
		base[m] = overall[m] / total
	for counts: Dictionary in [wins, losses]:
		for style: String in counts:
			var c: Dictionary = counts[style]
			var n: float = c.ko + c.submission + c.decision
			for m: String in METHODS:
				c[m] = snappedf((float(c[m]) + METHOD_PRIOR * float(base[m])) / (n + METHOD_PRIOR), 0.001)
	for m: String in rounds:
		var sum: float = maxf(1.0, rounds[m][0] + rounds[m][1] + rounds[m][2])
		rounds[m] = (rounds[m] as Array).map(func(x: float) -> float: return snappedf(x / sum, 0.001))
	return {
		"schema": "matchups@1", "id": "matchups", "per_point": snappedf(k, 0.0001), "draw": snappedf(float(draws) / maxf(1.0, rows.size()), 0.0001),
		"edges": edges, "wins": wins, "losses": losses, "rounds": rounds,
		"methods": { "ko": snappedf(float(base.ko), 0.001), "submission": snappedf(float(base.submission), 0.001), "decision": snappedf(float(base.decision), 0.001) },
	}


## How the model's a-win share sits against the engine's, pair by pair: { pairs, inside (pairs whose model share is
## inside the engine's 95% range), worst ([pair, engine share, model share]) }.
static func check(rows: Array, t: Dictionary) -> Dictionary:
	var by_pair: Dictionary = {}
	for r: Dictionary in rows:
		if String(r.winner) != "draw":
			by_pair.get_or_add("%s:%s" % [r.a, r.b], []).append(r)
	var inside: int = 0
	var worst: Array = []
	var worst_gap: float = -1.0
	for key: String in by_pair:
		var list: Array = by_pair[key]
		var won: float = 0.0
		var expected: float = 0.0
		for r: Dictionary in list:
			won += 1.0 if String(r.winner) == "a" else 0.0
			expected += win_chance(String(r.a), float(r.avg_a), String(r.b), float(r.avg_b), 0.0, t)
		var n: float = float(list.size())
		var range95: Array[float] = wilson(won, n)
		var model: float = expected / n
		if model >= range95[0] and model <= range95[1]:
			inside += 1
		var gap: float = absf(model - won / n)
		if gap > worst_gap:
			worst_gap = gap
			worst = [key, won / n, model]
	return { "pairs": by_pair.size(), "inside": inside, "worst": worst }


## The 95% range (Wilson score) for `won` of `n`.
static func wilson(won: float, n: float) -> Array[float]:
	if n <= 0.0:
		return [0.0, 1.0]
	var p: float = won / n
	var z2: float = Z95 * Z95
	var centre: float = (p + z2 / (2.0 * n)) / (1.0 + z2 / n)
	var half: float = Z95 * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n)) / (1.0 + z2 / n)
	return [maxf(0.0, centre - half), minf(1.0, centre + half)]


static func _method(m: String) -> String:
	if m == "ko" or m == "tko":
		return "ko"
	if m == "submission":
		return "submission"
	return "decision"


static func _newton_edge(list: Array, e: float, k: float) -> float:
	for step in 8:
		var g: float = -EDGE_PRIOR * e
		var h: float = -EDGE_PRIOR
		for r: Dictionary in list:
			var p: float = 1.0 / (1.0 + exp(-(e + k * (float(r.avg_a) - float(r.avg_b)))))
			g += (1.0 if String(r.winner) == "a" else 0.0) - p
			h -= p * (1.0 - p)
		e -= g / h
	return e


static func _newton_slope(by_pair: Dictionary, edges: Dictionary, k: float) -> float:
	for step in 8:
		var g: float = 0.0
		var h: float = -0.0001
		for key: String in by_pair:
			for r: Dictionary in by_pair[key]:
				var d: float = float(r.avg_a) - float(r.avg_b)
				var p: float = 1.0 / (1.0 + exp(-(float(edges[key]) + k * d)))
				g += ((1.0 if String(r.winner) == "a" else 0.0) - p) * d
				h -= p * (1.0 - p) * d * d
		k -= g / h
	return k
