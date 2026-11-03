class_name WorldScreen
extends PanelContainer
## The world pages as one full-screen page with tabs (docs/06 §6.12, D432; Kyle's picks on the D430 and D432 cards), in
## place of the four text pop-ups (D352, D354, D355, D358): *His division*, *Rankings*, *Promotions* and *History*.
##
## His division is a table of every man in it (name, age, where he's from, level, promotion and rank, record, style,
## grade, how it went if you fought him): click a column to sort by it, filter to pros, amateurs, the ranked men or the
## ones you've fought, his row picked out. Rankings and History show one promotion at a time, picked from its badges
## (opening on his own promotion): its champion with a belt, its table with each man's last move as an arrow and the
## reasons under it; each belt's champions as a timeline across the years with the legends under it. Promotions is a
## card each, in its colour with its badge, its next cards as small posters. Clicking a man anywhere opens his card at
## the side (ManCard). Close or Esc goes back to the hub.

signal closed

const DIVISION := "division"
const RANKINGS := "rankings"
const PROMOTIONS := "promotions"
const HISTORY := "history"
const TABS: Array = [[DIVISION, "His division"], [RANKINGS, "Rankings"], [PROMOTIONS, "Promotions"], [HISTORY, "History"]]
const FILTERS: Array = [["all", "Everyone"], ["pros", "Pros"], ["amateurs", "Amateurs"], ["ranked", "Ranked"], ["fought", "Fought him"]]
## His division's columns: [key, title, how wide against the others, sorted high first when first clicked].
const DIVISION_COLUMNS: Array = [["name", "Name", 5, false], ["age", "Age", 1, false], ["from", "From", 4, false],
	["level", "Level", 2, true], ["promotion", "Promotion", 2, true], ["record", "Record", 2, true], ["style", "Style", 3, false],
	["grade", "Grade", 1, true], ["met", "You", 2, true]]
const RANK_COLUMNS: Array = [["rank", "#", 1], ["move", "Move", 1], ["name", "Name", 5], ["record", "Record", 2], ["from", "From", 3],
	["note", "", 5]]
## His row's colour behind it, and the champion's.
const HIM_ROW := Color(0.41, 0.86, 0.49, 0.16)
const CHAMPION_ROW := Color(0.99, 0.77, 0.1, 0.10)
const BACKGROUND := Color("#0f1217")
const TABLE := Color("#161a20")
const UP := "▲"
const DOWN := "▼"
## The Tree's row padding and font sizes.
const ROW_PAD: int = 6
const FONT_SIZE: int = 17
const PROMOTION_BADGE := Vector2(38.0, 38.0)
const CARD_BADGE := Vector2(64.0, 64.0)
## The belt drawn by the champion's name, px.
const BELT_SIZE := Vector2i(30, 16)

var career: Career
var tab: String = DIVISION
## The promotion Rankings and History are showing.
var promotion_id: String = ""
var filter: String = "all"
var sort_key: String = "grade"
var sort_down: bool = true
var man_card: ManCard

var _title: Label
var _tab_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _filter_buttons: Dictionary = {}
var _count: Label
var division_tree: Tree
## Every row the division table can show this week (rows(), then filtered and sorted into the tree).
var division_rows: Array[Dictionary] = []
var _rank_strip: HBoxContainer
var _rank_strip_buttons: Dictionary = {}
var _his_rank: RichTextLabel
var _champion: RichTextLabel
var _champion_belt: TextureRect
var rank_tree: Tree
var _moves: RichTextLabel
var _promotion_grid: GridContainer
var _history_strip: HBoxContainer
var _history_strip_buttons: Dictionary = {}
var _home_legend: RichTextLabel
var _history_title: Label
var timeline: BeltTimeline
var _legends: GridContainer

