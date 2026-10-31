class_name BalanceReport
extends RefCounted
## The balance harness report (#18, docs/04 §7, D95): FightSummary rows in, a
## CSV and a readable summary out, with each balance target from the decisions
## marked as met or missed. Pure text; tools/balance.gd runs the fights and
## writes the files.

## D97: draws under 2%, and 10-10 rounds very rare (read here as under 2% of judges' round cards).
const DRAWS_UNDER: float = 0.02
const EVEN_CARDS_UNDER: float = 0.02
## FighterAI.PARTS as the AI parts line names them (D254).
const PART_NAMES: Array[String] = ["defence", "counter", "combination", "set-up", "lead", "cage", "tied up", "downed"]
## docs/12 §4: the showcase pair should be within 60/40 once the AI (#14) lands.
const SHOWCASE: Array[String] = ["kicker", "boxer"]
const SHOWCASE_WITHIN: float = 0.6
## D104, D109: the Wrestler's pairings are reported with no pass mark until after the playtest.
const WRESTLER := "wrestler"
const WRESTLER_OPPONENTS: Array[String] = ["kicker", "boxer"]
## D128: the Judoka and the BJJ fighter are reported the same way, against the other three styles.
const THROWERS := { "judoka": "Judoka", "bjj": "BJJ fighter" }
const THROWER_OPPONENTS: Array[String] = ["kicker", "boxer", "wrestler"]
## D129: and the Muay Thai fighter, against the same three.
const CLINCH_FIGHTERS := { "muay_thai": "Muay Thai fighter" }
## The leg-lock fighter (D132): reported against the same opponents, plus the BJJ fighter.
const LEG_LOCKERS := { "sambo": "Sambo fighter" }
const LEG_LOCKER_OPPONENTS: Array[String] = ["kicker", "boxer", "wrestler", "bjj"]
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
	out.append(_check("Draws under 2%", "D97", _share_text(plain, draws), draws < DRAWS_UNDER))
	var even: float = even_card_share(plain)
	out.append(_check("10-10 rounds very rare (under 2% of judges' cards)", "D97", _pct(even), even < EVEN_CARDS_UNDER))
	var showcase: Array[Dictionary] = plain.filter(_is_showcase)
	if not showcase.is_empty():
		var best: float = maxf(fighter_win_share(showcase, SHOWCASE[0]), fighter_win_share(showcase, SHOWCASE[1]))
		var spread: Vector2 = BalanceStats.wilson(best * showcase.size(), showcase.size())
		var value: String = "favourite wins %s" % BalanceStats.share_text(best, spread)
		if spread.x <= SHOWCASE_WITHIN and spread.y > SHOWCASE_WITHIN:
			value += ", too close to 60% to tell at this many fights"  # D250: the range crosses the line.
		out.append(_check("Kicker vs Boxer within 60/40, the exit test for the AI", "#14, docs/12 §4", value, best <= SHOWCASE_WITHIN))
	for opponent in WRESTLER_OPPONENTS:
		var pair: Array[Dictionary] = plain.filter(func(row: Dictionary) -> bool:
			return [row.red, row.blue] == [WRESTLER, opponent] or [row.blue, row.red] == [WRESTLER, opponent])
		if not pair.is_empty():
			out.append(_info("Wrestler vs %s: the Wrestler wins" % opponent.capitalize(), "D109", _pct(fighter_win_share(pair, WRESTLER))))
	var groups: Array[Dictionary] = [THROWERS, CLINCH_FIGHTERS, LEG_LOCKERS]
	var decisions: Array[String] = ["D128", "D129", "D132"]
	for g in groups.size():
		var styles: Dictionary = groups[g]
		var decision: String = decisions[g]
		for stylist: String in styles:
			for opponent in (LEG_LOCKER_OPPONENTS if styles == LEG_LOCKERS else THROWER_OPPONENTS):
				var pair: Array[Dictionary] = plain.filter(func(row: Dictionary) -> bool:
					return [row.red, row.blue] == [stylist, opponent] or [row.blue, row.red] == [stylist, opponent])
				if not pair.is_empty():
					var who: String = styles[stylist]
					var them: String = THROWERS.get(opponent, opponent.capitalize())
					out.append(_info("%s vs %s: the %s wins" % [who, them, who], decision, _pct(fighter_win_share(pair, stylist))))
	out.append(_info("Fights where someone got tired (under 50% of the tank)", "D96", _pct(tired_share(plain))))
	out.append(_info("Fights finished inside the distance", "docs/12 §4", _pct(finish_share(plain))))
	out.append(_info("Exchanges that hit the 5–95% odds clamp", "docs/12 §4", _pct(clamped_share(plain))))
	out.append(_info("Standing time with one fighter chasing the other", "D107", _pct(average(plain, "chase"))))
	out.append(_info("Standing time the more-fenced fighter spends near the fence", "D107", _pct(fenced_share(plain))))
	out.append_array(coaching_checks())
	out.append_array(rule_checks())
	return out


