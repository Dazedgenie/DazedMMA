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
## D128: the Judoka and the BJJ fighter are reported the same way, against the other three styles.
const THROWERS := { "judoka": "Judoka", "bjj": "BJJ fighter" }
const THROWER_OPPONENTS: Array[String] = ["kicker", "boxer", "wrestler"]
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


## "red:blue", with " red corner ideal" (and blue's) when a coaching bot made calls, and
## " red rules catch_kick_and_shoot@80" when a fighter had drilled rules.
static func pair_key(row: Dictionary) -> String:
	var key: String = fighters_key(row)
	for side: String in FightSummary.SIDES:
		if corner(row, side) != Corner.NONE:
			key += " %s corner %s" % [side, corner(row, side)]
		if drilled(row, side) != "":
			key += " %s rules %s" % [side, drilled(row, side)]
	return key


## "red:blue" whatever the corners did.
static func fighters_key(row: Dictionary) -> String:
	return "%s:%s" % [row.red, row.blue]


## The coaching bot in this side's corner ("none" in rows from before the bots).
static func corner(row: Dictionary, side: String) -> String:
	var style: String = str(row.get("corner_" + side, Corner.NONE))
	return style if style != "" and style != "0" else Corner.NONE


## This side's drilled rules ("" for none, and in rows from before #17).
static func drilled(row: Dictionary, side: String) -> String:
	var text: String = str(row.get("rules_" + side, ""))
	return text if text != "0" else ""


## The fights with no coaching bot in either corner and no drilled rules: the fight engine's own balance.
func uncoached() -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool:
		return corner(row, "red") == Corner.NONE and corner(row, "blue") == Corner.NONE \
			and drilled(row, "red") == "" and drilled(row, "blue") == "")


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


## KOs, TKOs and submissions: fights that ended inside the distance.
static func finish_share(of_rows: Array[Dictionary]) -> float:
	return method_share(of_rows, FightSummary.METHOD_KO) + method_share(of_rows, FightSummary.METHOD_TKO) \
		+ method_share(of_rows, FightSummary.METHOD_SUB)


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
		return coaching_checks() + rule_checks()
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
	for thrower: String in THROWERS:
		for opponent in THROWER_OPPONENTS:
			var pair: Array[Dictionary] = plain.filter(func(row: Dictionary) -> bool:
				return [row.red, row.blue] == [thrower, opponent] or [row.blue, row.red] == [thrower, opponent])
			if not pair.is_empty():
				var who: String = THROWERS[thrower]
				out.append(_info("%s vs %s: the %s wins" % [who, opponent.capitalize(), who], "D128", _pct(fighter_win_share(pair, thrower))))
	out.append(_info("Fights where someone got tired (under 50% of the tank)", "D96", _pct(tired_share(plain))))
	out.append(_info("Fights finished inside the distance", "docs/12 §4", _pct(finish_share(plain))))
	out.append(_info("Exchanges that hit the 5–95% odds clamp", "docs/12 §4", _pct(clamped_share(plain))))
	out.append(_info("Standing time with one fighter chasing the other", "D107", _pct(average(plain, "chase"))))
	out.append(_info("Standing time the more-fenced fighter spends near the fence", "D107", _pct(fenced_share(plain))))
	out.append_array(coaching_checks())
	out.append_array(rule_checks())
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


## For each fighter with drilled rules (the other with none, no coaching bots) against an
## opponent, next to the same two fighters without rules: what the rules did to their wins
## (#17, reported with no pass mark yet).
func rule_checks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ruled: Dictionary = {}  # "id:opponent" → rules → [scores]
	for row in rows:
		var side: String = ruled_side(row)
		if side == "":
			continue
		var by_rules: Dictionary = ruled.get_or_add("%s:%s" % [row[side], row[_other(side)]], {})
		by_rules.get_or_add(drilled(row, side), []).append(1.0 if row.winner == side else 0.0)
	var plain: Array[Dictionary] = uncoached()
	for key: String in ruled:
		var ids: PackedStringArray = key.split(":")
		var base_scores: Array = []
		for row in plain:
			if [row.red, row.blue] == [ids[0], ids[1]] or [row.red, row.blue] == [ids[1], ids[0]]:
				base_scores.append(_side_score(row, ids[0]))
		if base_scores.is_empty():
			continue
		var base: float = _mean(base_scores)
		for rules: String in ruled[key]:
			var with_rules: float = _mean(ruled[key][rules])
			out.append(_info("%s drilled (%s) against the %s" % [ids[0].capitalize(), rules, ids[1].capitalize()], "#17",
				"%+.1f%% (%s → %s, %d and %d fights)" % [(with_rules - base) * 100.0, _pct(base), _pct(with_rules), base_scores.size(), ruled[key][rules].size()]))
	return out


