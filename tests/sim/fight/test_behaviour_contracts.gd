extends GutTest
## Behaviour contracts (D254, docs/01 §2.6): things that must hold in every fight, whoever wins it.
## The golden fights catch a change; these catch a wrong one. Each fight below is played once, with
## the AI corner calling for both fighters, and watched as it goes: who started what, from where, and
## why. The pairings cover every style in data/fighters, the PRIDE and amateur rules, and outside
## fighters walked down by men who cut the cage off.

## [red, blue, ruleset, seed]
const FIGHTS: Array = [
	["kicker", "boxer", "pro", 1], ["wrestler", "boxer", "pro", 1], ["bjj", "wrestler", "pro", 1],
	["judoka", "kicker", "pro", 1], ["muay_thai", "wrestler", "pro", 1], ["sambo", "bjj", "pro", 1],
	["counter_striker", "pressure_wrestler", "pro", 1], ["gnp_wrestler", "brawler", "pride", 1],
	["dirty_boxer", "karate", "amateur_adult", 1], ["leg_kicker", "sprawl_brawl", "pro", 1],
	["kicker", "pressure_wrestler", "pro", 2], ["karate", "brawler", "pro", 2], ["counter_striker", "boxer", "pro", 2],
]
## Out of range when it landed: the opponent stepped out of it while it was on its way. Allowed, but rare.
const OUT_OF_RANGE_UNDER: float = 0.15
## The share of the AI's own moves that can be defences (sprawls, checks, slips, covering up).
const DEFENCE_UNDER: float = 0.25
## An outside fighter cut off onto the fence gets back to the middle at least this often.
const ESCAPES_AT_LEAST: float = 0.8

var _actions: ActionLibrary
var _played: Array[Dictionary] = []


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	var roster := FighterLibrary.load_dir()
	for fight: Array in FIGHTS:
		var sim: FightSim = FightSummary.setup(fight[3], roster, _actions, fight[0], fight[1], fight[2], 300, [Corner.AI, Corner.AI])
		var seen := {
			"name": "%s vs %s (%s, seed %d)" % fight, "sim": sim,
			"fresh_reaction": [sim.fighters[0].reaction_ticks(), sim.fighters[1].reaction_ticks()],
			"started": [{}, {}], "by": ["", ""], "moves": 0, "illegal": [], "too_soon": [], "answers": 0,
			"ai_strikes": [0, 0], "out_of_range": [0, 0], "ai_moves": [0, 0],
		}
		sim.event_emitted.connect(_watch.bind(seen))
		sim.run_to_end()
		_played.append(seen)


## Watches one fight as it goes (the position and roles are only known at the time).
func _watch(e: FightEvent, seen: Dictionary) -> void:
	var sim: FightSim = seen.sim
	if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph":
		var i: int = e.actor
		var action: Dictionary = _actions.get_action(e.data.action_id)
		var by: String = e.data.get("by", "")
		seen.moves += 1
		seen.by[i] = by
		if not action.positions.has(sim.situation.position) or not ActionLibrary.allows_role(action, sim.role(i)) \
				or not sim.ruleset.allows_action(action):
			seen.illegal.append("%s at %d from %s as %s" % [action.id, e.tick, sim.situation.position, sim.role(i)])
		if by == DecisionLayer.AI:
			seen.ai_moves[i] += 1
			if action.category == FighterAI.STRIKE:
				seen.ai_strikes[i] += 1
			if action.category == FighterAI.DEFENSE and action.has("defense") and not action.defense.has("head_share"):
				# A sprawl, check or slip answers the move he read: he can't have started it before he could see it.
				var theirs: Dictionary = seen.started[1 - i]
				if not theirs.is_empty():
					seen.answers += 1
					var seen_late: int = 1 if sim.first_at(theirs.tick) == i else 0  # Started after his turn.
					var earliest: int = theirs.tick + seen_late + seen.fresh_reaction[i]
					if e.tick < earliest:
						seen.too_soon.append("%s at %d against %s started at %d (not before %d)" % [action.id, e.tick, theirs.id, theirs.tick, earliest])
		seen.started[i] = { "tick": e.tick, "id": action.id }
	elif e.type == FightEvent.STRIKE_MISSED and e.data.get("reason", "") == "out of range" and seen.by[e.actor] == DecisionLayer.AI:
		seen.out_of_range[e.actor] += 1


