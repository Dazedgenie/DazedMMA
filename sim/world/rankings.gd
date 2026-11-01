class_name Rankings
extends RefCounted
## The rankings (docs/03 §12.5, D355): every promotion's own table for each division, updated each Saturday after the
## world's fights. Kyle (2026-11-01) picked all of them ranked ("All of them": the organisations' top TOP_ORGANISATION,
## each regional promotion's top TOP_REGIONAL), points from recent results ("Points from recent results"), men out of
## action sliding after SLIDE_WEEKS and off after OUT_WEEKS ("Slide after 6 months, out at 12"), ranked men matched near
## their rank (WorldWeeks.pair_gap, "Ranked men fight near their rank") and a Rankings page with the numbers by names
## everywhere ("Rankings page, numbers everywhere").
##
## A pro's points: each fight he has as a pro gets points when it happens (note()), kept with the fight in his `points`
## ([week, points, promotion rank, opponent's rank, w/l/d, method]):
## - a win WIN_POINTS, plus up to RANKED_BONUS for beating a ranked man (all of it for his table's #1, less down the
##   table), times FINISH_SHARE for a knockout or submission;
## - a draw DRAW_POINTS;
## - a loss LOSS_POINTS off, less for losing to a ranked man (LOSS_TO_RANKED_SHARE off for losing to his #1), more for
##   being finished (FINISH_SHARE).
## His score in a table is those points fading to nothing over FADE_WEEKS, with points won in a smaller promotion
## counting LOWER_SHARE (per rank of promotion) in a bigger one, and after SLIDE_WEEKS without a fight the lot shrinking
## SLIDE_PER_WEEK a week. A man ranks once he's had a pro fight in the last OUT_WEEKS; best score first.
##
## Each update notes the moves (World.ranking_moves): who went up and down and why ("beat #7 Tom Hill by knockout"),
## kept per table until its next moves. A new #1, and every move of the career's fighter, is news (a "ranked" result).
##
## The career's fighter is ranked too, in the promotion of his last pro fight (World.him, set by Career.finish_fight).
##
## Pure (D100): the same fights make the same tables.

## Each table's length.
const TOP_ORGANISATION: int = 15
const TOP_REGIONAL: int = 10
## Points for a fight (see the top).
const WIN_POINTS: float = 10.0
const RANKED_BONUS: float = 12.0
const DRAW_POINTS: float = 4.0
const LOSS_POINTS: float = 5.0
const LOSS_TO_RANKED_SHARE: float = 0.7
const FINISH_SHARE: float = 1.3
## Points fade to nothing over FADE_WEEKS (about 2 years).
const FADE_WEEKS: int = 104
## Points won in a promotion a rank smaller count this much in a bigger one (squared for two ranks).
const LOWER_SHARE: float = 0.4
## Out of action: after SLIDE_WEEKS (about 6 months) without a fight his score shrinks SLIDE_PER_WEEK a week; after
## OUT_WEEKS (a year) he's off.
const SLIDE_WEEKS: int = 26
const SLIDE_PER_WEEK: float = 0.02
const OUT_WEEKS: int = 52
## The rankings on day one (until D358's history): each table's men by level, the best given SEED_POINTS (the last
## SEED_FLOOR) today, as one win SEED_WEEKS ago.
const SEED_POINTS: float = 24.0
const SEED_FLOOR: float = 4.0
const SEED_WEEKS: Array[int] = [2, 20]


## The table key for a promotion and division: "org_0:lightweight".
static func key(promotion_id: String, division: String) -> String:
	return "%s:%s" % [promotion_id, division]


## How long this promotion's tables are.
static func size_for(p: Dictionary) -> int:
	return TOP_REGIONAL if int(p.get("rank", Promotions.REGIONAL)) == Promotions.REGIONAL else TOP_ORGANISATION


## A table: the ids, #1 first ([] when nobody's ranked).
static func table(w: World, promotion_id: String, division: String) -> Array:
	return w.rankings.get(key(promotion_id, division), [])