static var _belt: ImageTexture


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = OffCage.hall_panel(true)  # Over the hub, so solid (D435).
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	_title = Label.new()
	DisplayFont.apply(_title, 44)
	_title.add_theme_color_override("font_color", CareerHub.RED_CORNER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var group := ButtonGroup.new()
	for t: Array in TABS:
		var b := Button.new()
		b.text = String(t[1])
		b.toggle_mode = true
		b.button_group = group
		DisplayFont.apply(b, 24)
		b.custom_minimum_size = Vector2(150.0, 46.0)
		var key: String = String(t[0])
		b.pressed.connect(func() -> void: show_tab(key))
		top.add_child(b)
		_tab_buttons[key] = b
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 24.0
	top.add_child(spacer)
	var close := Button.new()
	close.text = "Back to the hub"
	close.tooltip_text = "Esc"
	close.custom_minimum_size = Vector2(0.0, 46.0)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(close_page)
	top.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var pages := Control.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(pages)
	man_card = ManCard.new()
	man_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(man_card)
	_pages[DIVISION] = _build_division()
	_pages[RANKINGS] = _build_rankings()
	_pages[PROMOTIONS] = _build_promotions()
	_pages[HISTORY] = _build_history()
	for key: String in _pages:
		var page: Control = _pages[key]
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		pages.add_child(page)
	visible = false


## Opens the world pages for this career on this tab.
func show_world(c: Career, p_tab: String = DIVISION) -> void:
	career = c
	var w: World = c.world()
	if promotion_id == "" or Promotions.by_id(w, promotion_id).is_empty():
		promotion_id = his_promotion(c)
	_title.text = "THE WORLD · %s" % Weight.name_of(c.division_now()).to_upper()
	man_card.visible = false
	_fill_strips()
	visible = true
	show_tab(p_tab)


## The promotion Rankings and History open on: his own once he's signed, else his home promotion.
static func his_promotion(c: Career) -> String:
	var w: World = c.world()
	var his: String = String(w.him.get("promotion", ""))
	if his != "" and not Promotions.by_id(w, his).is_empty():
		return his
	return String(Promotions.home(w).get("id", ""))


func show_tab(p_tab: String) -> void:
	tab = p_tab if _pages.has(p_tab) else DIVISION
	for key: String in _pages:
		(_pages[key] as Control).visible = key == tab
		(_tab_buttons[key] as Button).set_pressed_no_signal(key == tab)
	if career == null:
		return
	match tab:
		DIVISION:
			_fill_division()
		RANKINGS:
			_fill_rankings()
		PROMOTIONS:
			_fill_promotions()
		HISTORY:
			_fill_history()


## Rankings and History show this promotion.
func show_promotion(id: String) -> void:
	promotion_id = id
	for strip: Dictionary in [_rank_strip_buttons, _history_strip_buttons]:
		for key: String in strip:
			(strip[key] as Button).set_pressed_no_signal(key == id)
	if tab == RANKINGS:
		_fill_rankings()
	elif tab == HISTORY:
		_fill_history()


## Opens this man's card at the side.
func show_man(id: String) -> void:
	if career != null and id != "":
		man_card.show_man(career, id)


func close_page() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if man_card.visible:
			man_card.close_card()
		else:
			close_page()
		get_viewport().set_input_as_handled()


# --- His division -------------------------------------------------------------------------------------------------


func _build_division() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	page.add_child(bar)
	var group := ButtonGroup.new()
	for f: Array in FILTERS:
		var b := Button.new()
		b.text = String(f[1])
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_font_size_override("font_size", 17)
		var key: String = String(f[0])
		b.pressed.connect(func() -> void: set_filter(key))
		bar.add_child(b)
		_filter_buttons[key] = b
	_count = FightNightCard._label(17, CareerHub.DIM)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_count)
	division_tree = _tree(DIVISION_COLUMNS)
	division_tree.column_title_clicked.connect(func(col: int, _button: int) -> void: sort_by(String(DIVISION_COLUMNS[col][0])))
	division_tree.item_selected.connect(func() -> void: _picked(division_tree))
	page.add_child(division_tree)
	return page