func test_no_fighter_answers_a_move_before_he_could_have_seen_it() -> void:
	var answers: int = 0
	for p: Dictionary in _played:
		answers += p.answers
		assert_eq(p.too_soon, [], "%s: answered before his reaction time" % p.name)
	assert_gt(answers, 50, "there were sprawls, checks and slips to look at")


func test_a_stuffed_shot_never_counts_as_a_takedown() -> void:
	var landed: int = 0
	for p: Dictionary in _played:
		var sim: FightSim = p.sim
		var on_top: Array[int] = [0, 0]
		for e in sim.events:
			# A takedown that worked puts the man who shot it on top (a failed one can put him underneath).
			if e.type == FightEvent.POSITION_CHANGED and not e.data.get("failed", false) and _actions.has(e.data.action_id) \
					and _actions.get_action(e.data.action_id).category == FighterAI.TAKEDOWN and e.data.roles[e.actor] == PositionLibrary.TOP:
				on_top[e.actor] += 1
		for i in 2:
			assert_eq(sim.fighters[i].takedowns_landed, on_top[i], "%s: %s's takedowns are the ones that put him on top" % [p.name, FightSummary.SIDES[i]])
			assert_lte(sim.fighters[i].takedowns_landed, sim.fighters[i].takedowns_tried, "%s: no more takedowns than shots" % p.name)
			landed += on_top[i]
	assert_gt(landed, 20, "there were takedowns to count")


func test_every_move_a_fighter_starts_is_legal_where_he_is() -> void:
	var moves: int = 0
	for p: Dictionary in _played:
		moves += p.moves
		assert_eq(p.illegal, [], "%s: a move that isn't allowed from there (position, role or rules)" % p.name)
	assert_gt(moves, 2000)


func test_nearly_every_strike_the_ai_picks_is_still_in_range_when_it_lands() -> void:
	for p: Dictionary in _played:
		for i in 2:
			if p.ai_strikes[i] < 30:
				continue  # Too few to judge (a grappler who hardly strikes).
			var share: float = float(p.out_of_range[i]) / p.ai_strikes[i]
			assert_lt(share, OUT_OF_RANGE_UNDER, "%s: %s's strikes out of range %d of %d" % [p.name, FightSummary.SIDES[i], p.out_of_range[i], p.ai_strikes[i]])


func test_every_move_the_ai_picks_says_which_part_of_it_chose_it() -> void:
	for p: Dictionary in _played:
		var sim: FightSim = p.sim
		for i in 2:
			var parts: int = 0
			for part: String in sim.fighters[i].ai_parts:
				assert_has(FighterAI.PARTS, part, "%s: a part the harness doesn't report" % p.name)
				parts += sim.fighters[i].ai_parts[part]
			assert_eq(parts, p.ai_moves[i], "%s: %s's own moves, each counted once by part" % [p.name, FightSummary.SIDES[i]])


func test_defences_never_crowd_out_the_rest_of_the_ai() -> void:
	for p: Dictionary in _played:
		var sim: FightSim = p.sim
		for i in 2:
			var defences: int = sim.fighters[i].ai_parts.get(FighterAI.PART_DEFENCE, 0)
			if p.ai_moves[i] < 50:
				continue
			assert_lt(float(defences) / p.ai_moves[i], DEFENCE_UNDER, "%s: %s defends %d of his %d moves" % [p.name, FightSummary.SIDES[i], defences, p.ai_moves[i]])
	# The strikers still throw their combinations with all those reads and defences going on.
	var striking: Dictionary = _played[0]
	for i in 2:
		assert_gt(striking.sim.fighters[i].combos_thrown, 2, "%s: %s's combinations" % [striking.name, FightSummary.SIDES[i]])
		assert_gt(striking.sim.fighters[i].ai_parts.get(FighterAI.PART_COMBINATION, 0), 0)


func test_an_outside_fighter_cut_off_onto_the_fence_gets_back_to_the_middle() -> void:
	# Outside fighters (Range under 0) circle out, reverse and burst (D107, D233, D234); the others
	# plant their feet and fight when they're shut in, so they aren't held to this.
	var trapped: int = 0
	var escaped: int = 0
	for p: Dictionary in _played:
		var sim: FightSim = p.sim
		for i in 2:
			if sim.fighters[i].style.value(StyleLeanings.RANGE) < 0.0:
				trapped += sim.cut_offs[1 - i]
				escaped += sim.cage_escapes[i]
	assert_gt(trapped, 40, "outside fighters got cut off")
	assert_gte(float(escaped) / trapped, ESCAPES_AT_LEAST, "got back to the middle %d of %d times" % [escaped, trapped])
