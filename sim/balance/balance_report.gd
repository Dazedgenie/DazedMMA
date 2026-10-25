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
## D104, D109: the Wrestler's pairings are reported with no pass mark until after the playtest.
const WRESTLER := "wrestler"
const WRESTLER_OPPONENTS: Array[String] = ["kicker", "boxer"]
## D96: someone who pushed or had the pace pushed on them ends at ~30–50% of the tank.
const TIRED_BELOW: float = 0.5
## D12, docs/10 §2: the ideal caller adds +10–20% to the coached fighter's wins over no calls;
## the spam caller wins less than no calls (Corner styles, compared matchup by matchup).
const COACHING_GAIN_MIN: float = 0.10
const COACHING_GAIN_MAX: float = 0.20

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


## "red:blue", with " red corner ideal" (and blue's) when a coaching bot made calls.
static func pair_key(row: Dictionary) -> String:
	var key: String = fighters_key(row)
	for side: String in FightSummary.SIDES:
		if corner(row, side) != Corner.NONE:
			key += " %s corner %s" % [side, corner(row, side)]
	return key


## "red:blue" whatever the corners did.
static func fighters_key(row: Dictionary) -> String:
	return "%s:%s" % [row.red, row.blue]


## The coaching bot in this side's corner ("none" in rows from before the bots).
static func corner(row: Dictionary, side: String) -> String:
	var style: String = str(row.get("corner_" + side, Corner.NONE))
	return style if style != "" and style != "0" else Corner.NONE


## The fights with no coaching bot in either corner: the fight engine's own balance.
func uncoached() -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool:
		return corner(row, "red") == Corner.NONE and corner(row, "blue") == Corner.NONE)


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


## Share of these fights won by the fighter with this data/fighters id, whichever corner they were in.
static func fighter_win_share(of_rows: Array[Dictionary], fighter_id: String) -> float:
	return share(of_rows, func(row: Dictionary) -> bool: return row.winner_id == fighter_id)


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


## Average over fights of the bigger of the two fighters' time near the fence (FightSummary fence_*).
static func fenced_share(of_rows: Array[Dictionary]) -> float:
	if of_rows.is_empty():
		return 0.0
	var total: float = 0.0
	for row in of_rows:
		total += maxf(float(row.fence_red), float(row.fence_blue))
	return total / of_rows.size()


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
	# The engine's targets are about fights without calls; coached fights get their own checks.
	var plain: Array[Dictionary] = uncoached()
	if plain.is_empty():
		return coaching_checks()
	var draws: float = method_share(plain, FightSummary.METHOD_DRAW)
	out.append(_check("Draws under 2%", "D97", _pct(draws), draws < DRAWS_UNDER))
	var even: float = even_card_share(plain)
	out.append(_check("10-10 rounds very rare (under 2% of judges' cards)", "D97", _pct(even), even < EVEN_CARDS_UNDER))
	var showcase: Array[Dictionary] = plain.filter(_is_showcase)
	if not showcase.is_empty():
		var best: float = maxf(fighter_win_share(showcase, SHOWCASE[0]), fighter_win_share(showcase, SHOWCASE[1]))
		out.append(_check("Kicker vs Boxer within 60/40, the exit test for the AI", "#14, docs/12 §4",
			"favourite wins %s" % _pct(best), best <= SHOWCASE_WITHIN))
	for opponent in WRESTLER_OPPONENTS:
		var pair: Array[Dictionary] = plain.filter(func(row: Dictionary) -> bool:
			return [row.red, row.blue] == [WRESTLER, opponent] or [row.blue, row.red] == [WRESTLER, opponent])
		if not pair.is_empty():
			out.append(_info("Wrestler vs %s: the Wrestler wins" % opponent.capitalize(), "D109", _pct(fighter_win_share(pair, WRESTLER))))
	out.append(_info("Fights where someone got tired (under 50% of the tank)", "D96", _pct(tired_share(plain))))
	out.append(_info("Fights finished inside the distance", "docs/12 §4", _pct(finish_share(plain))))
	out.append(_info("Exchanges that hit the 5–95% odds clamp", "docs/12 §4", _pct(clamped_share(plain))))
	out.append(_info("Standing time with one fighter chasing the other", "D107", _pct(average(plain, "chase"))))
	out.append(_info("Standing time the more-fenced fighter spends near the fence", "D107", _pct(fenced_share(plain))))
	out.append_array(coaching_checks())
	return out


