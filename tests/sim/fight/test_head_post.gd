extends GutTest
## The head post (docs/01 §47, D490–D496): a hand on the other man's head against the fence, on the feet or in the
## clinch, what it does to both of them, the ways off it, the AI who use it, and the *Post and dig!* call.

const SEED: int = 20261105
## Stats that win (or lose) every contest the post and the swat have.
const BEST := { "boxing": 100, "strength": 100, "striking_defense": 100, "speed": 100, "clinch_control": 100 }
const WORST := { "boxing": 0, "strength": 0, "striking_defense": 0, "speed": 0, "clinch_control": 0 }
const MOVES: Array[String] = ["head_post", "swat_post", "jab", "cross", "hook", "rear_body_hook", "body_hook", "short_body_hook"]

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _sim(red_stats: Dictionary = {}, blue_stats: Dictionary = {}) -> FightSim:
	return FightSim.new(SEED, [FighterState.new("Red", red_stats, MOVES, 0.0), FighterState.new("Blue", blue_stats, MOVES, 0.0)], _actions, 1, 300)


## Standing in the pocket, Blue's back on the fence (the panel facing +x), Red in front of him.
func _on_the_fence(red_stats: Dictionary = {}, blue_stats: Dictionary = {}) -> FightSim:
	var sim: FightSim = _sim(red_stats, blue_stats)
	sim.fighters[0].pos = Vector2(2.8, 0.0)
	sim.fighters[1].pos = Vector2(4.0, 0.0)
	return sim


## Tied up in the clinch with Blue held on the fence.
func _clinched_on_the_fence(red_stats: Dictionary = {}, blue_stats: Dictionary = {}) -> FightSim:
	var sim: FightSim = _sim(red_stats, blue_stats)
	sim.fighters[0].pos = Vector2(3.0, 0.0)
	sim.fighters[1].pos = Vector2(4.0, 0.0)
	assert_true(sim.apply_transition(0, "clinch_entry"))
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)))


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


func _bonus(b: OddsBreakdown, bonus_name: String) -> float:
	for x: Dictionary in b.bonuses:
		if x.name == bonus_name:
			return float(x.value)
	return 0.0


# --- Getting it on -------------------------------------------------------------------------------

func test_a_post_on_a_man_with_his_back_on_the_fence_puts_a_hand_on_his_head() -> void:
	var sim: FightSim = _on_the_fence(BEST, WORST)
	_queue(sim, 0, 0, "head_post")
	_ticks(sim, 8)
	assert_true(sim.posting(0), "Red has his hand on Blue's head")
	assert_true(sim.posted(1))
	assert_true(sim.active_flags(0).has(FightSim.POSTING))
	assert_true(sim.active_flags(1).has(FightSim.HEAD_POSTED))
	assert_eq(sim.fighters[0].posts_won, 1)


func test_there_is_no_post_on_a_man_in_the_middle_of_the_cage() -> void:
	var sim: FightSim = _sim(BEST, WORST)
	sim.fighters[0].pos = Vector2(-0.4, 0.0)
	sim.fighters[1].pos = Vector2(0.4, 0.0)
	_queue(sim, 0, 0, "head_post")
	_ticks(sim, 8)
	assert_false(sim.posting(0))
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
	assert_eq(stopped.size(), 1)
	assert_eq(String(stopped[0].data.reason), "not on the fence")


func test_in_the_clinch_he_posts_on_the_man_held_on_the_fence_but_not_from_it() -> void:
	var sim: FightSim = _clinched_on_the_fence(BEST, WORST)
	_queue(sim, 0, 0, "head_post")
	_ticks(sim, 8)
	assert_true(sim.posting(0), "Red posts on the man he holds on the fence")
	var other: FightSim = _clinched_on_the_fence(WORST, BEST)
	_queue(other, 0, 1, "head_post")
	_ticks(other, 8)
	assert_false(other.posting(1), "the man held on the fence can't post on the man holding him")


# --- What it does --------------------------------------------------------------------------------

func test_his_body_shots_find_the_man_under_it_and_the_hand_on_the_head_cannot_jab() -> void:
	var sim: FightSim = _on_the_fence()
	sim.set_post(0)
	assert_almost_eq(_bonus(sim.odds_breakdown(0, "rear_body_hook"), FightSim.HEAD_POSTED), 0.25, 0.001)
	assert_almost_eq(_bonus(sim.odds_breakdown(0, "jab"), "own " + FightSim.POSTING), -0.30, 0.001)
	assert_almost_eq(_bonus(sim.odds_breakdown(0, "body_hook"), "own " + FightSim.POSTING), -0.30, 0.001, "the lead hook's hand is on his head too")


func test_the_man_under_it_is_smothered_but_his_hook_comes_over_the_arm() -> void:
	var sim: FightSim = _on_the_fence()
	sim.set_post(0)
	for id: String in ["jab", "cross", "rear_body_hook"]:
		assert_lt(_bonus(sim.odds_breakdown(1, id), "own " + FightSim.HEAD_POSTED), 0.0, "%s is smothered" % id)
	assert_gt(_bonus(sim.odds_breakdown(1, "hook"), "own " + FightSim.HEAD_POSTED), 0.0, "the hook over the post")
	var clinch: FightSim = _clinched_on_the_fence()
	clinch.set_post(0)
	assert_lt(_bonus(clinch.odds_breakdown(1, "spin_off"), "own " + FightSim.HEAD_POSTED), 0.0, "harder to spin off the fence")
	assert_almost_eq(_bonus(clinch.odds_breakdown(0, "short_body_hook"), FightSim.HEAD_POSTED), 0.20, 0.001)