## His place in his promotion's table: 1 for #1, 0 unranked.
static func rank_of(w: World, id: String) -> int:
	if w.rank_cache.is_empty() and not w.rankings.is_empty():
		_cache(w)
	return int(w.rank_cache.get(id, [ "", 0 ])[1])


## "#4" (or "" unranked).
static func rank_text(w: World, id: String) -> String:
	var r: int = rank_of(w, id)
	return "#%d" % r if r > 0 else ""


## The points for one fight: his result `letter` (w, l or d), how it ended, the man's place in his table (0 unranked)
## and the table's length.
static func points_for(letter: String, method: String, opponent_rank: int, n: int) -> float:
	var quality: float = float(n + 1 - opponent_rank) / float(n) if opponent_rank > 0 else 0.0
	var finish: bool = method in ["ko", "submission"]
	match letter:
		"w":
			return (WIN_POINTS + RANKED_BONUS * quality) * (FINISH_SHARE if finish else 1.0)
		"d":
			return DRAW_POINTS
		"l":
			return -LOSS_POINTS * (1.0 - LOSS_TO_RANKED_SHARE * quality) * (FINISH_SHARE if finish else 1.0)
	return 0.0


## A pro fight onto his points (a man of the world, or the career's fighter as World.him): `letter` w, l or d, `method`
## ko, submission, decision or draw. Points older than FADE_WEEKS go.
static func note(w: World, m: Dictionary, opponent_id: String, letter: String, method: String, week: int) -> void:
	if not bool(m.get("pro", false)):
		return
	var p: Dictionary = Promotions.of(w, m)
	if p.is_empty():
		return
	var opponent_rank: int = rank_of(w, opponent_id)
	var pts: float = snappedf(points_for(letter, method, opponent_rank, size_for(p)), 0.1)
	var points: Array = m.get_or_add("points", [])
	points.append([week, pts, int(p.rank), opponent_rank, letter, method, opponent_id])
	while not points.is_empty() and int(points[0][0]) <= week - FADE_WEEKS:
		points.pop_front()


## His score in a table of a promotion of this rank this week (see the top). -INF when he can't be ranked.
static func score(m: Dictionary, table_rank: int, week: int) -> float:
	var points: Array = m.get("points", [])
	if points.is_empty():
		return -INF
	var last: int = int(points[-1][0])
	if week - last >= OUT_WEEKS:
		return -INF
	var total: float = 0.0
	for e: Array in points:
		var fade: float = 1.0 - float(week - int(e[0])) / float(FADE_WEEKS)
		if fade <= 0.0:
			continue
		var share: float = pow(LOWER_SHARE, maxi(0, int(e[2]) - table_rank))
		total += float(e[1]) * fade * share
	if week - last > SLIDE_WEEKS:
		total *= maxf(0.0, 1.0 - SLIDE_PER_WEEK * float(week - last - SLIDE_WEEKS))
	return total


## Day one's rankings (and a world saved before D355's): every table's signed pros by level, given seeded points (see
## SEED_POINTS), then the tables made.
static func seed(w: World, week: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value, "rankings"])
	for p: Dictionary in w.promotions:
		for division_id: String in Weight.ids():
			var men: Array = _men_of(w, String(p.id), division_id)
			men.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return w.average(a) > w.average(b) if w.average(a) != w.average(b) else String(a.id) < String(b.id))
			for i in men.size():
				var m: Dictionary = men[i]
				if not (m.get("points", []) as Array).is_empty():
					continue
				var pts: float = lerpf(SEED_POINTS, SEED_FLOOR, float(i) / maxf(1.0, float(men.size() - 1)))
				var ago: int = rng.randi_range(SEED_WEEKS[0], SEED_WEEKS[1])
				pts /= 1.0 - float(ago) / float(FADE_WEEKS)  # So his score today is the seeded one, whenever the win was.
				m.points = [[week - ago, snappedf(pts, 0.01), int(p.rank), 0, "w", "seed", ""]]
	w.rankings = {}
	w.rank_cache = {}
	update(w, week, false)


