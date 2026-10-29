extends GutTest
## Mitt work (sim/world/mitt_work.gd, docs/02 §3.9, D137): the coach's calls on a beat,
## the timing windows, what a drill scores and how it gets harder.


## Hits every note `offset` seconds off the beat with the right key.
func _play_all(drill: MittWork, offset: float) -> void:
	for note in drill.notes:
		drill.press(String(note.key), float(note.t) + offset)


func test_a_round_lasts_about_a_minute_after_the_count_in() -> void:
	var drill := MittWork.new(50.0, 0.0, 1)
	var hitting: float = drill.length() - MittWork.COUNT_IN_BEATS * drill.beat
	assert_between(hitting, 58.0, 70.0)
	assert_eq(drill.calls[0].t, MittWork.COUNT_IN_BEATS * drill.beat, "four beats to get ready")


func test_each_call_is_hit_one_key_a_beat_after_the_coach_shouts_it() -> void:
	var drill := MittWork.new(70.0, 0.0, 2)
	for c in drill.calls:
		var keys: PackedStringArray = String(c.text).split("-")
		for i in keys.size():
			var note: Dictionary = drill.notes[int(c.first) + i]
			assert_eq(note.key, keys[i])
			assert_almost_eq(float(note.t), float(c.t) + (i + 1) * drill.beat, 0.0001)


func test_the_same_seed_gives_the_same_round() -> void:
	assert_eq(MittWork.new(60.0, 0.0, 9).calls, MittWork.new(60.0, 0.0, 9).calls)


func test_better_boxers_get_a_faster_tempo_and_longer_combinations() -> void:
	var novice := MittWork.new(25.0, 0.0, 3)
	var pro := MittWork.new(85.0, 0.0, 3)
	assert_gt(pro.tempo, novice.tempo)
	assert_false(novice.pool().has("1-2-3-2"))
	assert_true(pro.pool().has("1-2-3-roll-3-2"))
	var longest := func(r: MittWork) -> int:
		var most: int = 0
		for c in r.calls:
			most = maxi(most, int(c.count))
		return most
	assert_gt(longest.call(pro), longest.call(novice))


func test_a_perfect_round_scores_the_top_quality_and_a_lazy_one_the_bottom() -> void:
	var perfect := MittWork.new(50.0, 0.0, 4)
	_play_all(perfect, 0.01)
	assert_eq(perfect.counts[MittWork.PERFECT], perfect.notes.size())
	assert_almost_eq(perfect.quality(), TrainingCamp.PLAYED_MAX, 0.0001)
	var lazy := MittWork.new(50.0, 0.0, 4)
	lazy.miss_late(lazy.length() + 1.0)
	assert_eq(lazy.counts[MittWork.MISS], lazy.notes.size())
	assert_almost_eq(lazy.quality(), TrainingCamp.PLAYED_MIN, 0.0001, "bad play still gets 0.8")


func test_a_little_late_is_good_and_too_late_misses() -> void:
	var drill := MittWork.new(50.0, 0.0, 5)
	var first: Dictionary = drill.notes[0]
	assert_eq(drill.press(String(first.key), float(first.t) + 0.1).result, MittWork.GOOD)
	var second: Dictionary = drill.notes[1]
	assert_eq(drill.press(String(second.key), float(second.t) + 0.3).result, "stray", "nothing in the window")
	drill.miss_late(float(second.t) + 0.3)
	assert_eq(drill.notes[1].result, MittWork.MISS)


func test_the_wrong_punch_misses_the_note() -> void:
	var drill := MittWork.new(50.0, 0.0, 6)
	var note: Dictionary = drill.notes[0]
	var wrong: String = "slip" if note.key != "slip" else "1"
	assert_eq(drill.press(wrong, float(note.t)).result, MittWork.MISS)
	assert_eq(drill.press(String(note.key), float(note.t)).result, "stray", "that note is gone")


func test_swinging_wildly_costs_accuracy() -> void:
	var clean := MittWork.new(50.0, 0.0, 7)
	var wild := MittWork.new(50.0, 0.0, 7)
	_play_all(clean, 0.0)
	_play_all(wild, 0.0)
	for i in 10:
		wild.press("1", 0.1 * i)  # During the count-in: nothing to hit.
	assert_lt(wild.accuracy(), clean.accuracy())


func test_a_tired_fighter_has_tighter_timing() -> void:
	var fresh := MittWork.new(50.0, 30.0, 8)
	var tired := MittWork.new(50.0, 100.0, 8)
	assert_almost_eq(fresh.good_window(), MittWork.GOOD_WINDOW, 0.0001, "no change under fatigue 40")
	assert_almost_eq(tired.good_window(), MittWork.GOOD_WINDOW * MittWork.TIRED_FLOOR, 0.0001)
	var note: Dictionary = tired.notes[0]
	assert_eq(tired.press(String(note.key), float(note.t) + 0.1).result, "stray", "0.1 s late is too late when tired")


func test_the_call_on_screen_follows_the_round() -> void:
	var drill := MittWork.new(50.0, 0.0, 10)
	assert_true(drill.call_at(0.0).is_empty(), "nothing called in the count-in")
	var first: Dictionary = drill.calls[0]
	assert_eq(drill.call_at(float(first.t) + 0.01).text, first.text)


func test_the_quality_counts_in_the_camp_as_a_played_session() -> void:
	var library := TrainingLibrary.shared()
	var camp := TrainingCamp.new(FighterLibrary.load_dir().profile("boxer"), 1)
	var played := TrainingCamp.new(FighterLibrary.load_dir().profile("boxer"), 1)
	var plan: Dictionary = library.plan("striker")
	var slot: int = -1
	for i in TrainingCamp.DAYS * TrainingCamp.SLOTS_PER_DAY:
		if plan.days[i / 2][i % 2] == "boxing_drill":
			slot = i
			break
	assert_gt(slot, -1, "the striker week has Boxing drills")
	var drill := MittWork.new(played.stat("boxing"), 0.0, 1)
	_play_all(drill, 0.0)
	var auto: Dictionary = camp.run_plan(plan)
	var great: Dictionary = played.run_plan(plan, { slot: drill.quality() })
	assert_gt(great.gains.boxing, auto.gains.boxing)