## For each fighter coached by a bot (in either corner, the other corner empty) against an
## opponent, next to the same two fighters without calls: what the bot did to the coached
## fighter's wins, with its 95% range (D250). The ideal caller should add +10–20% (D12), the
## spam caller should cost wins; the AI corner (D68) is reported.
func coaching_checks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var coached: Dictionary = {}  # "id:opponent" → style → [rows, side]
	for row in rows:
		var side: String = coached_side(row)
		if side == "":
			continue
		var by_style: Dictionary = coached.get_or_add("%s:%s" % [row[side], row[_other(side)]], {})
		by_style.get_or_add(corner(row, side), []).append([row, side])
	var plain: Dictionary = _by_fight(uncoached())
	for key: String in coached:
		var ids: PackedStringArray = key.split(":")
		var who: String = "%s coached against the %s" % [ids[0].capitalize(), ids[1].capitalize()]
		for style: String in [Corner.IDEAL, Corner.SPAM, Corner.AI]:
			if not coached[key].has(style):
				continue
			var change: Dictionary = _change(coached[key][style], plain, ids)
			if change.is_empty():
				continue
			match style:
				Corner.IDEAL:
					out.append(_check("%s: good coaching adds +10–20%% wins" % who, "D12", change.text,
						change.mean >= COACHING_GAIN_MIN and change.mean <= COACHING_GAIN_MAX))
				Corner.SPAM:
					out.append(_check("%s: spam calls win less than no calls" % who, "D12", change.text, change.mean < 0.0))
				Corner.AI:
					out.append(_info("%s: the AI corner" % who, "D68", change.text))
	return out


## For each fighter with drilled rules (the other with none, no coaching bots) against an
## opponent, next to the same two fighters without rules: what the rules did to their wins,
## with its 95% range (#17, D250; reported with no pass mark yet).
func rule_checks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ruled: Dictionary = {}  # "id:opponent" → rules → [rows, side]
	for row in rows:
		var side: String = ruled_side(row)
		if side == "":
			continue
		var by_rules: Dictionary = ruled.get_or_add("%s:%s" % [row[side], row[_other(side)]], {})
		by_rules.get_or_add(drilled(row, side), []).append([row, side])
	var plain: Dictionary = _by_fight(uncoached())
	for key: String in ruled:
		var ids: PackedStringArray = key.split(":")
		for rules: String in ruled[key]:
			var change: Dictionary = _change(ruled[key][rules], plain, ids)
			if not change.is_empty():
				out.append(_info("%s drilled (%s) against the %s" % [ids[0].capitalize(), rules, ids[1].capitalize()], "#17", change.text))
	return out