## This Saturday's tables, and their moves since the last ones (World.ranking_moves). A promotion's tables are
## worked out afresh on its card weeks (its men's fights, and the points fading); between cards only the men who've
## gone come off, the men below move up into their places and the next best fills the end. `log` adds the news
## ("ranked" results): a new #1 of a table and the career's fighter's moves.
static func update(w: World, week: int, log: bool = true) -> void:
	var buckets: Dictionary = {}
	for m: Dictionary in w.men.values():
		if World.active(m) and bool(m.get("pro", false)) and String(m.get("promotion", "")) != "":
			buckets.get_or_add(key(String(m.promotion), String(m.get("division", ""))), []).append(m)
	if String(w.him.get("promotion", "")) != "":
		buckets.get_or_add(key(String(w.him.promotion), String(w.him.get("division", ""))), []).append(w.him)
	var tables: Dictionary = {}
	for p: Dictionary in w.promotions:
		var n: int = size_for(p)
		var fresh: bool = Promotions.has_card(p, week) or not log
		for division_id: String in Weight.ids():
			var k: String = key(String(p.id), division_id)
			var scored: Array = []
			var scores: Dictionary = {}
			for m: Dictionary in buckets.get(k, []):
				var s: float = score(m, int(p.rank), week)
				if s > -INF:
					scored.append([s, int(m.points[-1][0]), String(m.get("id", Career.FIGHTER_ID))])
					scores[String(m.get("id", Career.FIGHTER_ID))] = true
			scored.sort_custom(func(a: Array, b: Array) -> bool:
				if float(a[0]) != float(b[0]):
					return float(a[0]) > float(b[0])
				return int(a[1]) > int(b[1]) if int(a[1]) != int(b[1]) else String(a[2]) < String(b[2]))
			var before: Array = table(w, String(p.id), division_id)
			var ids: Array = []
			if not fresh:
				ids = before.filter(func(id: Variant) -> bool: return scores.has(String(id)))
			for x: Array in scored:
				if ids.size() >= n:
					break
				if not ids.has(String(x[2])):
					ids.append(String(x[2]))
			if not ids.is_empty():
				tables[k] = ids
			var moves: Array = _moves(w, before, ids, week, fresh, week - int(p.every))
			if moves.is_empty():
				continue
			var note: Dictionary = w.ranking_moves.get(k, {})
			if fresh or note.is_empty():
				w.ranking_moves[k] = { "week": week, "moves": moves }
			else:
				(note.moves as Array).append_array(moves)
			if log:
				for mv: Dictionary in moves:
					if (int(mv.to) == 1 and int(mv.from) != 1) or String(mv.id) == Career.FIGHTER_ID:
						w.results.append({ "kind": "ranked", "week": week, "id": String(mv.id), "division": division_id,
							"promotion": String(p.id), "from": int(mv.from), "to": int(mv.to), "why": String(mv.why) })
	w.rankings = tables
	_cache(w)


## The moves from one table to the next: each { id, from, to, why } (0 for not ranked), biggest climbs first, then the
## falls and the men who've gone. Between cards (not `fresh`) only the men coming on and going off count.
static func _moves(w: World, before: Array, after: Array, week: int, fresh: bool = true, since: int = -1) -> Array:
	var out: Array = []
	for i in after.size():
		var id: String = String(after[i])
		var from: int = before.find(id) + 1
		if from != i + 1 and (fresh or from == 0):
			out.append({ "id": id, "from": from, "to": i + 1, "why": why(w, id, week, from, i + 1, since) })
	for i in before.size():
		var id: String = String(before[i])
		if not after.has(id):
			out.append({ "id": id, "from": i + 1, "to": 0, "why": why(w, id, week, i + 1, 0, since) })
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var x: int = _climb(a)
		var y: int = _climb(b)
		return x > y if x != y else String(a.id) < String(b.id))
	return out


