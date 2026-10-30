extends MainLoop
## Prints every opponent style sheet's scouting card (data/styles, docs/03 §6, D160) and,
## with --fights=N, checks that opponents made from each sheet fight in style: N generated
## opponents of each style (seeds 1…N, level --level) each fight one signature fighter of
## another style in turn, and a table shows how each style wins and what it does.
##
## Usage:
##   godot --headless --script res://tools/style_sheets.gd [-- --fights=20 --level=0 --style=brawler]


func _initialize() -> void:
	var fights: int = 0
	var level: int = 0
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fights="):
			fights = int(arg.trim_prefix("--fights="))
		elif arg.begins_with("--level="):
			level = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--style="):
			only = arg.trim_prefix("--style=")
	var styles := StyleLibrary.load_dir()
	var ids: Array = styles.ids()
	ids.sort()
	if only != "":
		if not styles.has(only):
			printerr("No style '%s' in data/styles (have: %s)" % [only, ", ".join(ids)])
			return
		ids = [only]
	for id: String in ids:
		_print_card(styles.get_style(id))
	if fights > 0:
		_check_styles(styles, ids, fights, level)


func _print_card(s: Dictionary) -> void:
	var card: Dictionary = s.scouting
	print("── %s ── (built on data/fighters/%s.json; roots: %s)" % [s.name, s.fighter, ", ".join(s.roots)])
	print("  %s" % card.summary)
	print("  + %s" % "; ".join(card.strengths))
	print("  − %s" % "; ".join(card.weaknesses))
	print("  Tell: %s" % (card.tell if card.tell != null else "none known"))
	print("  How to beat him: %s" % card.how_to_beat)
	print("")


## One row per style: win rate against the field, how the wins came, and what the style does.
func _check_styles(styles: StyleLibrary, ids: Array, fights: int, level: int) -> void:
	var actions := ActionLibrary.load_dir()
	var all: Array = styles.ids()
	all.sort()
	print("%d generated opponents per style at level %+d, each against the other styles' signature fighters in turn:" % [fights, level])
	print("%-26s %5s %5s %5s %6s %6s %5s %6s %6s" % ["style", "win%", "KO%", "sub%", "strk/m", "shots", "subs", "clinch", "ground"])
	for id: String in ids:
		var others: Array = all.filter(func(o: String) -> bool: return o != id)
		var t := { "wins": 0, "ko": 0, "sub": 0, "thrown": 0.0, "shots": 0.0, "subs": 0.0, "clinch": 0.0, "ground": 0.0, "seconds": 0.0 }
		for n in fights:
			var roster := FighterLibrary.load_dir()
			var gen: Dictionary = styles.generate(id, n + 1, level, roster)
			roster.add(gen)
			var opponent: String = styles.get_style(others[n % others.size()]).fighter
			var row: Dictionary = FightSummary.run(n + 1, roster, actions, gen.id, opponent)
			if row.winner == "red":
				t.wins += 1
				if row.method in [FightSummary.METHOD_KO, FightSummary.METHOD_TKO]:
					t.ko += 1
				elif row.method == FightSummary.METHOD_SUB:
					t.sub += 1
			t.thrown += float(row.thrown_red)
			t.shots += float(row.shots_red) + float(row.throws_red)
			t.subs += float(row.subs_red)
			t.clinch += float(row.clinch)
			t.ground += float(row.ground)
			t.seconds += float(row.fight_seconds)
		print("%-26s %4.0f%% %4.0f%% %4.0f%% %6.1f %6.1f %5.1f %5.0f%% %5.0f%%" % [
			styles.get_style(id).name, 100.0 * t.wins / fights, 100.0 * t.ko / fights, 100.0 * t.sub / fights,
			t.thrown / (t.seconds / 60.0), t.shots / fights, t.subs / fights, 100.0 * t.clinch / fights, 100.0 * t.ground / fights])
	print("win% against the field · KO% and sub% are wins that way · strk/m strikes thrown a fight-minute · shots takedowns and throws tried a fight · subs submissions tried a fight · clinch/ground share of the fight")


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
