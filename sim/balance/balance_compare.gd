class_name BalanceCompare
extends RefCounted
## Two balance harness runs side by side, fight by fight (D250, docs/01 §2.4): the
## CSV from before a change and the CSV from after it, matched by pairing and seed,
## so each seed is one paired difference and the 95% ranges show whether the change
## did something or the dice did. tools/balance_compare.gd reads the files and prints this.
##
## Both runs should use the same seeds (the same --seed and --fights). Fights that
## only one run has are counted and left out.

## The shares of fights every comparison shows (share_score).
const SHARES: Array[String] = ["red wins", "blue wins", "draws", "finishes"]


## The rows of a balance.csv (BalanceReport.csv): one Dictionary per line, keyed by the
## header, every value a String. Quoted cells may hold commas and doubled quotes.
static func parse_csv(text: String) -> Array[Dictionary]:
	var lines: Array[PackedStringArray] = []
	var cells: PackedStringArray = []
	var cell: String = ""
	var quoted: bool = false
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		if quoted:
			if c == "\"" and i + 1 < text.length() and text[i + 1] == "\"":
				cell += "\""
				i += 1
			elif c == "\"":
				quoted = false
			else:
				cell += c
		elif c == "\"":
			quoted = true
		elif c == ",":
			cells.append(cell)
			cell = ""
		elif c == "\n":
			cells.append(cell)
			lines.append(cells)
			cells = PackedStringArray()
			cell = ""
		elif c != "\r":
			cell += c
		i += 1
	if cell != "" or not cells.is_empty():
		cells.append(cell)
		lines.append(cells)
	var rows: Array[Dictionary] = []
	if lines.is_empty():
		return rows
	var header: PackedStringArray = lines[0]
	for n in range(1, lines.size()):
		var row: Dictionary = {}
		for k in mini(header.size(), lines[n].size()):
			row[header[k]] = lines[n][k]
		rows.append(row)
	return rows


## The comparison as readable text: per pairing (BalanceReport.pair_key, in the after run's
## order), how many fights matched and how many played out differently, then each share in
## SHARES and each extra column's mean before → after with the paired change and its 95% range.
static func report(before: Array[Dictionary], after: Array[Dictionary], columns: PackedStringArray = []) -> String:
	var out: PackedStringArray = []
	var old: Dictionary = {}  # pair key → seed → row
	for row in before:
		var by_seed: Dictionary = old.get_or_add(BalanceReport.pair_key(row), {})
		by_seed[str(row.seed)] = row
	var groups: Array[String] = []
	var new: Dictionary = {}
	for row in after:
		var key: String = BalanceReport.pair_key(row)
		if key not in groups:
			groups.append(key)
		var by_seed: Dictionary = new.get_or_add(key, {})
		by_seed[str(row.seed)] = row
	for key in groups:
		var then: Dictionary = old.get(key, {})
		var matched: Array[Array] = []
		for fight_seed: String in new[key]:
			if then.has(fight_seed):
				matched.append([then[fight_seed], new[key][fight_seed]])
		out.append("%s: %d fights matched by seed (%d only before, %d only after)" % [key, matched.size(),
			then.size() - matched.size(), new[key].size() - matched.size()])
		if matched.is_empty():
			out.append("")
			continue
		var differ: int = matched.filter(func(m: Array) -> bool: return played_differently(m[0], m[1])).size()
		out.append("  %-24s %d of %d" % ["played out differently", differ, matched.size()])
		for label in SHARES:
			out.append(_line(label, matched, func(row: Dictionary) -> float: return share_score(row, label), true))
		for column in columns:
			if not after[0].has(column) or not before[0].has(column):
				out.append("  %-24s not in both files" % column)
				continue
			out.append(_line(column, matched, func(row: Dictionary) -> float: return float(row[column]), false))
		out.append("")
	for key: String in old:
		if key not in groups:
			out.append("%s: only in the before run (%d fights)" % [key, old[key].size()])
	return "\n".join(out) + "\n"


## 1 when the fight counts toward this share ("red wins", "blue wins", "draws", "finishes"), else 0.
static func share_score(row: Dictionary, label: String) -> float:
	match label:
		"red wins":
			return 1.0 if row.winner == "red" else 0.0
		"blue wins":
			return 1.0 if row.winner == "blue" else 0.0
		"draws":
			return 1.0 if row.winner == "draw" else 0.0
		"finishes":
			return 1.0 if row.method in [FightSummary.METHOD_KO, FightSummary.METHOD_TKO, FightSummary.METHOD_SUB] else 0.0
	return 0.0


## True when the same seed gave a different fight: another winner, result, ending or number of events.
static func played_differently(a: Dictionary, b: Dictionary) -> bool:
	for column: String in ["winner", "result", "end_round", "end_second", "events"]:
		if str(a.get(column, "")) != str(b.get(column, "")):
			return true
	return false


static func _line(label: String, matched: Array[Array], score: Callable, as_share: bool) -> String:
	var was: Array = []
	var now: Array = []
	var diffs: Array = []
	for m in matched:
		was.append(score.call(m[0]))
		now.append(score.call(m[1]))
		diffs.append(now[-1] - was[-1])
	var change: Dictionary = BalanceStats.paired(diffs)
	if as_share:
		return "  %-24s %.1f%% → %.1f%%   change %s" % [label, BalanceStats.mean(was) * 100.0, BalanceStats.mean(now) * 100.0, BalanceStats.change_text(change)]
	var spread: String = "range unknown" if BalanceStats.unknown(change) else "%+.2f to %+.2f" % [change.low, change.high]
	return "  %-24s %.2f → %.2f   change %+.2f (%s)" % [label, BalanceStats.mean(was), BalanceStats.mean(now), change.mean, spread]
