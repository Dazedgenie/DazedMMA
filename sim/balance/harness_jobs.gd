class_name HarnessJobs
extends RefCounted
## The balance harness's fights as a plain list (#35, D123, docs/01 §2.3), so
## tools/balance.gd can share them out between several Godot processes and put
## the rows back in the same order: the CSV and summary come out the same
## whichever number of processes ran them.
##
## A job is one fight: { seed, red, blue, corners ([red, blue] Corner styles),
## rules ([red, blue] lists of "rule_id@drilled"), group (a label for progress) }.


## Every fight a harness run plays, in report order: for each pair, every
## corner style (with the bot in each side in `coach_sides`), then the pair
## with its fighters' drilled rules if any are given (`drilled`: fighter id →
## ["rule_id@drilled", …]).
static func plan(pairs: PackedStringArray, fights: int, first_seed: int, corners: PackedStringArray, coach_sides: Array[int], drilled: Dictionary) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	for pair in pairs:
		var ids: PackedStringArray = pair.split(":")
		for style in corners:
			for side in ([0] if style == Corner.NONE else coach_sides):
				var both: Array[String] = [Corner.NONE, Corner.NONE]
				both[side] = style
				var group: String = pair if style == Corner.NONE else "%s, %s caller in %s's corner" % [pair, style, ["red", "blue"][side]]
				for n in fights:
					jobs.append({ "seed": first_seed + n, "red": ids[0], "blue": ids[1], "corners": both, "rules": [], "group": group })
		var with_rules: Array = [drilled.get(ids[0], []), drilled.get(ids[1], [])]
		if not with_rules[0].is_empty() or not with_rules[1].is_empty():
			for n in fights:
				jobs.append({ "seed": first_seed + n, "red": ids[0], "blue": ids[1], "corners": [] as Array[String],
					"rules": with_rules, "group": pair + ", drilled rules" })
	return jobs


## Plays one job and returns its FightSummary row. `blue_first` has blue step before red
## every tick (FightSim.step_order), for the corner-lean check (D252).
static func run(job: Dictionary, roster: FighterLibrary, actions: ActionLibrary, rules: Ruleset, blue_first: bool = false) -> Dictionary:
	var corners: Array[String] = []
	corners.assign(job.corners)
	var sim: FightSim = FightSummary.setup(job.seed, roster, actions, job.red, job.blue, rules, 300, corners, job.rules)
	if blue_first:
		sim.step_order = [1, 0]
	return FightSummary.play(sim)


## The jobs process `k` of `processes` plays: every processes-th job from k,
## so each process gets a share of every pair and corner.
static func share(job_count: int, processes: int, k: int) -> Array[int]:
	var out: Array[int] = []
	for n in range(k, job_count, processes):
		out.append(n)
	return out


## Puts the rows from each process (parts[k] in the order share() gave them)
## back into job order.
static func merge(parts: Array, job_count: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.resize(job_count)
	for k in parts.size():
		var indexes: Array[int] = share(job_count, parts.size(), k)
		assert(indexes.size() == parts[k].size(), "process %d returned %d rows, expected %d" % [k, parts[k].size(), indexes.size()])
		for i in indexes.size():
			rows[indexes[i]] = parts[k][i]
	return rows
