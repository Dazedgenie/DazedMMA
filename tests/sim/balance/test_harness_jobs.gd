extends GutTest
## HarnessJobs: the balance harness's fights as a list that can be shared out
## between several processes and put back in order (#35, D123).


func _plan() -> Array[Dictionary]:
	return HarnessJobs.plan(["kicker:boxer", "wrestler:kicker"], 3, 10, [Corner.NONE, Corner.AI], [0, 1],
		{ "wrestler": ["catch_kick_and_shoot@80"] })


func test_the_plan_lists_every_fight_in_report_order() -> void:
	var jobs: Array[Dictionary] = _plan()
	# Each pair: no corners, the AI corner in red's then blue's corner; then the Wrestler's pair once more with his rule.
	assert_eq(jobs.size(), 2 * 3 * 3 + 3)
	assert_eq(jobs[0], { "seed": 10, "red": "kicker", "blue": "boxer", "corners": [Corner.NONE, Corner.NONE], "rules": [], "group": "kicker:boxer" })
	assert_eq(jobs[3].corners, [Corner.AI, Corner.NONE])
	assert_eq(jobs[6].corners, [Corner.NONE, Corner.AI])
	assert_eq(jobs[8].seed, 12)
	assert_eq(jobs[-1].rules, [["catch_kick_and_shoot@80"], []])
	assert_eq(jobs[-1].group, "wrestler:kicker, drilled rules")


func test_each_gameplan_plays_every_pair_again_with_the_plan_in_each_corner() -> void:
	var jobs: Array[Dictionary] = HarnessJobs.plan(["kicker:boxer"], 2, 1, [Corner.NONE], [0, 1], {}, ["counter+legs"])
	assert_eq(jobs.size(), 2 + 2 * 2)
	assert_eq(jobs[2].plans, ["counter+legs", ""])
	assert_eq(jobs[4].plans, ["", "counter+legs"])
	assert_eq(jobs[4].group, "kicker:boxer, counter+legs in blue's corner")
	var row: Dictionary = HarnessJobs.run(jobs[2], FighterLibrary.load_dir(), ActionLibrary.load_dir(), Ruleset.load_id("pro"))
	assert_eq([row.plan_red, row.plan_blue], ["counter+legs", ""])


func test_every_fight_goes_to_exactly_one_process() -> void:
	for processes in range(1, 6):
		var seen: Array[int] = []
		for k in processes:
			seen.append_array(HarnessJobs.share(21, processes, k))
		seen.sort()
		assert_eq(seen, Array(range(21), TYPE_INT, "", null), "%d processes" % processes)


func test_rows_from_several_processes_come_back_in_fight_order() -> void:
	for processes in range(1, 6):
		var parts: Array = []
		for k in processes:
			var part: Array = []
			for n in HarnessJobs.share(13, processes, k):
				part.append({ "job": n })
			parts.append(part)
		var rows: Array[Dictionary] = HarnessJobs.merge(parts, 13)
		for n in 13:
			assert_eq(rows[n].job, n, "%d processes" % processes)


func test_a_row_comes_back_unchanged_from_another_process() -> void:
	# Other processes hand their rows back in a binary file (FileAccess.store_var), so floats survive
	# exactly; as text (var_to_str) this row's circling_red would come back 21.9 instead of 21.900000000000002.
	var row: Dictionary = FightSummary.run(7, FighterLibrary.load_dir(), ActionLibrary.load_dir(), "kicker", "boxer", 1, 60)
	var back: Variant = bytes_to_var(var_to_bytes([row]))
	assert_eq(back[0], row)
	for key: String in row:
		assert_eq(typeof(back[0][key]), typeof(row[key]), key)