func test_his_feet_are_held_while_he_is_posted() -> void:
	var free: FightSim = _on_the_fence()
	var held: FightSim = _on_the_fence()
	held.set_post(0, 100)
	for sim: FightSim in [free, held]:
		sim.fighters[1].pos = Vector2(3.9, 0.0)
		sim._move(1, 1.2, 1.0, 0.0, 1)
	var free_step: float = free.fighters[1].pos.distance_to(Vector2(3.9, 0.0))
	var held_step: float = held.fighters[1].pos.distance_to(Vector2(3.9, 0.0))
	assert_almost_eq(held_step, free_step * FightSim.POSTED_FEET, 0.002, "he circles along the fence at %d%% of his step" % roundi(FightSim.POSTED_FEET * 100.0))


# --- Getting it off ------------------------------------------------------------------------------

func test_it_comes_off_on_its_own_after_four_seconds() -> void:
	var sim: FightSim = _on_the_fence()
	sim.set_post(0, 40)
	_ticks(sim, 39)
	assert_true(sim.posting(0))
	_ticks(sim, 2)
	assert_false(sim.posting(0))
	var ended: Array[FightEvent] = _events(sim, FightEvent.POST_ENDED, 0)
	assert_eq(ended.size(), 1)
	assert_eq(String(ended[0].data.how), FightSim.POST_TIME)


func test_he_can_swat_it_off() -> void:
	var sim: FightSim = _on_the_fence(WORST, BEST)
	sim.set_post(0, 100)
	_queue(sim, 0, 1, "swat_post")
	_ticks(sim, 6)
	assert_false(sim.posting(0), "the hand is off his head")
	assert_eq(sim.fighters[1].swats_won, 1)
	assert_eq(int(sim.fighters[0].post_ends.get(FightSim.POST_SWATTED, 0)), 1)


func test_there_is_nothing_to_swat_without_a_post() -> void:
	var sim: FightSim = _on_the_fence(WORST, BEST)
	_queue(sim, 0, 1, "swat_post")
	_ticks(sim, 6)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 1)
	assert_eq(stopped.size(), 1)
	assert_eq(String(stopped[0].data.reason), "no post to swat")


func test_circling_off_the_fence_or_tying_him_up_takes_it_off() -> void:
	var sim: FightSim = _on_the_fence()
	sim.set_post(0, 100)
	sim.fighters[1].pos = Vector2(2.6, 1.6)  # Off the fence.
	_ticks(sim, 1)
	assert_false(sim.posting(0))
	assert_eq(int(sim.fighters[0].post_ends.get(FightSim.POST_CIRCLED, 0)), 1)
	var tied: FightSim = _on_the_fence()
	tied.set_post(0, 100)
	assert_true(tied.apply_transition(1, "clinch_entry"))
	assert_false(tied.posting(0))
	assert_eq(int(tied.fighters[0].post_ends.get(FightSim.POST_TIED, 0)), 1)


# --- Who does it, and the call ---------------------------------------------------------------------

func _fights(red: String, blue: String, n: int) -> Array[FightSim]:
	var roster: FighterLibrary = FighterLibrary.load_dir()
	var out: Array[FightSim] = []
	for k in n:
		var sim := FightSim.new(SEED + k, roster.make_pair(red, blue), _actions)
		sim.run_to_end()
		out.append(sim)
	return out


func test_the_volume_striker_posts_a_man_on_the_fence_now_and_then_and_the_boxer_never_does() -> void:
	var posts: int = 0
	var boxer_posts: int = 0
	var swats: int = 0
	for sim: FightSim in _fights("volume_striker", "boxer", 6):
		posts += sim.fighters[0].posts_won
		boxer_posts += sim.fighters[1].posts_tried
		swats += sim.fighters[1].swats_tried
	assert_gt(posts, 6, "a few times a fight")
	assert_eq(boxer_posts, 0, "the Boxer doesn't know it")
	assert_gt(swats, 0, "the Boxer swats it off")


func test_after_a_post_comes_off_he_waits_before_the_next() -> void:
	for sim: FightSim in _fights("volume_striker", "boxer", 4):
		var off_at: int = -100000
		for e in sim.events:
			if e.actor != 0:
				continue
			if e.type == FightEvent.POST_ENDED:
				off_at = e.tick
			elif e.type == FightEvent.ACTION_PHASE and String(e.data.action_id) == FightSim.HEAD_POST and String(e.data.phase) == "telegraph" \
					and String(e.data.get("by", "")) == DecisionLayer.AI:
				assert_gte(e.tick - off_at, FighterAI.POST_AGAIN_TICKS, "the next post waits (tick %d)" % e.tick)


func test_post_and_dig_is_on_b_for_a_fighter_who_knows_the_head_post() -> void:
	var calls: CallLibrary = CallLibrary.load_dir()
	var call: Dictionary = calls.get_call("post_and_dig")
	assert_eq(String(call.hotkey), "B")
	assert_eq(String(call.requires_technique), "head_post")
	assert_gt(float(call.focus.weights.head_post), 1.0, "he looks for the post")
	assert_gt(float(call.focus.weights.rear_body_hook), 1.0, "and digs to the body off it")