## The division table's rows (see the top), unfiltered and unsorted: { id, cells (by column key), keys (to sort by),
## pro, ranked, met, mine }.
static func rows(c: Career) -> Array[Dictionary]:
	var w: World = c.world()
	var met: Dictionary = {}
	for f: Dictionary in c.fights:
		met[String(f.get("opponent", ""))] = String(f.get("result", ""))
	var out: Array[Dictionary] = []
	for m: Dictionary in CareerHub.division_men(c):
		var id: String = String(m.id)
		var style_id: String = String(m.style)
		var style_name: String = String(StyleLibrary.shared().get_style(style_id).get("name", style_id)) if StyleLibrary.shared().has(style_id) else style_id
		var p: Dictionary = Promotions.of(w, m)
		var rank: int = Rankings.rank_of(w, id)
		var belt: bool = Titles.held_by(w, id) != ""
		var promo: String = ""
		if not p.is_empty():
			promo = String(p.short) + (" · C" if belt else (" · #%d" % rank) if rank > 0 else "")
		var r: Dictionary = m.get("record", {})
		var result: String = String(met.get(id, ""))
		var nick: String = String(m.get("nickname", ""))
		out.append({
			"id": id, "pro": bool(m.pro), "ranked": rank > 0 or belt, "met": met.has(id), "mine": false, "belt": belt,
			"former": History.former_tag(w, id), "colour": PromotionBadge.colour_of(w, p) if not p.is_empty() else CareerHub.TEXT,
			"cells": { "name": String(m.name) + ((" '%s'" % nick) if nick != "" else ""), "age": str(int(floor(World.age_of(m, c.week)))),
				"from": "%s, %s" % [String(m.hometown), String(m.country)], "level": World.level_name(m) if bool(m.pro) else "Amateur",
				"promotion": promo, "record": World.record_text(m), "style": style_name, "grade": TrainingCamp.grade(w.average(m)),
				"met": { "win": "beat him", "loss": "lost to him", "draw": "drew" }.get(result, "fought him") if met.has(id) else "" },
			"keys": { "name": String(m.name), "age": World.age_of(m, c.week), "from": String(m.country) + String(m.hometown),
				"level": _level_order(m), "promotion": (100 - int(p.rank) * 30 - (0 if belt else rank if rank > 0 else 20)) if not p.is_empty() else -1000,
				"record": int(r.get("win", 0)) * 1000 - int(r.get("loss", 0)), "style": style_name, "grade": w.average(m),
				"met": { "win": 3, "draw": 2, "loss": 1 }.get(result, 0) if met.has(id) else -1 },
		})
	# Him, picked out.
	var me: Dictionary = c.record(c.pro)
	var his_p: Dictionary = Promotions.by_id(w, String(w.him.get("promotion", "")))
	var his_rank: int = Rankings.rank_of(w, Career.FIGHTER_ID)
	var his_belt: bool = Titles.held_by(w, Career.FIGHTER_ID) != ""
	var stats: Dictionary = c.profile().get("stats", {})
	var total: float = 0.0
	for v: Variant in stats.values():
		total += float(v)
	var avg: float = total / maxf(stats.size(), 1.0)
	out.append({
		"id": Career.FIGHTER_ID, "pro": c.pro, "ranked": his_rank > 0 or his_belt, "met": false, "mine": true, "belt": his_belt, "former": "",
		"cells": { "name": c.fighter_name() + " (you)", "age": str(c.age()),
			"from": "%s, %s" % [String(c.about.get("hometown", "")), String(c.about.get("country", ""))], "level": "Pro" if c.pro else "Amateur",
			"promotion": (String(his_p.short) + (" · C" if his_belt else (" · #%d" % his_rank) if his_rank > 0 else "")) if not his_p.is_empty() else "",
			"record": c.record_text(c.pro), "style": "Your fighter", "grade": TrainingCamp.grade(avg), "met": "" },
		"keys": { "name": c.fighter_name(), "age": float(c.age()), "from": String(c.about.get("country", "")), "level": 1 if c.pro else 0,
			"promotion": (100 - int(his_p.rank) * 30 - (0 if his_belt else his_rank if his_rank > 0 else 20)) if not his_p.is_empty() else -1000,
			"record": int(me.win) * 1000 - int(me.loss), "style": "", "grade": avg, "met": -1 },
	})
	return out


static func _level_order(m: Dictionary) -> int:
	if not bool(m.get("pro", false)):
		return 0
	for i in World.LEVELS.size():
		if String(World.LEVELS[i].id) == String(m.get("tier", "")):
			return i + 1
	return 1


func set_filter(key: String) -> void:
	filter = key
	_fill_division(false)


## Sorts the division table by this column; the same column again turns it round.
func sort_by(key: String) -> void:
	if key == sort_key:
		sort_down = not sort_down
	else:
		sort_key = key
		for col: Array in DIVISION_COLUMNS:
			if String(col[0]) == key:
				sort_down = bool(col[3])
	_fill_division(false)


## The rows the table shows now: filtered, then sorted (him always in, whatever the filter, so you can find him).
func shown_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in division_rows:
		var keep: bool = true
		match filter:
			"pros":
				keep = bool(r.pro)
			"amateurs":
				keep = not bool(r.pro)
			"ranked":
				keep = bool(r.ranked)
			"fought":
				keep = bool(r.met)
		if keep or bool(r.mine):
			out.append(r)
	var key: String = sort_key
	var down: bool = sort_down
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var x: Variant = a.keys[key]
		var y: Variant = b.keys[key]
		if x == y:
			return String(a.keys.name) < String(b.keys.name)
		if x is String:
			return (String(x) > String(y)) if down else (String(x) < String(y))
		return (float(x) > float(y)) if down else (float(x) < float(y)))
	return out


