class_name History
extends RefCounted
## The world's history (docs/03 §12.8, D358): the world is played for Career.HISTORY_YEARS years before his career
## starts (Career.play_history), and what it leaves is kept here. Kyle (2026-11-02) picked "A short wait with a progress
## line", "Records, reigns and a History page", "World champions and long reigns" as legends, former champions marked
## "everywhere by name", and his hometown's own legend "named on the hub".
##
## Every reign that ends is kept for good in World.reigns, by the man's id: [[belt key, won, lost, defences, how it
## ended]] (the belts' own `past` keeps only their last few). A legend is anyone who's held the world organisation's
## belt, or defended any belt LEGEND_DEFENCES times in one reign (a reign still going counts), retired or not. A former
## champion is a man who's held a belt and doesn't now; his best one is the biggest promotion's, then the most defences.
##
## Pure (D100).

## A reign with this many defences makes a legend (the world organisation's belt makes one with none).
const LEGEND_DEFENCES: int = 3
## How many legends the History page lists, best first.
const LEGENDS_SHOWN: int = 20


## A reign has ended: kept for good.
static func note_reign(w: World, k: String, id: String, won: int, lost: int, defences: int, how: String) -> void:
	if id == "":
		return
	(w.reigns.get_or_add(id, []) as Array).append([k, won, lost, defences, how])


## His reigns, ended ones and the one he's on (with `lost` -1 and how "").
static func reigns_of(w: World, id: String) -> Array:
	var out: Array = (w.reigns.get(id, []) as Array).duplicate()
	var now: String = Titles.held_by(w, id)
	if now != "":
		var b: Dictionary = Titles.belt(w, now)
		out.append([now, int(b.won), -1, int(b.defences), ""])
	return out


## How big a belt is: the promotion's rank (0 the world organisation's, the smallest first).
static func belt_rank(w: World, k: String) -> int:
	return int(Promotions.by_id(w, k.get_slice(":", 0)).get("rank", Promotions.REGIONAL))


## His best reign ([] for none): the biggest promotion's, then the most defences, then the longest.
static func best_reign(w: World, id: String) -> Array:
	var best: Array = []
	for r: Array in reigns_of(w, id):
		if best.is_empty() or _better(w, r, best):
			best = r
	return best


static func _better(w: World, a: Array, b: Array) -> bool:
	var ra: int = belt_rank(w, String(a[0]))
	var rb: int = belt_rank(w, String(b[0]))
	if ra != rb:
		return ra < rb
	if int(a[3]) != int(b[3]):
		return int(a[3]) > int(b[3])
	return _length(a) > _length(b)


static func _length(r: Array) -> int:
	return (int(r[2]) if int(r[2]) >= 0 else 1 << 20) - int(r[1])


## "former IML champion" for a man who's held a belt and doesn't now ("" otherwise; a champion's own tag is his belt).
static func former_tag(w: World, id: String) -> String:
	if id == "" or Titles.held_by(w, id) != "" or not w.reigns.has(id):
		return ""
	var best: Array = best_reign(w, id)
	if best.is_empty():
		return ""
	return "former %s champion" % String(Promotions.by_id(w, String(best[0]).get_slice(":", 0)).get("short", ""))


## Whether he's a legend (see the top).
static func is_legend(w: World, id: String) -> bool:
	for r: Array in reigns_of(w, id):
		if belt_rank(w, String(r[0])) == Promotions.MAJOR or int(r[3]) >= LEGEND_DEFENCES:
			return true
	return false


## The legends, best first: the most world organisation reigns' defences and reigns, then all defences, then wins.
static func legends(w: World) -> Array:
	var ids: Dictionary = {}
	for id: String in w.reigns:
		ids[id] = true
	for k: String in w.titles:
		var c: String = String(w.titles[k].get("champion", ""))
		if c != "":
			ids[c] = true
	var out: Array = []
	for id: String in ids:
		if is_legend(w, id):
			out.append(id)
	var scores: Dictionary = {}
	for id: String in out:
		scores[id] = legacy(w, id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return float(scores[a]) > float(scores[b]) if float(scores[a]) != float(scores[b]) else a < b)
	return out


## How much his reigns count for, to put the legends in order: a reign 10 a defence plus 10, times 3 in the world
## organisation and 1.5 in the international one; a win adds a little.
static func legacy(w: World, id: String) -> float:
	var score: float = 0.0
	for r: Array in reigns_of(w, id):
		var weight: float = [3.0, 1.5, 1.0][clampi(belt_rank(w, String(r[0])), 0, 2)]
		score += weight * (10.0 + 10.0 * float(r[3]))
	var m: Dictionary = w.man(id)
	if not m.is_empty():
		score += 0.1 * float(m.get("record", {}).get("win", 0))
	return score


## His hometown's own legend (D358): of the men who've held his home promotion's belts, one from his hometown if any
## is, else from his country, else anyone; the one whose reigns there count for most. "" when nobody has.
static func home_legend(w: World) -> String:
	var home: Dictionary = Promotions.home(w)
	if home.is_empty():
		return ""
	var pid: String = String(home.id)
	var best: String = ""
	var best_score: float = -1.0
	var country: String = w._names.country_name(w.country_id)
	for id: String in _belt_holders(w, pid):
		var m: Dictionary = w.man(id)
		if m.is_empty():
			continue
		var score: float = 0.0
		for r: Array in reigns_of(w, id):
			if String(r[0]).get_slice(":", 0) == pid:
				score += 10.0 + 10.0 * float(r[3])
		if String(m.get("hometown", "")) == w.hometown:
			score += 1000.0
		elif String(m.get("country", "")) == country:
			score += 500.0
		if score > best_score or (score == best_score and id < best):
			best = id
			best_score = score
	return best


## The men who've held a promotion's belts.
static func _belt_holders(w: World, pid: String) -> Array:
	var out: Dictionary = {}
	for id: String in w.reigns:
		for r: Array in w.reigns[id]:
			if String(r[0]).get_slice(":", 0) == pid:
				out[id] = true
	for k: String in w.titles:
		if k.get_slice(":", 0) == pid and String(w.titles[k].get("champion", "")) != "":
			out[String(w.titles[k].champion)] = true
	var ids: Array = out.keys()
	ids.sort()
	return ids


## A belt's champions, newest first: [[id, won, lost, defences, how]] (the one on now first, `lost` -1).
static func line_of(w: World, k: String) -> Array:
	var out: Array = []
	for id: String in w.reigns:
		for r: Array in w.reigns[id]:
			if String(r[0]) == k:
				out.append([id, int(r[1]), int(r[2]), int(r[3]), String(r[4])])
	var b: Dictionary = Titles.belt(w, k)
	if String(b.get("champion", "")) != "":
		out.append([String(b.champion), int(b.won), -1, int(b.defences), ""])
	out.sort_custom(func(a: Array, c: Array) -> bool: return int(a[1]) > int(c[1]) if int(a[1]) != int(c[1]) else String(a[0]) < String(c[0]))
	return out