## Fights without calls or rules by "red:blue#seed", to find the plain twin of a coached fight.
static func _by_fight(of_rows: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for row in of_rows:
		out["%s#%s" % [fighters_key(row), row.seed]] = row
	return out


## What a coach or drilled rules did to fighter ids[0]'s wins against ids[1]: `changed` is
## [row, side the fighter was on] for each fight with them, `plain` the fights without (_by_fight).
## When every changed fight has a plain twin (same corners, same seed: the harness plays them
## so), each seed is one paired difference; otherwise the shares are compared unpaired, against
## the plain fights between the two either way round. Returns { mean, text } or {} with no plain fights.
static func _change(changed: Array, plain: Dictionary, ids: PackedStringArray) -> Dictionary:
	var after: Array = []
	var before: Array = []
	var diffs: Array = []
	for entry: Array in changed:
		var row: Dictionary = entry[0]
		var side: String = entry[1]
		after.append(1.0 if row.winner == side else 0.0)
		var twin: Dictionary = plain.get("%s#%s" % [fighters_key(row), row.seed], {})
		if not twin.is_empty():
			before.append(1.0 if twin.winner == side else 0.0)
			diffs.append(after[-1] - before[-1])
	var change: Dictionary
	var how: String
	if diffs.size() == changed.size():
		change = BalanceStats.paired(diffs)
		how = "%d fights paired by seed" % diffs.size()
	else:
		before.clear()
		for row: Dictionary in plain.values():
			if [row.red, row.blue] == [ids[0], ids[1]] or [row.red, row.blue] == [ids[1], ids[0]]:
				before.append(_side_score(row, ids[0]))
		if before.is_empty():
			return {}
		change = BalanceStats.unpaired(before, after)
		how = "%d and %d fights, not paired" % [before.size(), after.size()]
	return { "mean": change.mean, "text": "%s, %s → %s, %s" % [BalanceStats.change_text(change),
		_pct(BalanceStats.mean(before)), _pct(BalanceStats.mean(after)), how] }


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
## `names` maps fighter id → display name (ids are used when missing). `run` is what the
## run was made from (D250): { commit, data, godot, and order when blue stepped first (D252) }, shown first when given.
func summary(names: Dictionary = {}, run: Dictionary = {}) -> String:
	var out: PackedStringArray = []
	if not run.is_empty():
		out.append("Run: commit %s · data files %s · Godot %s%s" % [run.get("commit", "?"), run.get("data", "?"), run.get("godot", "?"),
			(" · " + str(run.order)) if run.has("order") else ""])
		out.append("")
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
	lines.append("  Wins       %s %s · %s %s · draw %s (95%% ranges, D250)" % [red, _share_text(of_rows, win_share(of_rows, "red")),
		blue, _share_text(of_rows, win_share(of_rows, "blue")), _pct(method_share(of_rows, FightSummary.METHOD_DRAW))])
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
	lines.append("  Circling   %s %s, %s %s · cutting off the cage: %s %s, %s %s · cut off onto the fence %s %.1f, %s %.1f a fight (D230)" % [
		red, _time_line(of_rows, "circling_red"), blue, _time_line(of_rows, "circling_blue"),
		red, _time_line(of_rows, "cutting_red"), blue, _time_line(of_rows, "cutting_blue"),
		red, average(of_rows, "cut_offs_red"), blue, average(of_rows, "cut_offs_blue")])
	lines.append("  Cut off    %s · %s (D233)" % [_cut_off_line(of_rows, red, "red", "blue"), _cut_off_line(of_rows, blue, "blue", "red")])
	lines.append("  Resets     back to the middle %s %.1f a fight (made it %.1f, cut off %.1f) · %s %.1f (%.1f, %.1f) (D290)" % [
		red, average(of_rows, "resets_red"), average(of_rows, "resets_made_red"), average(of_rows, "resets_cut_red"),
		blue, average(of_rows, "resets_blue"), average(of_rows, "resets_made_blue"), average(of_rows, "resets_cut_blue")])
	lines.append("  Grappling  takedowns %s %.1f of %.1f a fight, %s %.1f of %.1f · clinch %s of the fight · ground %s (%s on top %s, %s on top %s)" % [
		red, average(of_rows, "takedowns_red"), average(of_rows, "shots_red"), blue, average(of_rows, "takedowns_blue"), average(of_rows, "shots_blue"),
		_pct(average(of_rows, "clinch")), _pct(average(of_rows, "ground")), red, _pct(average(of_rows, "top_red")), blue, _pct(average(of_rows, "top_blue"))])
	lines.append("  Subs       %s %.1f tried, %.1f locked a fight · %s %.1f tried, %.1f locked (D126)" % [
		red, average(of_rows, "subs_red"), average(of_rows, "locked_red"), blue, average(of_rows, "subs_blue"), average(of_rows, "locked_blue")])
	lines.append("  Leg locks  %s %.1f tried, %.1f locked a fight · %s %.1f tried, %.1f locked · ended %s of fights (D132)" % [
		red, average(of_rows, "leg_locks_red"), average(of_rows, "leg_locked_red"), blue, average(of_rows, "leg_locks_blue"), average(of_rows, "leg_locked_blue"),
		_pct(average(of_rows, "leg_lock_finish"))])
	lines.append("  Throws     %s %.1f of %.1f a fight landed · %s %.1f of %.1f (D128)" % [
		red, average(of_rows, "throws_landed_red"), average(of_rows, "throws_red"), blue, average(of_rows, "throws_landed_blue"), average(of_rows, "throws_blue")])
	lines.append("  Clinch     %s collar ties %.1f of %.1f won, knees landed %.1f (%.1f from the tie) · %s %.1f of %.1f, %.1f (%.1f) (D129)" % [
		red, average(of_rows, "collar_ties_won_red"), average(of_rows, "collar_ties_red"), average(of_rows, "clinch_knees_red"), average(of_rows, "tied_knees_red"),
		blue, average(of_rows, "collar_ties_won_blue"), average(of_rows, "collar_ties_blue"), average(of_rows, "clinch_knees_blue"), average(of_rows, "tied_knees_blue")])
	lines.append("  Cage       %s holds him on the fence %s of the fight, drives %.1f of %.1f won, spin-offs %.1f of %.1f · %s %s, %.1f of %.1f, %.1f of %.1f (D220)" % [
		red, _pct(average(of_rows, "fence_hold_red")), average(of_rows, "fence_drives_won_red"), average(of_rows, "fence_drives_red"),
		average(of_rows, "spin_offs_won_red"), average(of_rows, "spin_offs_red"),
		blue, _pct(average(of_rows, "fence_hold_blue")), average(of_rows, "fence_drives_won_blue"), average(of_rows, "fence_drives_blue"),
		average(of_rows, "spin_offs_won_blue"), average(of_rows, "spin_offs_blue")])
	lines.append("  Grips      %s an underhook %s of the clinch (both %s), pummels %.1f of %.1f won, strips %.1f of %.1f, turns him on the fence %.1f of %.1f · %s %s (%s), %.1f of %.1f, %.1f of %.1f, %.1f of %.1f (D261, D262)" % [
		red, _pct(average(of_rows, "underhook_red")), _pct(average(of_rows, "body_lock_red")), average(of_rows, "pummels_won_red"), average(of_rows, "pummels_red"),
		average(of_rows, "strips_won_red"), average(of_rows, "strips_red"), average(of_rows, "turns_won_red"), average(of_rows, "turns_red"),
		blue, _pct(average(of_rows, "underhook_blue")), _pct(average(of_rows, "body_lock_blue")), average(of_rows, "pummels_won_blue"), average(of_rows, "pummels_blue"),
		average(of_rows, "strips_won_blue"), average(of_rows, "strips_blue"), average(of_rows, "turns_won_blue"), average(of_rows, "turns_blue")])
	lines.append("  Ground grip %s ties up %.1f of %.1f, wrists %.1f of %.1f; held on top %s of his time there (no punches %s), postures up %.1f of %.1f; half-guard underhook %s, %.1f of %.1f · %s %.1f of %.1f, %.1f of %.1f; %s (%s), %.1f of %.1f; %s, %.1f of %.1f (D263)" % [
		red, average(of_rows, "ground_ties_won_red"), average(of_rows, "ground_ties_red"), average(of_rows, "wrists_won_red"), average(of_rows, "wrists_red"),
		_pct(average(of_rows, "held_top_red")), _pct(average(of_rows, "tied_top_red")), average(of_rows, "postures_won_red"), average(of_rows, "postures_red"),
		_pct(average(of_rows, "half_uh_red")), average(of_rows, "half_uhs_won_red"), average(of_rows, "half_uhs_red"),
		blue, average(of_rows, "ground_ties_won_blue"), average(of_rows, "ground_ties_blue"), average(of_rows, "wrists_won_blue"), average(of_rows, "wrists_blue"),
		_pct(average(of_rows, "held_top_blue")), _pct(average(of_rows, "tied_top_blue")), average(of_rows, "postures_won_blue"), average(of_rows, "postures_blue"),
		_pct(average(of_rows, "half_uh_blue")), average(of_rows, "half_uhs_won_blue"), average(of_rows, "half_uhs_blue")])
	lines.append("  Positions  full guard %s · half guard %s · side control %s · mount %s · back %s of the fight · better positions on top %s %.1f, %s %.1f · out from under %s %.1f, %s %.1f a fight (D130)" % [
		_pct(average(of_rows, "full_guard")), _pct(average(of_rows, "half_guard")), _pct(average(of_rows, "side_control")),
		_pct(average(of_rows, "mount")), _pct(average(of_rows, "back_control")),
		red, average(of_rows, "advances_red"), blue, average(of_rows, "advances_blue"),
		red, average(of_rows, "escapes_red"), blue, average(of_rows, "escapes_blue")])
	lines.append("  Feints     %s %.1f a fight, %.1f bit on · %s %.1f, %.1f · blind shots %s %.1f (%.1f worked), %s %.1f (%.1f) · strikes off a bite %s %.1f (%.1f landed), %s %.1f (%.1f) (D131, D236)" % [
		red, average(of_rows, "feints_red"), average(of_rows, "feints_bit_red"), blue, average(of_rows, "feints_blue"), average(of_rows, "feints_bit_blue"),
		red, average(of_rows, "blind_red"), average(of_rows, "blind_landed_red"), blue, average(of_rows, "blind_blue"), average(of_rows, "blind_landed_blue"),
		red, average(of_rows, "off_feint_red"), average(of_rows, "off_feint_landed_red"), blue, average(of_rows, "off_feint_blue"), average(of_rows, "off_feint_landed_blue")])
	lines.append("  Combos     %s %.1f a fight, follow-ups land %s · %s %.1f, %s (D133)" % [
		red, average(of_rows, "combos_red"), _pct(_ratio(of_rows, "combo_landed_red", "combo_strikes_red")),
		blue, average(of_rows, "combos_blue"), _pct(_ratio(of_rows, "combo_landed_blue", "combo_strikes_blue"))])
	lines.append("  Defence    %s checks %.1f of %.1f worked, slips %.1f of %.1f, %.1f hits on the guard · %s %.1f of %.1f, %.1f of %.1f, %.1f (D180)" % [
		red, average(of_rows, "checked_red"), average(of_rows, "checks_red"), average(of_rows, "slipped_red"), average(of_rows, "slips_red"), average(of_rows, "covered_hits_red"),
		blue, average(of_rows, "checked_blue"), average(of_rows, "checks_blue"), average(of_rows, "slipped_blue"), average(of_rows, "slips_blue"), average(of_rows, "covered_hits_blue")])
	lines.append("  GnP        %s %s · %s %s (D270)" % [red, _gnp_line(of_rows, "red", "blue"), blue, _gnp_line(of_rows, "blue", "red")])
	lines.append("  Chosen by  %s %s · %s %s (D250)" % [red, _chosen_line(of_rows, "red"), blue, _chosen_line(of_rows, "blue")])
	lines.append("  AI parts   %s %s · %s %s (D254)" % [red, _parts_line(of_rows, "red"), blue, _parts_line(of_rows, "blue")])
	lines.append("  Tired      someone under 50%% of the tank in %s of fights" % _pct(tired_share(of_rows)))
	lines.append("  Odds       %s of exchanges hit the 5–95%% clamp" % _pct(clamped_share(of_rows)))
	return lines


## One side's ground and pound (D270): "lands 14.2 a fight (hammerfists 21% · body 18% · bombs 6%),
## the other man covers up 2.1 times (3.4 on the gloves), turns away 0.2".
static func _gnp_line(of_rows: Array[Dictionary], side: String, other: String) -> String:
	var landed: float = average(of_rows, "gnp_landed_" + side)
	var share := func(key: String) -> String: return _pct(average(of_rows, "%s_%s" % [key, side]) / landed if landed > 0.0 else 0.0)
	return "lands %.1f a fight (hammerfists %s · body %s · bombs %s), the other covers up %.1f (%.1f on the gloves), turns away %.2f" % [
		landed, share.call("gnp_hammer"), share.call("gnp_body"), share.call("gnp_bomb"),
		average(of_rows, "ground_covers_" + other), average(of_rows, "gnp_covered_" + other), average(of_rows, "turned_away_" + other)]


## Who chose a side's moves, as shares: "own AI 97.1% · calls 2.4% · rules 0.5% · commands 0.0% of 312 moves a fight".
static func _chosen_line(of_rows: Array[Dictionary], side: String) -> String:
	var counts: Array[float] = []
	var total: float = 0.0
	for layer: String in FightSummary.CHOOSERS:
		counts.append(average(of_rows, "chosen_%s_%s" % [layer, side]))
		total += counts[-1]
	var parts: PackedStringArray = []
	var names: Array[String] = ["own AI", "calls", "rules", "commands"]
	for n in counts.size():
		parts.append("%s %s" % [names[n], _pct(counts[n] / total if total > 0.0 else 0.0)])
	return "%s of %.0f moves a fight" % [" · ".join(parts), total]


## Which part of a side's own AI chose its moves (FighterAI.PARTS, D254), as shares, the ones it never used
## left out: "lead 61.2% · counter 20.4% · combination 12.0% · defence 6.4% of 140 a fight".
static func _parts_line(of_rows: Array[Dictionary], side: String) -> String:
	var counts: Array[float] = []
	var total: float = 0.0
	for part: String in FighterAI.PARTS:
		counts.append(average(of_rows, "ai_%s_%s" % [part, side]))
		total += counts[-1]
	var shown: PackedStringArray = []
	for n in counts.size():
		if counts[n] > 0.0:
			shown.append("%s %s" % [PART_NAMES[n], _pct(counts[n] / total)])
	return "%s of %.0f a fight" % [" · ".join(shown) if not shown.is_empty() else "nothing", total]


## A share of these fights with its 95% range (D250): "55.0% (45.3–64.4%)".
static func _share_text(of_rows: Array[Dictionary], fraction: float) -> String:
	return BalanceStats.share_text(fraction, BalanceStats.wilson(fraction * of_rows.size(), of_rows.size()))


## A fight-seconds column as "m:ss a fight (share of fight time)", e.g. "6:12 a fight (41%)" (D119).
## Being cut off (D233), for one side: how often he got back to the middle of the times he was
## cut off onto the fence, how long he was shut in, and what cutting him off cost the other man;
## then the doors the other man sold him shut with a feint and how often he turned back into it (D235).
static func _cut_off_line(of_rows: Array[Dictionary], who: String, side: String, other: String) -> String:
	var trapped: float = average(of_rows, "cut_offs_" + other)
	if trapped < 0.05:
		return "%s never cut off" % who
	var escaped: float = average(of_rows, "cage_escapes_" + side)
	var seconds: int = roundi(average(of_rows, "shut_in_" + side))
	return "%s got back to the middle %.1f of %.1f times a fight (%s), shut in %d:%02d, %.0f damage to the man cutting him off, sold %.1f doors shut (turned back into %.1f)" % [
		who, escaped, trapped, _pct(escaped / trapped if trapped > 0.0 else 0.0), seconds / 60, seconds % 60, average(of_rows, "cut_hurt_" + other),
		average(of_rows, "doors_sold_" + other), average(of_rows, "turned_back_" + other)]


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
