extends GutTest
## Damage on the body (D375-D378): cuts over the eyes opened by what hit him (elbows most), the trickle growing and the
## cutman closing it between rounds, blood on the other man's gloves and the canvas, an eye swelling on the side he's
## hit, his ribs and each leg marked by their own damage, and sweat and a flush as he tires. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _fighter() -> FighterState:
	return FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions).fighters[0]


## How many of `fights` fresh men (each his own seed) a run of `shots` clean `action`s to a hurt head cuts.
func _cut_count(action: String, fights: int = 400, shots: int = 20) -> int:
	var cuts: int = 0
	for s in fights:
		var marks := BodyMarks.new(s)
		for n in shots:
			if marks.landed(action, "head", 12.0, false, 0, 0.4):
				cuts += 1
				break
	return cuts


func test_a_shot_to_the_body_or_legs_never_cuts_him_or_counts_toward_his_eyes() -> void:
	var marks := BodyMarks.new(1)
	for n in 500:
		assert_false(marks.landed("elbow", "body", 18.0, false, 0, 0.9))
		assert_false(marks.landed("low_kick", "legs", 18.0, false, 0, 0.9))
	assert_eq(marks.head_hits, [0.0, 0.0] as Array[float])
	assert_eq(marks.cut, [false, false] as Array[bool])


func test_no_cut_opens_before_his_head_is_hurt() -> void:
	var marks := BodyMarks.new(1)
	for n in 2000:
		assert_false(marks.landed("elbow", "head", 18.0, false, 0, BodyMarks.CUT_FROM_HURT - 0.01))


func test_elbows_cut_far_more_often_than_punches_and_jabs_least() -> void:
	var elbows: int = _cut_count("elbow")
	var crosses: int = _cut_count("cross")
	var jabs: int = _cut_count("jab")
	assert_gt(elbows, crosses * 3, "elbows %d against crosses %d" % [elbows, crosses])
	assert_gt(crosses, jabs, "crosses %d against jabs %d" % [crosses, jabs])


func test_a_covered_shot_opens_no_cut_but_still_counts_toward_the_swelling() -> void:
	var marks := BodyMarks.new(1)
	for n in 2000:
		assert_false(marks.landed("elbow", "head", 18.0, true, 1, 0.9))
	assert_almost_eq(marks.head_hits[1], 2000 * 18.0, 0.1)


func test_the_same_fight_opens_the_same_cuts() -> void:
	var first := BodyMarks.new(77)
	var second := BodyMarks.new(77)
	for n in 300:
		assert_eq(first.landed("hook", "head", 14.0, false, n % 2, 0.5), second.landed("hook", "head", 14.0, false, n % 2, 0.5))
	assert_eq(first.cut, second.cut)


func test_a_left_hand_lands_on_the_right_side_of_his_face() -> void:
	assert_eq(BodyMarks.side_hit(0), 1, "the thrower's left lands on his right")
	assert_eq(BodyMarks.side_hit(1), 0, "the thrower's right lands on his left")


func test_a_hook_marks_the_side_it_lands_on_and_a_straight_shot_spreads_over_both() -> void:
	var hooked := BodyMarks.new(1)
	hooked.landed("hook", "head", 10.0, true, 1, 0.0)
	assert_eq(hooked.head_hits, [0.0, 10.0] as Array[float])
	var jabbed := BodyMarks.new(1)
	jabbed.landed("jab", "head", 10.0, true, 1, 0.0)
	assert_almost_eq(jabbed.head_hits[1], 10.0 * BodyMarks.STRAIGHT_SHARE, 0.001)
	assert_almost_eq(jabbed.head_hits[0], 10.0 * (1.0 - BodyMarks.STRAIGHT_SHARE), 0.001)


func test_a_cut_trickles_further_when_hit_and_on_its_own_and_the_cutman_closes_it_between_rounds() -> void:
	var f := _fighter()
	f.damage["head"] = 200
	var marks := BodyMarks.new(1)
	marks.cut[0] = true
	marks.bleed[0] = BodyMarks.BLEED_START
	assert_true(marks.bleeding(0))
	assert_false(marks.bleeding(1), "no cut on the other side")
	marks.landed("hook", "head", 12.0, false, 0, f.hurt("head"))
	assert_almost_eq(marks.bleed[0], BodyMarks.BLEED_START + BodyMarks.BLEED_PER_HIT, 0.001, "a shot on it")
	var before: float = marks.bleed[0]
	for n in 10:
		marks.update(f, 1.0, 2.0)
	assert_gt(marks.bleed[0], before, "running on its own")
	assert_lte(marks.bleed[0], lerpf(BodyMarks.BLEED_DRIFT_TO.x, BodyMarks.BLEED_DRIFT_TO.y, f.hurt("head")) + 0.001,
		"only so far on its own")
	var open: float = marks.bleed[0]
	marks.cornered()
	assert_almost_eq(marks.bleed[0], open * BodyMarks.BLEED_AFTER_CORNER, 0.001, "the cutman")
	assert_true(marks.cut[0], "the cut is still there")