## "red" or "blue" when exactly one corner has a coaching bot (and no rules either side), else "".
static func coached_side(row: Dictionary) -> String:
	var red: bool = corner(row, "red") != Corner.NONE
	var blue: bool = corner(row, "blue") != Corner.NONE
	if red == blue or drilled(row, "red") != "" or drilled(row, "blue") != "":
		return ""
	return "red" if red else "blue"


## "red" or "blue" when exactly one fighter has drilled rules (and no coaching bots), else "".
static func ruled_side(row: Dictionary) -> String:
	var red: bool = drilled(row, "red") != ""
	var blue: bool = drilled(row, "blue") != ""
	if red == blue or corner(row, "red") != Corner.NONE or corner(row, "blue") != Corner.NONE:
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
	out.append("Targets (all %d fights; the engine's own on the %d without calls or rules)" % [rows.size(), uncoached().size()])
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
		if drilled(first, side) != "":
			lines.append("  Rules      %s drilled %s, fired %.1f times a fight" % [red if side == "red" else blue, drilled(first, side), average(of_rows, "fired_" + side)])
	lines.append("  Wins       %s %s · %s %s · draw %s" % [red, _pct(win_share(of_rows, "red")), blue, _pct(win_share(of_rows, "blue")), _pct(method_share(of_rows, FightSummary.METHOD_DRAW))])
	lines.append("  How        KO %s · TKO %s · submission %s · decision %s · draw %s" % [
		_pct(method_share(of_rows, FightSummary.METHOD_KO)), _pct(method_share(of_rows, FightSummary.METHOD_TKO)),
		_pct(method_share(of_rows, FightSummary.METHOD_SUB)),
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
	lines.append("  Circling   %s %s, %s %s · cutting off the cage: %s %s, %s %s" % [
		red, _time_line(of_rows, "circling_red"), blue, _time_line(of_rows, "circling_blue"),
		red, _time_line(of_rows, "cutting_red"), blue, _time_line(of_rows, "cutting_blue")])
	lines.append("  Grappling  takedowns %s %.1f of %.1f a fight, %s %.1f of %.1f · clinch %s of the fight · ground %s (%s on top %s, %s on top %s)" % [
		red, average(of_rows, "takedowns_red"), average(of_rows, "shots_red"), blue, average(of_rows, "takedowns_blue"), average(of_rows, "shots_blue"),
		_pct(average(of_rows, "clinch")), _pct(average(of_rows, "ground")), red, _pct(average(of_rows, "top_red")), blue, _pct(average(of_rows, "top_blue"))])
	lines.append("  Subs       %s %.1f tried, %.1f locked a fight · %s %.1f tried, %.1f locked (D126)" % [
		red, average(of_rows, "subs_red"), average(of_rows, "locked_red"), blue, average(of_rows, "subs_blue"), average(of_rows, "locked_blue")])
	lines.append("  Throws     %s %.1f of %.1f a fight landed · %s %.1f of %.1f (D128)" % [
		red, average(of_rows, "throws_landed_red"), average(of_rows, "throws_red"), blue, average(of_rows, "throws_landed_blue"), average(of_rows, "throws_blue")])
	lines.append("  Tired      someone under 50%% of the tank in %s of fights" % _pct(tired_share(of_rows)))
	lines.append("  Odds       %s of exchanges hit the 5–95%% clamp" % _pct(clamped_share(of_rows)))
	return lines


## A fight-seconds column as "m:ss a fight (share of fight time)", e.g. "6:12 a fight (41%)" (D119).
static func _time_line(of_rows: Array[Dictionary], key: String) -> String:
	var seconds: int = roundi(average(of_rows, key))
	return "%d:%02d a fight (%.0f%%)" % [seconds / 60, seconds % 60, time_share(of_rows, key) * 100.0]


## A fight-seconds column (circling_red, cutting_blue, ...) as a share of all the fight time in these rows.
static func time_share(of_rows: Array[Dictionary], key: String) -> float:
	var part: float = 0.0
	var total: float = 0.0
	for row in of_rows:
		part += float(row[key])
		total += float(row.fight_seconds)
	return part / total if total > 0.0 else 0.0


static func _pct(fraction: float) -> String:
	return "%.1f%%" % (fraction * 100.0)