func _fill_division(fresh: bool = true) -> void:
	if fresh:
		division_rows = rows(career)
	for key: String in _filter_buttons:
		(_filter_buttons[key] as Button).set_pressed_no_signal(key == filter)
	var shown: Array[Dictionary] = shown_rows()
	_count.text = "%d men · click a column to sort, a man to see his card" % (shown.size() - 1)
	division_tree.clear()
	var root: TreeItem = division_tree.create_item()
	for col in DIVISION_COLUMNS.size():
		var key: String = String(DIVISION_COLUMNS[col][0])
		division_tree.set_column_title(col, String(DIVISION_COLUMNS[col][1]) + ((" " + (DOWN if sort_down else UP)) if key == sort_key else ""))
	for r: Dictionary in shown:
		var item: TreeItem = division_tree.create_item(root)
		item.set_metadata(0, String(r.id))
		for col in DIVISION_COLUMNS.size():
			var key: String = String(DIVISION_COLUMNS[col][0])
			item.set_text(col, String(r.cells[key]))
			if bool(r.mine):
				item.set_custom_bg_color(col, HIM_ROW)
				item.set_custom_color(col, CareerHub.GOOD)
		if r.has("colour") and not bool(r.mine):
			item.set_custom_color(4, (r.colour as Color).lightened(0.25))
		if bool(r.belt):
			item.set_icon(0, belt_texture())
			item.set_custom_color(4, CareerHub.WARN)
		elif String(r.former) != "":
			item.set_tooltip_text(0, String(r.former))
			item.set_custom_color(0, CareerHub.WARN)
		if String(r.cells.met) != "":
			var result: String = String(r.cells.met)
			item.set_custom_color(8, CareerHub.GOOD if result == "beat him" else CareerHub.BAD if result == "lost to him" else CareerHub.WARN)


# --- Rankings -----------------------------------------------------------------------------------------------------


func _build_rankings() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	_rank_strip = HBoxContainer.new()
	_rank_strip.add_theme_constant_override("separation", 8)
	page.add_child(_rank_strip)
	_his_rank = _rich(18)
	page.add_child(_his_rank)
	var champion := HBoxContainer.new()
	champion.add_theme_constant_override("separation", 10)
	page.add_child(champion)
	_champion_belt = TextureRect.new()
	_champion_belt.texture = belt_texture()
	_champion_belt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_champion_belt.custom_minimum_size = Vector2(BELT_SIZE) * 1.6
	_champion_belt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	champion.add_child(_champion_belt)
	_champion = _rich(20)
	_champion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_champion.mouse_filter = Control.MOUSE_FILTER_STOP
	_champion.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_champion.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			show_man(champion_id()))
	champion.add_child(_champion)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	rank_tree = _tree(RANK_COLUMNS)
	rank_tree.size_flags_stretch_ratio = 3.0
	rank_tree.item_selected.connect(func() -> void: _picked(rank_tree))
	body.add_child(rank_tree)
	var moves_scroll := ScrollContainer.new()
	moves_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_scroll.size_flags_stretch_ratio = 2.0
	moves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(moves_scroll)
	_moves = _rich(16)
	_moves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_scroll.add_child(_moves)
	return page


## The champion of the promotion Rankings shows, in his division ("" when it's vacant).
func champion_id() -> String:
	if career == null:
		return ""
	return String(Titles.belt(career.world(), Rankings.key(promotion_id, career.division_now())).get("champion", ""))