func test_hitting_a_bleeding_cut_bloodies_his_gloves_up_to_full() -> void:
	var marks := BodyMarks.new(1)
	marks.blooded()
	assert_almost_eq(marks.glove_blood, BodyMarks.GLOVE_BLOOD_PER_HIT, 0.001)
	for n in 20:
		marks.blooded()
	assert_eq(marks.glove_blood, 1.0)


func test_an_eye_swells_on_the_side_he_is_hit_as_his_head_is_hurt() -> void:
	var f := _fighter()
	var marks := BodyMarks.new(1)
	marks.landed("hook", "head", 100.0, true, 0, 0.0)
	marks.update(f, 1.0, 1.0)
	assert_eq(marks.swell, [0.0, 0.0] as Array[float], "a fresh head shows nothing yet")
	f.damage["head"] = 400
	marks.update(f, 1.0, 1.0)
	assert_gt(marks.swell[0], 0.3, "the eye he was hit over")
	assert_eq(marks.swell[1], 0.0, "not the other")


func test_his_ribs_and_each_leg_are_marked_by_their_own_damage() -> void:
	var f := _fighter()
	var marks := BodyMarks.new(1)
	marks.update(f, 1.0, 1.0)
	assert_eq(marks.legs, [0.0, 0.0] as Array[float])
	assert_eq(marks.body, 0.0)
	f.leg_damage[FighterState.LEFT_LEG] = 300
	marks.update(f, 1.0, 1.0)
	assert_gt(marks.legs[FighterState.LEFT_LEG], 0.2, "the kicked leg")
	assert_eq(marks.legs[FighterState.RIGHT_LEG], 0.0, "not the other")
	assert_eq(marks.body, 0.0, "nor his ribs")
	f.damage["body"] = 300
	marks.update(f, 1.0, 1.0)
	assert_gt(marks.body, 0.2, "his ribs")


func test_sweat_and_the_flush_come_on_over_seconds_as_he_tires_not_with_every_burst() -> void:
	var f := _fighter()
	var marks := BodyMarks.new(1)
	marks.update(f, 1.0, 0.5)
	assert_eq(marks.flush, 0.0, "fresh")
	assert_lt(marks.sweat, 0.05, "barely damp")
	f.stamina = 0.0
	marks.update(f, 1.0, 0.5)
	assert_lt(marks.flush, 0.2, "one empty second doesn't flush him")
	for n in 60:
		marks.update(f, 1.0, 1.5)
	assert_gt(marks.flush, 0.9, "a minute on empty does")
	assert_gt(marks.sweat, 0.5, "and soaks him")
	f.stamina = f.max_stamina()
	marks.update(f, 1.0, 1.5)
	assert_gt(marks.flush, 0.6, "getting his wind back takes a while")
	assert_gt(marks.sweat, 0.5, "the sweat stays on him")


func test_a_watched_fight_draws_the_marks_on_both_bodies_and_spots_blood_up_to_a_limit() -> void:
	var sim := FightSim.new(3, _roster.make_pair("dirty_boxer", "muay_thai"), _actions)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	view.driver._snap()
	for n in 10:
		view._process(0.1)
	assert_eq(view.marks.size(), 2, "one set of marks a man")
	for figure in view.figures:
		var skin: ShaderMaterial = figure.body.find_children("*", "MeshInstance3D", true, false)[0].material_override
		assert_eq(skin.get_shader_parameter("has_damage"), true, "drawn on his body")
	view.marks[1].cut[0] = true
	view.marks[1].bleed[0] = 0.5
	view.marks[1].swell[0] = 0.7
	view.marks[1].head_hits[0] = 500.0
	sim.fighters[1].damage["head"] = 400
	view._process(0.1)
	var skin: ShaderMaterial = view.figures[1].body.find_children("*", "MeshInstance3D", true, false)[0].material_override
	assert_gt(Vector2(skin.get_shader_parameter("swell")).x, 0.0, "his left eye swollen")
	assert_eq(Vector2(skin.get_shader_parameter("cut")).x, 1.0, "his left brow cut")
	for n in 100:
		view._drop_blood(1)
	assert_eq(view._blood_spots.size(), ArenaView.BLOOD_SPOTS_MAX, "the canvas only takes so much")


func test_a_clean_shot_on_a_bleeding_cut_bloodies_the_hitter_and_the_canvas() -> void:
	var sim := FightSim.new(3, _roster.make_pair("dirty_boxer", "muay_thai"), _actions)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	view.driver._snap()
	view._process(0.1)
	for side in 2:
		view.marks[1].cut[side] = true
		view.marks[1].bleed[side] = 0.5
	view._mark_hit(0, "hook", {"target": "head", "damage": 12.0}, false)
	assert_gt(view.marks[0].glove_blood, 0.0, "on the gloves that hit it")
	assert_gt(view._blood_spots.size(), 0, "and on the canvas")
	var spots: int = view._blood_spots.size()
	view._mark_hit(0, "hook", {"target": "head", "damage": 12.0}, true)
	assert_eq(view._blood_spots.size(), spots, "a shot on his gloves doesn't")