static func _climb(mv: Dictionary) -> int:
	if int(mv.to) == 0:
		return -100 - int(mv.from)
	return (16 if int(mv.from) == 0 else int(mv.from)) - int(mv.to)


## Why he moved, in a few words: his fight since `since` (the promotion's last card before this one; this week when
## not given: "beat #7 Tom Hill by knockout"), or why he's gone, or that he's been out of action, or the other men's
## results.
static func why(w: World, id: String, week: int, from: int, to: int, since: int = -1) -> String:
	var m: Dictionary = w.him if id == Career.FIGHTER_ID else w.man(id)
	if m.is_empty():
		return "gone"
	if id != Career.FIGHTER_ID and not World.active(m):
		return "retired"
	var points: Array = m.get("points", [])
	var last: Array = points[-1] if not points.is_empty() else []
	if to == 0 and id != Career.FIGHTER_ID:
		var now: Dictionary = Promotions.of(w, m)
		if int(m.get("moved", -1)) == week and not now.is_empty():
			var was: String = ""
			for k: String in w.rankings:
				if (w.rankings[k] as Array).has(id):
					was = k.get_slice(":", 0)
			var was_rank: int = int(Promotions.by_id(w, was).get("rank", Promotions.REGIONAL))
			return ("called up to the %s" if int(now.rank) < was_rank else "let go to the %s") % String(now.name)
	if not last.is_empty() and int(last[0]) > (since if since >= 0 else week - 1) and String(last[5]) != "seed":
		return fight_words(w, last)
	if not last.is_empty() and week - int(last[0]) >= OUT_WEEKS:
		return "a year without a fight"
	if not last.is_empty() and week - int(last[0]) > SLIDE_WEEKS:
		return "out of action %d months" % int(float(week - int(last[0])) / 4.35)
	return "others' results" if to > 0 else "pushed out on others' results"


## A points entry's fight as words: "beat #7 Tom Hill by knockout", "lost to Joe Bell on the cards".
static func fight_words(w: World, e: Array) -> String:
	var opponent_id: String = String(e[6]) if e.size() > 6 else ""
	var who: String = name_of(w, opponent_id)
	if int(e[3]) > 0:
		who = "#%d %s" % [int(e[3]), who]
	var how: String = { "ko": " by knockout", "submission": " by submission", "decision": " on the cards" }.get(String(e[5]), "")
	match String(e[4]):
		"w":
			return "beat %s%s" % [who, how]
		"l":
			return "lost to %s%s" % [who, how]
	return "drew with %s" % who


## A man's name, the career's fighter's included ("" when he's gone).
static func name_of(w: World, id: String) -> String:
	if id == Career.FIGHTER_ID:
		return String(w.him.get("name", "him"))
	return String(w.man(id).get("name", ""))


## The career's fighter's pro fight on a promotion's card (Career.finish_fight): he's in that promotion's tables now,
## in his division, and the fight goes onto his points.
static func his_fight(w: World, name: String, promotion_id: String, division: String, opponent_id: String, result: String,
		method: String, week: int) -> void:
	if Promotions.by_id(w, promotion_id).is_empty() or not result in ["win", "loss", "draw"]:
		return
	w.him.name = name
	w.him.pro = true
	w.him.id = Career.FIGHTER_ID
	w.him.promotion = promotion_id
	w.him.division = division
	note(w, w.him, opponent_id, result.substr(0, 1), WorldWeeks._method(method), week)


static func _men_of(w: World, promotion_id: String, division: String) -> Array:
	var out: Array = []
	for m: Dictionary in w.men.values():
		if World.active(m) and bool(m.get("pro", false)) and String(m.get("promotion", "")) == promotion_id \
				and String(m.get("division", "")) == division:
			out.append(m)
	return out


static func _cache(w: World) -> void:
	w.rank_cache = {}
	for k: String in w.rankings:
		var ids: Array = w.rankings[k]
		for i in ids.size():
			w.rank_cache[String(ids[i])] = [k, i + 1]
