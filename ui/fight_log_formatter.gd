class_name FightLogFormatter
extends RefCounted
## Turns FightEvents into readable console lines (BBCode) for the debug console.
## Presentation only: reads events and the sim's fighters/actions, never changes them.

const FIGHTER_COLOURS: Array[String] = ["#ff6b6b", "#5fa8ff"]
const PASS_COLOUR := "#6bd66b"
const FAIL_COLOUR := "#ff5555"
const DIM_COLOUR := "#8a8f98"
## Stats the debug summary shows when condition has moved them (docs/11 §3.2).
const RANGE_NAMES := { "out": "out of range", "long": "long (kicking range)", "mid": "mid (punching range)", "pocket": "in the pocket" }
const CAGE_NAMES := { "centre": "is back in open space", "near": "is near the fence", "pinned": "is PINNED against the cage" }
const RESULT_NAMES := { "ko": "KO", "tko": "TKO" }
const CALL_OUTCOMES := { "accepted": "takes", "ignored": "ignores", "infeasible": "can't do" }
const CONDITION_STATS: Array[String] = ["boxing", "kicking", "power", "speed", "striking_defense", "footwork", "takedowns", "takedown_defense", "fight_iq"]


## Phase changes are noisy; the console hides them unless "phase details" is on.
static func is_detail(event: FightEvent) -> bool:
	if event.type == FightEvent.ACTION_ENDED:
		return true
	return event.type == FightEvent.ACTION_PHASE and event.data.phase != "telegraph"


## Fight time since the start of the event's round, e.g. "R1 0:03.4".
static func time_label(event: FightEvent, round_seconds: int) -> String:
	var ticks_per_round: int = round_seconds * FightClock.TICKS_PER_SECOND
	var in_round: int = event.tick - (event.round_number - 1) * ticks_per_round
	var seconds: int = in_round / FightClock.TICKS_PER_SECOND
	var tenths: int = in_round % FightClock.TICKS_PER_SECOND
	return "R%d %d:%02d.%d" % [event.round_number, seconds / 60, seconds % 60, tenths]


static func line(event: FightEvent, sim: FightSim) -> String:
	var stamp: String = "[color=%s]%s  t%d[/color]  " % [DIM_COLOUR, time_label(event, sim.clock.round_seconds), event.tick]
	return stamp + _describe(event, sim)


static func _describe(event: FightEvent, sim: FightSim) -> String:
	var who: String = _fighter(event.actor, sim)
	match event.type:
		FightEvent.ACTION_PHASE:
			if event.data.phase == "telegraph":
				var why: String = String(event.data.get("why", ""))
				var reason: String = "  [color=%s](%s)[/color]" % [DIM_COLOUR, why] if why != "" else ""
				return "%s starts a %s%s" % [who, _action_name(event.data.action_id, sim), reason]
			return "[color=%s]%s %s → %s[/color]" % [DIM_COLOUR, who, _action_name(event.data.action_id, sim), event.data.phase]
		FightEvent.ACTION_ENDED:
			return "[color=%s]%s %s finished[/color]" % [DIM_COLOUR, who, _action_name(event.data.action_id, sim)]
		FightEvent.STRIKE_LANDED:
			var counter: String = "counter " if event.data.get("counter", false) else ""
			return "%s's %s%s [b]LANDS[/b] (%s, %d damage)%s" % [who, counter, _action_name(event.data.action_id, sim), event.data.target, event.data.damage, _odds(event)]
		FightEvent.STRIKE_MISSED:
			if event.data.has("reason"):
				return "%s's %s misses (%s)" % [who, _action_name(event.data.action_id, sim), event.data.reason]
			return "%s's %s misses%s" % [who, _action_name(event.data.action_id, sim), _odds(event)]
		FightEvent.RANGE_CHANGED:
			return "[color=%s]Range: %s[/color]" % [DIM_COLOUR, RANGE_NAMES.get(event.data.band, event.data.band)]
		FightEvent.POSITION_CHANGED:
			return "[b]%s's %s → %s[/b]%s" % [who, _action_name(event.data.action_id, sim), _position_name(event.data.position, sim), _roles(event, sim)]
		FightEvent.CAGE_CHANGED:
			return "[color=%s]%s %s[/color]" % [DIM_COLOUR, who, CAGE_NAMES.get(event.data.proximity, event.data.proximity)]
		FightEvent.ROCKED:
			return "[b]%s is ROCKED![/b]" % who
		FightEvent.KNOCKDOWN:
			return "[b]%s goes DOWN![/b]" % who
		FightEvent.GOT_UP:
			return "%s beats the count and gets back up" % who
		FightEvent.RECOVERED:
			return "[color=%s]%s has shaken it off[/color]" % [DIM_COLOUR, who]
		FightEvent.CALL_ANSWERED:
			var outcome: String = CALL_OUTCOMES.get(event.data.outcome, event.data.outcome)
			return "[color=%s]%s %s the %s call (%s)[/color]" % [DIM_COLOUR, who, outcome, _action_name(event.data.action_id, sim), event.data.reason]
		FightEvent.COMMAND_REJECTED:
			return "[color=%s]Command refused for %s: %s[/color]" % [FAIL_COLOUR, who, event.data.reason]
		FightEvent.ROUND_ENDED:
			return "[b]── End of round %d ──[/b]  judges: %s" % [event.round_number, _cards(event.data.get("cards", []))]
		FightEvent.FIGHT_ENDED:
			return "[b]── %s ──[/b]" % result_text(event, sim)
	return "%s %s %s" % [who, event.type, JSON.stringify(event.data)]