func _fill_rankings() -> void:
	var c: Career = career
	var w: World = c.world()
	var division: String = c.division_now()
	var p: Dictionary = Promotions.by_id(w, promotion_id)
	_his_rank.text = CareerHub.his_rank_text(c)
	_his_rank.visible = _his_rank.text != ""
	var k: String = Rankings.key(promotion_id, division)
	_champion.text = CareerHub.champion_line(c, w, k)
	_champion_belt.modulate = Color.WHITE if champion_id() != "" else Color(1.0, 1.0, 1.0, 0.25)
	var moved: Dictionary = {}
	var note: Dictionary = w.ranking_moves.get(k, {})
	for mv: Dictionary in note.get("moves", []):
		moved[String(mv.id)] = mv
	rank_tree.clear()
	var root: TreeItem = rank_tree.create_item()
	var ids: Array = Rankings.table(w, promotion_id, division)
	for i in ids.size():
		var id: String = String(ids[i])
		var mine: bool = id == Career.FIGHTER_ID
		var m: Dictionary = {} if mine else w.man(id)
		var item: TreeItem = rank_tree.create_item(root)
		item.set_metadata(0, id)
		item.set_text(0, str(i + 1))
		var mv: Dictionary = moved.get(id, {})
		var move: String = "–"
		var move_colour: Color = CareerHub.DIM
		if not mv.is_empty():
			var from: int = int(mv.from)
			if from == 0:
				move = "NEW"
				move_colour = CareerHub.GOOD
			elif int(mv.to) < from:
				move = "%s%d" % [UP, from - int(mv.to)]
				move_colour = CareerHub.GOOD
			elif int(mv.to) > from:
				move = "%s%d" % [DOWN, int(mv.to) - from]
				move_colour = CareerHub.BAD
		item.set_text(1, move)
		item.set_custom_color(1, move_colour)
		item.set_text(2, (c.fighter_name() + " (you)") if mine else String(m.get("name", "")))
		item.set_text(3, c.record_text(true) if mine else World.record_text(m))
		item.set_text(4, String(c.about.get("country", "")) if mine else String(m.get("country", "")))
		var former: String = "" if mine else History.former_tag(w, id)
		item.set_text(5, former)
		item.set_custom_color(5, CareerHub.WARN)
		if mine:
			for col in RANK_COLUMNS.size():
				item.set_custom_bg_color(col, HIM_ROW)
				if col != 1:
					item.set_custom_color(col, CareerHub.GOOD)
	if ids.is_empty():
		var item: TreeItem = rank_tree.create_item(root)
		item.set_text(2, "Nobody ranked yet.")
		item.set_custom_color(2, CareerHub.DIM)
		item.set_selectable(2, false)
	var lines: Array[String] = []
	lines.append("[color=%s][b]%s[/b] · top %d[/color]" % [PromotionBadge.colour_of(w, p).to_html(false), String(p.get("name", "")), Rankings.size_for(p)])
	if not (note.get("moves", []) as Array).is_empty():
		var week: int = int(note.week)
		var when: String = c.short_date(week, 5)
		if Promotions.has_card(p, week):
			when = "%s, %s" % [String(Promotions.card(w, p, week).short), when]
		lines.append("[color=%s]Moves after %s:[/color]" % [CareerHub.DIM.to_html(false), when])
		var shuffled: int = 0
		for mv: Dictionary in note.moves:
			if String(mv.why).begins_with("others'"):
				shuffled += 1
				continue
			lines.append(CareerHub.move_text(w, mv, c))
		if shuffled > 0:
			lines.append("[color=%s]%d more moved on others' results[/color]" % [CareerHub.DIM.to_html(false), shuffled])
	else:
		lines.append("[color=%s]No moves since its last card.[/color]" % CareerHub.DIM.to_html(false))
	_moves.text = "\n".join(lines)


# --- Promotions ---------------------------------------------------------------------------------------------------


func _build_promotions() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_promotion_grid = GridContainer.new()
	_promotion_grid.columns = 2
	_promotion_grid.add_theme_constant_override("h_separation", 16)
	_promotion_grid.add_theme_constant_override("v_separation", 16)
	_promotion_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_promotion_grid)
	return scroll


## The promotions, biggest first.
static func ordered(w: World) -> Array:
	var out: Array = w.promotions.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.rank) < int(b.rank) if int(a.rank) != int(b.rank) else String(a.id) < String(b.id))
	return out


func _fill_promotions() -> void:
	for child in _promotion_grid.get_children():
		child.queue_free()
	var w: World = career.world()
	for p: Dictionary in ordered(w):
		_promotion_grid.add_child(_promotion_card(w, p))


