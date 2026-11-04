class_name OpponentCamp
extends RefCounted
## The opponent's camp (docs/03 §13.8, D404): the man he's booked against prepares for him too.
##
##   his plan    his corner rolls one of the two or three plans his style sheet lists (style@1 `gameplan` and `gameplans`)
##   his rule    your favourite move (the one you threw most in your last MOVES_FIGHTS fights that a rule can answer):
##               a third of amateur opponents drill a rule against it, half of pros, and every title fight's. Only a
##               rule whose move he knows, drilled DRILLED_MIN–DRILLED_MAX%
##   his tank    most come in fresh; TIRED_CHANCE of them overtrained, with TANK_LOW–TANK_HIGH of their gas tank
##   seeing it   the fight night card shows it all; in fight week the camp's scouting box shows it too once you know
##               him SCOUTED_EARLY or better (Scouting.knowledge)
##
## Not in a tournament (one day, nobody prepared for him) or the tutorial's lesson fights before the gameplan opens.
## Pure and seeded: the same booking always gives the same camp. Every number is a first guess.

const RULE_CHANCE_AMATEUR: float = 1.0 / 3.0
const RULE_CHANCE_PRO: float = 0.5
const RULE_CHANCE_TITLE: float = 1.0
const DRILLED_MIN: float = 50.0
const DRILLED_MAX: float = 80.0
## Your favourite move is counted over your last this many fights (each fight's `moves`, docs/09 career@1).
const MOVES_FIGHTS: int = 3
const TIRED_CHANCE: float = 0.25
const TANK_LOW: float = 0.85
const TANK_HIGH: float = 0.95
## How well you must know him (0–1) to see his camp in fight week, before the fight night card.
const SCOUTED_EARLY: float = 0.6

static var _actions: ActionLibrary


## His camp for the booked fight: { plan: {approach, target, where}, rule: rule id or "", drilled: 0–100, move: your
## favourite move's action id or "", tank: 0–1 }. {} when there's nobody booked, in a tournament, or in a lesson fight
## before the gameplan opens.
static func of(c: Career) -> Dictionary:
	var him: Dictionary = c.booked_opponent()
	if him.is_empty() or c.booked.get("tournament") is Dictionary or not Tutorial.plan_open(Tutorial.lesson(c)):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.career_seed, String(him.get("id", "")), int(c.booked.get("week", 0)), "their camp"])
	# Every roll is made every time, in the same order, so one part changing never moves another.
	var plan_roll: float = rng.randf()
	var rule_roll: float = rng.randf()
	var pick_roll: float = rng.randf()
	var drill_roll: float = rng.randf()
	var tired_roll: float = rng.randf()
	var tank_roll: float = rng.randf()
	var plans: Array[Dictionary] = StyleLibrary.gameplans_of(him)
	var out: Dictionary = { "plan": {}, "rule": "", "drilled": 0.0, "move": favourite_move(c), "tank": 1.0 }
	if not plans.is_empty():
		out.plan = plans[mini(plans.size() - 1, floori(plan_roll * plans.size()))].duplicate()
	if out.move != "" and rule_roll < rule_chance(c):
		var options: Array[String] = answers_to(String(out.move), him)
		if not options.is_empty():
			out.rule = options[mini(options.size() - 1, floori(pick_roll * options.size()))]
			out.drilled = snappedf(lerpf(DRILLED_MIN, DRILLED_MAX, drill_roll), 1.0)
	if tired_roll < TIRED_CHANCE:
		out.tank = snappedf(lerpf(TANK_LOW, TANK_HIGH, tank_roll), 0.01)
	return out


## How likely the booked man is to drill a rule against your favourite move: every title fight's, half of pros, a third
## of amateurs.
static func rule_chance(c: Career) -> float:
	if String(c.booked.get("title", "")) != "":
		return RULE_CHANCE_TITLE
	return RULE_CHANCE_PRO if c.pro else RULE_CHANCE_AMATEUR


## The move you threw most in your last MOVES_FIGHTS fights that some rule answers ("" when there's none, as before
## your first fight). Ties go to the move's id, alphabetically.
static func favourite_move(c: Career) -> String:
	var counts: Dictionary = {}
	for f: Variant in c.fights.slice(maxi(0, c.fights.size() - MOVES_FIGHTS)):
		if not f is Dictionary or not f.get("moves") is Dictionary:
			continue
		for id: String in f.moves:
			counts[id] = int(counts.get(id, 0)) + int(f.moves[id])
	var best: String = ""
	var ids: Array = counts.keys()
	ids.sort()
	for id: String in ids:
		if int(counts[id]) > 0 and answerable(id) and (best == "" or int(counts[id]) > int(counts[best])):
			best = id
	return best


## Whether any rule answers move `action_id` when the other man starts it.
static func answerable(action_id: String) -> bool:
	for id: String in RuleLibrary.shared().ids():
		if RuleDrilling.answers(id, { "action": action_id }):
			return true
	return false


## The rules `profile` knows that answer move `action_id`, sorted by id.
static func answers_to(action_id: String, profile: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in RuleLibrary.shared().ids():
		if RuleDrilling.answers(id, { "action": action_id }) and RuleDrilling.knows_profile(profile, id):
			out.append(id)
	out.sort()
	return out


## Every move fighter `fighter` started in a fight (its telegraph), by action id: a fight's `moves` on his record.
static func moves_of(sim: FightSim, fighter: int) -> Dictionary:
	var out: Dictionary = {}
	for e: FightEvent in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.actor == fighter and String(e.data.get("phase", "")) == "telegraph":
			var id: String = String(e.data.get("action_id", ""))
			out[id] = int(out.get(id, 0)) + 1
	return out


## Whether you see his camp before fight night: it's fight week and you know him SCOUTED_EARLY or better.
static func known_early(c: Career) -> bool:
	return not c.booked.is_empty() and c.camp_weeks_left() <= 1 \
		and Scouting.knowledge(c, String(c.booked.get("opponent", ""))) >= SCOUTED_EARLY


## His camp in three lines (the fight night card and the scouting box): his plan, his rule, his tank.
static func lines(camp: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if camp.is_empty():
		return out
	out.append("His plan: %s." % Gameplan.describe(camp.get("plan", {})))
	if String(camp.get("rule", "")) != "":
		out.append("He's drilled %s (%d%%) for your %s." % [RuleDrilling.rule_name(String(camp.rule)),
			roundi(float(camp.drilled)), move_name(String(camp.move))])
	elif String(camp.get("move", "")) != "":
		out.append("Nothing drilled for your %s." % move_name(String(camp.move)))
	else:
		out.append("He has no film of you to drill against yet.")
	var tank: float = float(camp.get("tank", 1.0))
	out.append("He comes in fresh." if tank >= 0.995 else "He overtrained: %d%% of his gas tank." % roundi(100.0 * tank))
	return out


## A move's name, lower case ("leg kick").
static func move_name(action_id: String) -> String:
	if _actions == null:
		_actions = ActionLibrary.load_dir()
	return String(_actions.get_action(action_id).get("name", action_id)).to_lower() if _actions.has(action_id) else action_id.replace("_", " ")