## For each fighter coached by a bot (in either corner, the other corner empty) against an
## opponent, next to the same two fighters without calls (either way round): what the bot
## did to the coached fighter's wins. The ideal caller should add +10–20% (D12), the spam
## caller should cost wins; the AI corner (D68) is reported.
func coaching_checks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var coached: Dictionary = {}  # "id:opponent" → style → [scores]
	for row in rows:
		var side: String = coached_side(row)
		if side == "":
			continue
		var key: String = "%s:%s" % [row[side], row[_other(side)]]
		var by_style: Dictionary = coached.get_or_add(key, {})
		by_style.get_or_add(corner(row, side), []).append(1.0 if row.winner == side else 0.0)
	var plain: Array[Dictionary] = uncoached()
	for key: String in coached:
		var ids: PackedStringArray = key.split(":")
		var base_scores: Array = []
		for row in plain:
			if [row.red, row.blue] == [ids[0], ids[1]] or [row.red, row.blue] == [ids[1], ids[0]]:
				base_scores.append(_side_score(row, ids[0]))
		if base_scores.is_empty():
			continue
		var base: float = _mean(base_scores)
		var who: String = "%s coached against the %s" % [ids[0].capitalize(), ids[1].capitalize()]
		for style: String in [Corner.IDEAL, Corner.SPAM, Corner.AI]:
			if not coached[key].has(style):
				continue
			var with_bot: float = _mean(coached[key][style])
			var gain: float = with_bot - base
			var value: String = "%+.1f%% (%s → %s, %d and %d fights)" % [gain * 100.0, _pct(base), _pct(with_bot), base_scores.size(), coached[key][style].size()]
			match style:
				Corner.IDEAL:
					out.append(_check("%s: good coaching adds +10–20%% wins" % who, "D12", value,
						gain >= COACHING_GAIN_MIN and gain <= COACHING_GAIN_MAX))
				Corner.SPAM:
					out.append(_check("%s: spam calls win less than no calls" % who, "D12", value, gain < 0.0))
				Corner.AI:
					out.append(_info("%s: the AI corner" % who, "D68", value))
	return out


## "red" or "blue" when exactly one corner has a coaching bot, else "".
static func coached_side(row: Dictionary) -> String:
	var red: bool = corner(row, "red") != Corner.NONE
	var blue: bool = corner(row, "blue") != Corner.NONE
	if red == blue:
		return ""
	return "red" if red else "blue"


## 1 when the fighter with this id won the fight, 0 when not; in a mirror, half a win per side.
static func _side_score(row: Dictionary, id: String) -> float:
	var score: float = 0.0
	var sides: int = 0
	for side: String in FightSummary.SIDES:
		if row[side] == id:
			sides += 1
			score += 1.0 if row.winner == side else 0.0
	return score / sides if sides > 0 else 0.0


static func _other(side: String) -> String:
	return "blue" if side == "red" else "red"


static func _mean(values: Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / values.size() if not values.is_empty() else 0.0


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
	out.append("Targets (all %d fights; the engine's own on the %d without calls)" % [rows.size(), uncoached().size()])
	for c in checks():
		out.append("  %-7s %s: %s  [%s]" % [c.status, c.name, c.value, c.source])
	return "\n".join(out) + "\n"


func _pair_lines(of_rows: Array[Dictionary], names: Dictionary) -> PackedStringArray:
	var first: Dictionary = of_rows[0]
	var red: String = "%s (red)" % names.get(first.red, first.red)
	var blue: String = "%s (blue)" % names.get(first.blue, first.blue)
	var lines: PackedStringArray = []
	lines.append("%s vs %s: %d fights from seed %d, %s rules" % [red, blue, of_rows.size(), of_rows[0].seed, first.ruleset])
	for side: String in FightSummary.SIDES:
		if corner(first, side) != Corner.NONE:
			lines.append("  Corner     %s's corner: %s caller, %.1f calls a fight" % [red if side == "red" else blue, corner(first, side), average(of_rows, "calls_" + side)])
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
	lines.append("  Feet       near the fence: %s %s (pinned %s), %s %s (pinned %s) · nearer the centre: %s %s, %s %s · chasing %s" % [
		red, _pct(average(of_rows, "fence_red")), _pct(average(of_rows, "pinned_red")),
		blue, _pct(average(of_rows, "fence_blue")), _pct(average(of_rows, "pinned_blue")),
		red, _pct(average(of_rows, "centre_red")), blue, _pct(average(of_rows, "centre_blue")), _pct(average(of_rows, "chase"))])
	lines.append("  Grappling  takedowns %s %.1f of %.1f a fight, %s %.1f of %.1f · clinch %s of the fight · ground %s (%s on top %s, %s on top %s)" % [
		red, average(of_rows, "takedowns_red"), average(of_rows, "shots_red"), blue, average(of_rows, "takedowns_blue"), average(of_rows, "shots_blue"),
		_pct(average(of_rows, "clinch")), _pct(average(of_rows, "ground")), red, _pct(average(of_rows, "top_red")), blue, _pct(average(of_rows, "top_blue"))])
	lines.append("  Tired      someone under 50%% of the tank in %s of fights" % _pct(tired_share(of_rows)))
	lines.append("  Odds       %s of exchanges hit the 5–95%% clamp" % _pct(clamped_share(of_rows)))
	return lines


static func _pct(fraction: float) -> String:
	return "%.1f%%" % (fraction * 100.0)