func _promotion_card(w: World, p: Dictionary) -> Control:
	var c: Career = career
	var division: String = c.division_now()
	var colour: Color = PromotionBadge.colour_of(w, p)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = FightHud._panel_style(CareerHub.CARD)
	style.set_content_margin_all(18)
	style.border_width_left = 6
	style.border_width_top = 0
	style.border_color = colour
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	var badge := PromotionBadge.new(Vector2(CARD_BADGE.x * (1.5 if PromotionBadge.shape_of(p) == PromotionBadge.PLATE else 1.0), CARD_BADGE.y))
	badge.show_promotion(w, p)
	head.add_child(badge)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	var name := Label.new()
	DisplayFont.apply(name, 30)
	name.text = String(p.name)
	name.add_theme_color_override("font_color", CareerHub.TEXT)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(name)
	var kind := FightNightCard._label(16, colour.lightened(0.2))
	var home: bool = String(p.id) == String(Promotions.home(w).get("id", ""))
	var his: bool = String(p.id) == String(w.him.get("promotion", ""))
	kind.text = String(p.kind).to_upper() + (" · YOUR PROMOTION" if his else " · YOUR HOMETOWN'S" if home else "")
	names.add_child(kind)
	var men: int = 0
	var here: int = 0
	for m: Dictionary in w.men.values():
		if World.active(m) and String(m.get("promotion", "")) == String(p.id):
			men += 1
			here += 1 if World.division_of(m, c.week) == division else 0
	var info := _rich(16)
	info.text = "From %s, %s · the %s, %s seats\n[color=%s]$%s to show, $%s more to win · %d men, %d at %s · a card every %d weeks[/color]" % [
		String(p.city), NameLibrary.shared().country_name(String(p.country)), String(p.venue), CareerHub._thousands(int(p.capacity)),
		CareerHub.DIM.to_html(false), CareerHub._thousands(int(p.show)), CareerHub._thousands(int(p.win)), men, here,
		Weight.name_of(division).to_lower(), int(p.every)]
	box.add_child(info)
	var k: String = Rankings.key(String(p.id), division)
	var champion := _rich(16)
	champion.text = CareerHub.champion_line(c, w, k)
	box.add_child(champion)
	var posters := HBoxContainer.new()
	posters.add_theme_constant_override("separation", 10)
	box.add_child(posters)
	for week: int in Promotions.card_weeks(p, c.week, c.week + 12).slice(0, 3):
		var mine: bool = not c.booked.is_empty() and int(c.booked.get("week", -1)) == week \
			and String(c.booked.get("card", {}).get("promotion", "")) == String(p.id)
		posters.add_child(_poster(w, p, week, colour, mine))
	if home:
		var legend: String = CareerHub.home_legend_text(c)
		if legend != "":
			var l := _rich(15)
			l.text = legend
			box.add_child(l)
	var last: Array[String] = []
	var last_week: int = -1
	var last_card: String = ""
	for r: Dictionary in w.results:
		if String(r.get("kind", "fight")) == "fight" and String(r.get("promotion", "")) == String(p.id) and String(r.division) == division \
				and int(r.week) >= last_week:
			if int(r.week) > last_week:
				last.clear()
			last_week = int(r.week)
			last_card = String(r.get("card", ""))
			last.append(CareerHub._result_line(w, r))
	if not last.is_empty():
		var results := _rich(15)
		results.text = "[color=%s]Last %s card, %s:[/color] %s" % [CareerHub.DIM.to_html(false), Weight.name_of(division).to_lower(), last_card, " ".join(last)]
		box.add_child(results)
	return card


