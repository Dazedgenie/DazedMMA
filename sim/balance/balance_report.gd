class_name BalanceReport
extends RefCounted
## The balance harness report (#18, docs/04 §7, D95): FightSummary rows in, a
## CSV and a readable summary out, with each balance target from the decisions
## marked as met or missed. Pure text; tools/balance.gd runs the fights and
## writes the files.

## D97: draws under 2%, and 10-10 rounds very rare (read here as under 2% of judges' round cards).
const DRAWS_UNDER: float = 0.02
const EVEN_CARDS_UNDER: float = 0.02
## docs/12 §4: the showcase pair should be within 60/40 once the AI (#14) lands.
const SHOWCASE: Array[String] = ["kicker", "boxer"]
const SHOWCASE_WITHIN: float = 0.6
## D96: someone who pushed or had the pace pushed on them ends at ~30–50% of the tank.
const TIRED_BELOW: float = 0.5

const MET := "MET"
const MISSED := "MISSED"
const INFO := "INFO"

var rows: Array[Dictionary] = []


func add(row: Dictionary) -> void:
	rows.append(row)


## "red:blue" for each pairing, in the order they were first added.
func pairs() -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		var key: String = pair_key(row)
		if key not in out:
			out.append(key)
	return out


static func pair_key(row: Dictionary) -> String:
	return "%s:%s" % [row.red, row.blue]


func rows_for(pair: String) -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool: return pair_key(row) == pair)


# --- Numbers ------------------------------------------------------------------

## Share of these fights where `test` is true for the row.
static func share(of_rows: Array[Dictionary], test: Callable) -> float:
	if of_rows.is_empty():
		return 0.0
	return float(of_rows.filter(test).size()) / of_rows.size()


static func win_share(of_rows: Array[Dictionary], side: String) -> float:
	return share(of_rows, func(row: Dictionary) -> bool: return row.winner == side)


static func method_share(of_rows: Array[Dictionary], method: String) -> float:
	return share(of_rows, func(row: Dictionary) -> bool: return row.method == method)


## KOs and TKOs: fights that ended inside the distance.
static func finish_share(of_rows: Array[Dictionary]) -> float:
	return method_share(of_rows, FightSummary.METHOD_KO) + method_share(of_rows, FightSummary.METHOD_TKO)


static func even_card_share(of_rows: Array[Dictionary]) -> float:
	return _ratio(of_rows, "even_cards", "round_cards")


static func clamped_share(of_rows: Array[Dictionary]) -> float:
	return _ratio(of_rows, "clamped", "exchanges")


static func average(of_rows: Array[Dictionary], key: String) -> float:
	if of_rows.is_empty():
		return 0.0
	var total: float = 0.0
	for row in of_rows:
		total += float(row[key])
	return total / of_rows.size()


## Share of fights where at least one fighter dipped under TIRED_BELOW of the tank.
static func tired_share(of_rows: Array[Dictionary]) -> float:
	return share(of_rows, func(row: Dictionary) -> bool:
		return row.stamina_low_red < TIRED_BELOW or row.stamina_low_blue < TIRED_BELOW)


static func _ratio(of_rows: Array[Dictionary], part: String, whole: String) -> float:
	var parts: float = 0.0
	var wholes: float = 0.0
	for row in of_rows:
		parts += float(row[part])
		wholes += float(row[whole])
	return parts / wholes if wholes > 0.0 else 0.0


# --- Targets ------------------------------------------------------------------

## Each balance target: {name, source, value (text), status MET / MISSED / INFO}.
## INFO lines have no pass mark yet but are worth watching.
func checks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if rows.is_empty():
		return out
	var draws: float = method_share(rows, FightSummary.METHOD_DRAW)
	out.append(_check("Draws under 2%", "D97", _pct(draws), draws < DRAWS_UNDER))
	var even: float = even_card_share(rows)
	out.append(_check("10-10 rounds very rare (under 2% of judges' cards)", "D97", _pct(even), even < EVEN_CARDS_UNDER))
	var showcase: Array[Dictionary] = rows.filter(_is_showcase)
	if not showcase.is_empty():
		var best: float = maxf(win_share(showcase, "red"), win_share(showcase, "blue"))
		out.append(_check("Kicker vs Boxer within 60/40, the exit test for the AI", "#14, docs/12 §4",
			"favourite wins %s" % _pct(best), best <= SHOWCASE_WITHIN))
	out.append(_info("Fights where someone got tired (under 50% of the tank)", "D96", _pct(tired_share(rows))))
	out.append(_info("Fights finished inside the distance", "docs/12 §4", _pct(finish_share(rows))))
	out.append(_info("Exchanges that hit the 5–95% odds clamp", "docs/12 §4", _pct(clamped_share(rows))))
	return out