## One fighter's condition for the debug console, e.g.
## "Red stamina 41/100 · Boxing 60 → 55 (tired) · Speed 55 → 44 (tired, hurt)".
static func condition_line(f: FighterState) -> String:
	var parts: Array[String] = ["%s stamina %d/%d" % [f.name, roundi(f.stamina), roundi(f.max_stamina())]]
	if f.is_rocked():
		parts.append("ROCKED")
	if f.is_panicking():
		parts.append("PANICKING")
	if f.knockdowns > 0:
		parts.append("knocked down %d×" % f.knockdowns)
	for id in CONDITION_STATS:
		if not f.condition_reasons(id).is_empty() and roundi(f.effective_stat(id)) != f.stat(id):
			parts.append(f.describe_stat(id))
	for leaning in StyleLeanings.LEANINGS:
		if f.style.hint(leaning) != "":
			parts.append(f.style.hint(leaning))
	for trait_id in f.style.traits():
		parts.append(StyleLeanings.TRAIT_NAMES[trait_id])
	return " · ".join(parts)


## e.g. "Red wins by KO", "Blue wins by split decision (29-28, 28-29, 29-28)", "Draw (...)".
static func result_text(event: FightEvent, sim: FightSim) -> String:
	var result: String = event.data.result
	var how: String = RESULT_NAMES.get(result, result)
	var cards: String = " (%s)" % _cards(event.data.cards) if event.data.has("cards") else ""
	var winner: int = int(event.data.get("winner", -1))
	if winner < 0:
		return "%s%s" % [how.capitalize(), cards]
	return "%s wins by %s%s" % [_fighter(winner, sim), how, cards]


static func _cards(cards: Array) -> String:
	var out: Array[String] = []
	for c: Array in cards:
		out.append("%d-%d" % [c[0], c[1]])
	return ", ".join(out)


static func _odds(event: FightEvent) -> String:
	if not event.data.has("chance"):
		return ""
	var why: String = ""
	if event.data.has("odds"):
		why = " (%s)" % odds_reasons(event.data.odds)
	return " [color=%s]%d%%%s[/color]" % [DIM_COLOUR, roundi(event.data.chance * 100.0), why]


## Why the odds were what they were (OddsBreakdown.to_dict), e.g.
## "base 50 · stats +7 · counter +10 · ONE_LEG +35 · capped at 95".
static func odds_reasons(odds: Dictionary) -> String:
	var parts: Array[String] = ["base %d" % roundi(odds.base * 100.0), "stats %s" % _signed(odds.stat_gap)]
	for b: Dictionary in odds.bonuses:
		parts.append("%s %s" % [b.name, _signed(b.value)])
	if odds.has("missing"):
		parts.append("needs %s" % odds.missing)
	elif odds.get("clamped", false):
		parts.append("capped at %d" % roundi(odds.chance * 100.0))
	return " · ".join(parts)


static func _signed(fraction: float) -> String:
	var points: int = roundi(fraction * 100.0)
	return "+%d" % points if points >= 0 else "%d" % points


static func _fighter(index: int, sim: FightSim) -> String:
	if index < 0 or index >= sim.fighters.size():
		return "?" if index != FightEvent.NO_ACTOR else ""
	return "[color=%s]%s[/color]" % [FIGHTER_COLOURS[index], sim.fighters[index].name]


static func _position_name(id: String, sim: FightSim) -> String:
	return String(sim.positions.get_position(id).name) if sim.positions.has(id) else id


## " (Red on top)" when someone is on top, "" when both are neutral.
static func _roles(event: FightEvent, sim: FightSim) -> String:
	var roles: Array = event.data.get("roles", [])
	var top: int = roles.find("top")
	return " (%s on top)" % _fighter(top, sim) if top != -1 else ""


static func _action_name(id: String, sim: FightSim) -> String:
	return String(sim.actions.get_action(id).name) if sim.actions.has(id) else id