## A small poster for one card: its name, the date and city, in the promotion's colour; HIS FIGHT when he's on it.
func _poster(w: World, p: Dictionary, week: int, colour: Color, mine: bool) -> Control:
	var card: Dictionary = Promotions.card(w, p, week)
	var poster := PanelContainer.new()
	poster.custom_minimum_size = Vector2(150.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = colour.darkened(0.62)
	style.border_color = CareerHub.GOOD if mine else colour.darkened(0.2)
	style.set_border_width_all(2 if mine else 1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	poster.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	poster.add_child(box)
	var name := Label.new()
	DisplayFont.apply(name, 22)
	name.text = String(card.get("short", ""))
	name.add_theme_color_override("font_color", colour.lightened(0.35))
	box.add_child(name)
	var when := FightNightCard._label(14, CareerHub.TEXT)
	when.text = "%s · %s" % [career.short_date(week, 5), String(card.get("city", ""))]
	box.add_child(when)
	if mine:
		var his := FightNightCard._label(14, CareerHub.GOOD)
		DisplayFont.apply(his, 16)
		his.text = "HIS FIGHT"
		box.add_child(his)
	return poster


# --- History ------------------------------------------------------------------------------------------------------


func _build_history() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	_history_strip = HBoxContainer.new()
	_history_strip.add_theme_constant_override("separation", 8)
	page.add_child(_history_strip)
	_home_legend = _rich(17)
	page.add_child(_home_legend)
	_history_title = Label.new()
	DisplayFont.apply(_history_title, 26)
	_history_title.add_theme_color_override("font_color", CareerHub.WARN)
	page.add_child(_history_title)
	timeline = BeltTimeline.new()
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.man_picked.connect(show_man)
	page.add_child(timeline)
	var legends := Label.new()
	DisplayFont.apply(legends, 26)
	legends.add_theme_color_override("font_color", CareerHub.WARN)
	legends.text = "LEGENDS"
	page.add_child(legends)
	var about := FightNightCard._label(15, CareerHub.DIM)
	about.text = "The world organisation's champions, and anyone who defended a belt %d times, in every division." % History.LEGEND_DEFENCES
	page.add_child(about)
	_legends = GridContainer.new()
	_legends.columns = 3
	_legends.add_theme_constant_override("h_separation", 12)
	_legends.add_theme_constant_override("v_separation", 12)
	_legends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_legends)
	return scroll


## The reigns of this promotion's belt in his division, for the timeline: [id, name, won, lost, defences, how], newest
## first.
static func reigns(c: Career, promotion: String) -> Array:
	var w: World = c.world()
	var out: Array = []
	for r: Array in History.line_of(w, Rankings.key(promotion, c.division_now())):
		var id: String = String(r[0])
		var how: String = { "lost": "lost it", "retired": "retired", "stripped": "stripped", "called up": "called up", "left": "moved on" }.get(String(r[4]), "")
		out.append([id, c.fighter_name() if id == Career.FIGHTER_ID else String(w.man(id).get("name", "")), int(r[1]), int(r[2]), int(r[3]), how])
	return out


func _fill_history() -> void:
	var c: Career = career
	var w: World = c.world()
	var p: Dictionary = Promotions.by_id(w, promotion_id)
	_home_legend.text = CareerHub.home_legend_text(c)
	_home_legend.visible = _home_legend.text != ""
	_history_title.text = "%s %s CHAMPIONS" % [String(p.get("name", "")).to_upper(), Weight.name_of(c.division_now()).to_upper()]
	timeline.show_reigns(reigns(c, promotion_id), PromotionBadge.colour_of(w, p), c.week, c.year_of)
	for child in _legends.get_children():
		child.queue_free()
	var legends: Array = History.legends(w)
	for id: String in legends.slice(0, History.LEGENDS_SHOWN):
		_legends.add_child(_legend_card(c, w, id))
	if legends.is_empty():
		var none := FightNightCard._label(16, CareerHub.DIM)
		none.text = "None yet."
		_legends.add_child(none)


func _legend_card(c: Career, w: World, id: String) -> Control:
	var mine: bool = id == Career.FIGHTER_ID
	var m: Dictionary = w.man(id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style: StyleBoxFlat = FightHud._panel_style(CareerHub.CARD)
	style.border_width_top = 3
	style.border_color = CareerHub.GOOD if mine else PromotionBadge.WORLD_GOLD
	card.add_theme_stylebox_override("panel", style)
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			show_man(id))
	var text := _rich(15)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var belts: Array[String] = legend_belts(w, id)
	var name: String = c.fighter_name() if mine else String(m.get("name", ""))
	var status: String = "still fighting" if mine or World.active(m) else "retired %d" % c.year_of(int(m.retired))
	text.text = "[font_size=20][b]%s[/b][/font_size]\n%s · %s · %s\n[color=%s]%s[/color]" % [name,
		String(c.about.get("country", "")) if mine else String(m.get("country", "")), c.record_text(true) if mine else World.record_text(m),
		status, CareerHub.WARN.to_html(false), " · ".join(belts)]
	card.add_child(text)
	return card


## The belts a legend held, each once: "ACL middleweight, 3 reigns, 5 defences" (or "ACL bantamweight, 17 defences").
static func legend_belts(w: World, id: String) -> Array[String]:
	var order: Array[String] = []
	var count: Dictionary = {}
	var defences: Dictionary = {}
	for r: Array in History.reigns_of(w, id):
		var k: String = String(r[0])
		if not count.has(k):
			order.append(k)
			count[k] = 0
			defences[k] = 0
		count[k] += 1
		defences[k] += int(r[3])
	var out: Array[String] = []
	for k: String in order:
		var bits: Array[String] = ["%s %s" % [String(Promotions.by_id(w, k.get_slice(":", 0)).get("short", "")), Weight.name_of(k.get_slice(":", 1)).to_lower()]]
		if int(count[k]) > 1:
			bits.append("%d reigns" % int(count[k]))
		if int(defences[k]) > 0:
			bits.append("%d defence%s" % [int(defences[k]), "" if int(defences[k]) == 1 else "s"])
		out.append(", ".join(bits))
	return out


# --- Shared -------------------------------------------------------------------------------------------------------


## Fills the promotion badge strips over Rankings and History.
func _fill_strips() -> void:
	var w: World = career.world()
	for pair: Array in [[_rank_strip, _rank_strip_buttons], [_history_strip, _history_strip_buttons]]:
		var strip: HBoxContainer = pair[0]
		var buttons: Dictionary = pair[1]
		for child in strip.get_children():
			child.queue_free()
		buttons.clear()
		var group := ButtonGroup.new()
		for p: Dictionary in ordered(w):
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = group
			b.tooltip_text = String(p.name)
			b.custom_minimum_size = Vector2(0.0, PROMOTION_BADGE.y + 14.0)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_anchors_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 8.0
			row.offset_right = -10.0
			b.add_child(row)
			var badge_w: float = PROMOTION_BADGE.x * (1.5 if PromotionBadge.shape_of(p) == PromotionBadge.PLATE else 1.0)
			var badge := PromotionBadge.new(Vector2(badge_w, PROMOTION_BADGE.y))
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.show_promotion(w, p)
			row.add_child(badge)
			var label := Label.new()
			DisplayFont.apply(label, 20)
			label.text = String(p.short)
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(label)
			var font: Font = DisplayFont.font()
			b.custom_minimum_size.x = 8.0 + badge_w + 8.0 + font.get_string_size(String(p.short), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 18.0
			var id: String = String(p.id)
			b.pressed.connect(func() -> void: show_promotion(id))
			b.set_pressed_no_signal(id == promotion_id)
			strip.add_child(b)
			buttons[id] = b


func _picked(tree: Tree) -> void:
	var item: TreeItem = tree.get_selected()
	if item != null and item.get_metadata(0) != null:
		show_man(String(item.get_metadata(0)))


func _tree(columns: Array) -> Tree:
	var tree := Tree.new()
	tree.columns = columns.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.add_theme_font_size_override("font_size", FONT_SIZE)
	tree.add_theme_font_size_override("title_button_font_size", 16)
	tree.add_theme_constant_override("v_separation", ROW_PAD)
	tree.add_theme_constant_override("h_separation", 8)
	tree.add_theme_color_override("font_color", CareerHub.TEXT)
	tree.add_theme_color_override("title_button_color", CareerHub.DIM)
	var panel := StyleBoxFlat.new()
	panel.bg_color = TABLE
	panel.set_content_margin_all(6)
	tree.add_theme_stylebox_override("panel", panel)
	var title := StyleBoxFlat.new()
	title.bg_color = CareerHub.CARD
	title.set_content_margin_all(6)
	tree.add_theme_stylebox_override("title_button_normal", title)
	var hover: StyleBoxFlat = title.duplicate()
	hover.bg_color = CareerHub.TILE
	tree.add_theme_stylebox_override("title_button_hover", hover)
	tree.add_theme_stylebox_override("title_button_pressed", hover)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(1.0, 1.0, 1.0, 0.10)
	tree.add_theme_stylebox_override("selected", selected)
	tree.add_theme_stylebox_override("selected_focus", selected)
	for i in columns.size():
		tree.set_column_title(i, String(columns[i][1]))
		tree.set_column_expand(i, true)
		tree.set_column_expand_ratio(i, int(columns[i][2]))
		tree.set_column_clip_content(i, true)
		tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
	return tree


func _rich(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", CareerHub.TEXT)
	return label


## A small gold belt (the champion's mark), drawn once.
static func belt_texture() -> ImageTexture:
	if _belt != null:
		return _belt
	var w: int = BELT_SIZE.x
	var h: int = BELT_SIZE.y
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var gold: Color = PromotionBadge.WORLD_GOLD
	var strap: Color = gold.darkened(0.5)
	for x in w:
		for y in range(int(h * 0.3), int(h * 0.7) + 1):
			image.set_pixel(x, y, strap)
	var c := Vector2(w * 0.5, h * 0.5)
	for x in w:
		for y in h:
			var d: Vector2 = (Vector2(x + 0.5, y + 0.5) - c) / Vector2(w * 0.3, h * 0.5)
			var r: float = d.length()
			if r <= 1.0:
				image.set_pixel(x, y, gold.lightened(0.3) if r > 0.8 else gold)
	_belt = ImageTexture.create_from_image(image)
	return _belt
