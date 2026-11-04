class_name RoundBreakCard
extends VBoxContainer
## The round break's card (docs/06 §6.17, D465, Kyle's pick): the judges' cards for the round as chips in the colour
## of the man each gave it to, the totals so far, and the two men side by side as mirrored bars: strikes landed,
## stamina, and the damage taken to the head, body and legs. It sits at the top of the break's side panel, over the
## rule and gameplan pickers. Presentation only.

## A bar's longest, at 1080p.
const BAR_WIDTH: float = 140.0
const BAR_HEIGHT: float = 10.0
## The middle column's width.
const LABEL_WIDTH: float = 120.0


## The rows of the side-by-side, top to bottom: [label, red's words, blue's words, red's amount, blue's amount].
static func rows(sim: FightSim) -> Array:
	var a: FighterState = sim.fighters[0]
	var b: FighterState = sim.fighters[1]
	var out: Array = [
		["LANDED", "%d of %d" % [a.strikes_landed, a.strikes_thrown], "%d of %d" % [b.strikes_landed, b.strikes_thrown],
			float(a.strikes_landed), float(b.strikes_landed)],
		["STAMINA", "%d" % roundi(a.stamina), "%d" % roundi(b.stamina), a.stamina, b.stamina],
	]
	for area: String in ["head", "body", "legs"]:
		var hurt_a: int = int(a.damage[area])
		var hurt_b: int = int(b.damage[area])
		out.append(["%s HURT" % area.to_upper(), "%d" % hurt_a, "%d" % hurt_b, float(hurt_a), float(hurt_b)])
	return out


## Who a judge's card went to: 0 red, 1 blue, -1 even.
static func card_winner(card: Array) -> int:
	if int(card[0]) == int(card[1]):
		return -1
	return 0 if int(card[0]) > int(card[1]) else 1


## The line beside the chips: "Boxer's round", "Kicker's round" or "An even round", by most cards.
static func round_verdict(sim: FightSim, cards: Array) -> String:
	var won: Array[int] = [0, 0]
	for card: Array in cards:
		var w: int = card_winner(card)
		if w >= 0:
			won[w] += 1
	if won[0] == won[1]:
		return "An even round"
	return "%s's round" % sim.fighters[0 if won[0] > won[1] else 1].name


func _init() -> void:
	add_theme_constant_override("separation", 14)


## Fills the card from the bell's event (its `cards`, or none under whole-fight judging, D141).
func show_round(sim: FightSim, event: FightEvent) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var judges := HBoxContainer.new()
	judges.add_theme_constant_override("separation", 10)
	add_child(judges)
	judges.add_child(FightHud._heading("JUDGES"))
	if not event.data.has("cards"):
		var whole := Label.new()
		whole.text = "Whole fight: %s" % FightHud.judges_estimate(sim).trim_prefix("Judges: ")
		whole.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		whole.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		judges.add_child(whole)
	else:
		for card: Array in event.data.cards:
			judges.add_child(_chip("%d-%d" % [card[0], card[1]], card_winner(card)))
		var verdict := Label.new()
		verdict.text = round_verdict(sim, event.data.cards)
		verdict.add_theme_color_override("font_color", Color("#aeb4bd"))
		verdict.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		judges.add_child(verdict)
		if event.round_number > 1:
			var totals: Array[String] = []
			for t: Array in sim.judge_totals:
				totals.append("%d-%d" % [t[0], t[1]])
			var so_far := HBoxContainer.new()
			so_far.add_theme_constant_override("separation", 10)
			so_far.add_child(FightHud._heading("SO FAR"))
			var total := Label.new()
			total.text = "  ·  ".join(totals)
			so_far.add_child(total)
			add_child(so_far)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for i in 2:
		var name := Label.new()
		name.text = sim.fighters[i].name
		DisplayFont.apply(name, 24)
		name.add_theme_color_override("font_color", FightHud.FIGHTER_COLOURS[i])
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name)
		if i == 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
			grid.add_child(gap)
	for row: Array in rows(sim):
		var most: float = maxf(1.0, maxf(float(row[3]), float(row[4])))
		grid.add_child(_side(0, String(row[1]), float(row[3]) / most))
		var label: Label = FightHud._heading(String(row[0]), 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)
		grid.add_child(_side(1, String(row[2]), float(row[4]) / most))


func _side(i: int, words: String, share: float) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_END if i == 0 else BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 8)
	var value := Label.new()
	value.text = words
	value.add_theme_font_size_override("font_size", 17)
	var bar := ColorRect.new()
	bar.color = FightHud.FIGHTER_COLOURS[i]
	bar.custom_minimum_size = Vector2(maxf(2.0, BAR_WIDTH * clampf(share, 0.0, 1.0)), BAR_HEIGHT)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(value if i == 0 else bar)
	box.add_child(bar if i == 0 else value)
	return box


func _chip(text: String, winner: int) -> Label:
	var chip := Label.new()
	chip.text = text
	DisplayFont.apply(chip, 26)
	var colour: Color = FightHud.FIGHTER_COLOURS[winner] if winner >= 0 else FightHud.MUTED
	chip.add_theme_color_override("font_color", colour.lightened(0.5))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(colour, 0.15)
	box.border_color = Color(colour, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	chip.add_theme_stylebox_override("normal", box)
	return chip