static func _is_showcase(row: Dictionary) -> bool:
	return [row.red, row.blue] == SHOWCASE or [row.blue, row.red] == SHOWCASE


static func _check(check_name: String, source: String, value: String, ok: bool) -> Dictionary:
	return { "name": check_name, "source": source, "value": value, "status": MET if ok else MISSED }


static func _info(check_name: String, source: String, value: String) -> Dictionary:
	return { "name": check_name, "source": source, "value": value, "status": INFO }


# --- Output -------------------------------------------------------------------

## One line per fight, columns in FightSummary.COLUMNS order.
func csv() -> String:
	var lines: PackedStringArray = [",".join(FightSummary.COLUMNS)]
	for row in rows:
		var cells: PackedStringArray = []
		for column: String in FightSummary.COLUMNS:
			cells.append(_csv_cell(row.get(column, "")))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


static func _csv_cell(value: Variant) -> String:
	var text: String = str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


## The readable report: one block per pairing, then the targets.
## `names` maps fighter id → display name (ids are used when missing).
func summary(names: Dictionary = {}) -> String:
	var out: PackedStringArray = []
	for pair in pairs():
		out.append_array(_pair_lines(rows_for(pair), names))
		out.append("")
	out.append("Targets (all %d fights)" % rows.size())
	for c in checks():
		out.append("  %-7s %s: %s  [%s]" % [c.status, c.name, c.value, c.source])
	return "\n".join(out) + "\n"


func _pair_lines(of_rows: Array[Dictionary], names: Dictionary) -> PackedStringArray:
	var first: Dictionary = of_rows[0]
	var red: String = "%s (red)" % names.get(first.red, first.red)
	var blue: String = "%s (blue)" % names.get(first.blue, first.blue)
	var lines: PackedStringArray = []
	lines.append("%s vs %s: %d fights from seed %d, %s rules" % [red, blue, of_rows.size(), of_rows[0].seed, first.ruleset])
	lines.append("  Wins       %s %s · %s %s · draw %s" % [red, _pct(win_share(of_rows, "red")), blue, _pct(win_share(of_rows, "blue")), _pct(method_share(of_rows, FightSummary.METHOD_DRAW))])
	lines.append("  How        KO %s · TKO %s · decision %s · draw %s" % [
		_pct(method_share(of_rows, FightSummary.METHOD_KO)), _pct(method_share(of_rows, FightSummary.METHOD_TKO)),
		_pct(method_share(of_rows, FightSummary.METHOD_DECISION)), _pct(method_share(of_rows, FightSummary.METHOD_DRAW))])
	lines.append("  Rounds     10-10 on %s of judges' cards · %.2f knockdowns a fight" % [
		_pct(even_card_share(of_rows)), average(of_rows, "knockdowns_red") + average(of_rows, "knockdowns_blue")])
	for side: String in FightSummary.SIDES:
		var who: String = red if side == "red" else blue
		var thrown: float = average(of_rows, "thrown_" + side)
		var landed: float = average(of_rows, "landed_" + side)
		lines.append("  %-10s lands %.0f of %.0f (%s) · head damage taken %.0f · stamina at the end %s, lowest %s" % [
			who, landed, thrown, _pct(landed / thrown if thrown > 0.0 else 0.0), average(of_rows, "head_damage_" + side),
			_pct(average(of_rows, "stamina_end_" + side)), _pct(average(of_rows, "stamina_low_" + side))])
	lines.append("  Tired      someone under 50%% of the tank in %s of fights" % _pct(tired_share(of_rows)))
	lines.append("  Odds       %s of exchanges hit the 5–95%% clamp" % _pct(clamped_share(of_rows)))
	return lines


static func _pct(fraction: float) -> String:
	return "%.1f%%" % (fraction * 100.0)
