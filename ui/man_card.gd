class_name ManCard
extends PanelContainer
## The side card for one man on the world pages (docs/06 §6.12, D432; Kyle's pick on the D432 cards): his head-and-chest
## portrait (D431), name and nickname, record, age and where he's from, his level, promotion (with its badge) and rank,
## his style, frame and grade, how it went if you've fought him, what you've scouted on him (D401) and his last few
## fights. Opened by clicking a man in any table; Close or Esc shuts it.

signal closed

const WIDTH: float = 420.0
const PORTRAIT_SIZE := Vector2(180.0, 220.0)
## His last fights listed, newest first (from the world's results, which keep the last World.RESULTS_WEEKS weeks).
const LAST_FIGHTS: int = 5
const CARD := Color("#1b1f26")

var career: Career
var id: String = ""
var portrait: FighterPortrait
var badge: PromotionBadge
var _name: Label
var _nick: Label
var _text: RichTextLabel
var _promotion: Label
var _promotion_row: HBoxContainer
var _groups: Dictionary = {}


func _init() -> void:
	custom_minimum_size.x = WIDTH
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(18)
	style.border_width_left = 2
	style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	portrait = FighterPortrait.new(FighterPortrait.BUST, 1, -12.0)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	top.add_child(portrait)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(close_card)
	names.add_child(close)
	_name = Label.new()
	DisplayFont.apply(_name, 32)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_color_override("font_color", CareerHub.TEXT)
	names.add_child(_name)
	_nick = FightNightCard._label(17, CareerHub.WARN)
	names.add_child(_nick)
	_promotion_row = HBoxContainer.new()
	_promotion_row.add_theme_constant_override("separation", 8)
	names.add_child(_promotion_row)
	badge = PromotionBadge.new(Vector2(34.0, 34.0))
	_promotion_row.add_child(badge)
	_promotion = FightNightCard._label(16, CareerHub.DIM)
	_promotion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promotion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_promotion_row.add_child(_promotion)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.add_theme_color_override("default_color", CareerHub.TEXT)
	scroll.add_child(_text)
	_groups = CareerHub._enum("stats")
	visible = false


## Shows this man of the career's world (Career.FIGHTER_ID for him).
func show_man(c: Career, man_id: String) -> void:
	career = c
	id = man_id
	var w: World = c.world()
	var mine: bool = man_id == Career.FIGHTER_ID
	var m: Dictionary = {} if mine else w.man(man_id)
	if not mine and m.is_empty():
		return
	var profile: Dictionary = c.profile() if mine else w.profile(man_id, c.week)
	portrait.corner = 0 if mine else 1
	portrait.show_fighter(profile)
	_name.text = c.fighter_name() if mine else String(m.get("name", ""))
	var nick: String = String(c.about.get("nickname", "")) if mine else String(m.get("nickname", ""))
	_nick.text = ("'%s'" % nick) if nick != "" else ""
	_nick.visible = nick != ""
	var p: Dictionary = Promotions.by_id(w, String(w.him.get("promotion", ""))) if mine else Promotions.of(w, m)
	_promotion_row.visible = not p.is_empty()
	if not p.is_empty():
		badge.show_promotion(w, p)
		_promotion.text = String(p.get("name", ""))
	_text.text = text_for(c, man_id)
	visible = true


## His card's words (see the top): the lines under his name.
func text_for(c: Career, man_id: String) -> String:
	var w: World = c.world()
	var dim: String = CareerHub.DIM.to_html(false)
	var lines: Array[String] = []
	if man_id == Career.FIGHTER_ID:
		lines.append("[b]%s[/b] · %s · age %d" % [c.record_text(c.pro), "pro" if c.pro else "amateur", c.age()])
		lines.append("From %s, %s" % [String(c.about.get("hometown", "")), String(c.about.get("country", ""))])
		var rank: String = CareerHub.his_rank_text(c)
		if rank != "":
			lines.append(rank)
		lines.append("[color=%s]Your fighter[/color]" % CareerHub.GOOD.to_html(false))
		return "\n".join(lines)
	var m: Dictionary = w.man(man_id)
	var age: int = int(floor(World.age_of(m, c.week)))
	var status: String = "" if World.active(m) else " · retired %d" % c.year_of(int(m.retired))
	lines.append("[b]%s[/b] · %s · age %d%s" % [World.record_text(m), World.level_name(m) if bool(m.get("pro", false)) else "amateur", age, status])
	lines.append("From %s, %s" % [String(m.get("hometown", "")), String(m.get("country", ""))])
	var ranked: String = CareerHub.opponent_rank_text(c, man_id) if c.pro else ""
	if ranked == "" and Rankings.rank_of(w, man_id) > 0:
		ranked = "[color=%s]Ranked %s[/color]" % [CareerHub.GOOD.to_html(false), Rankings.rank_text(w, man_id)]
	if ranked != "":
		lines.append(ranked)
	elif History.former_tag(w, man_id) != "":
		lines.append("[color=%s]A %s[/color]" % [CareerHub.WARN.to_html(false), History.former_tag(w, man_id)])
	var style_id: String = String(m.get("style", ""))
	var style_name: String = String(StyleLibrary.shared().get_style(style_id).get("name", style_id)) if StyleLibrary.shared().has(style_id) else style_id
	var frame: Dictionary = m.get("frame", {})
	lines.append("%s · %d cm · grade %s" % [style_name, int(frame.get("height_cm", 0)), TrainingCamp.grade(w.average(m))])
	for f: Dictionary in c.fights:
		if String(f.get("opponent", "")) == man_id:
			var result: String = String(f.get("result", ""))
			lines.append("[color=%s]%s[/color]" % [(CareerHub.GOOD if result == "win" else CareerHub.BAD if result == "loss" else CareerHub.WARN).to_html(false),
				{ "win": "You beat him", "loss": "He beat you", "draw": "You drew with him" }.get(result, "You fought him")])
	var profile: Dictionary = w.profile(man_id, c.week)
	lines.append("")
	lines.append("[color=%s]SCOUTED[/color]" % dim)
	lines.append(Scouting.report_text(c, profile, _groups, CareerHub.SCOUTED_GROUPS))
	var last: Array[String] = last_fights(c, man_id)
	if not last.is_empty():
		lines.append("")
		lines.append("[color=%s]LAST FIGHTS[/color]" % dim)
		lines.append_array(last)
	return "\n".join(lines)


## His last few fights in the world's results, newest first: "W · beat Tom Hill by knockout in round 1 · Mar 2027".
static func last_fights(c: Career, man_id: String) -> Array[String]:
	var w: World = c.world()
	var out: Array[String] = []
	for i in range(w.results.size() - 1, -1, -1):
		var r: Dictionary = w.results[i]
		if String(r.get("kind", "fight")) != "fight" or (String(r.get("a", "")) != man_id and String(r.get("b", "")) != man_id):
			continue
		var side: String = "a" if String(r.a) == man_id else "b"
		var other: String = String(r.b) if side == "a" else String(r.a)
		var other_name: String = c.fighter_name() if other == Career.FIGHTER_ID else Rankings.name_of(w, other)
		var how: String = CareerHub._how(String(r.get("method", "")), int(r.get("round", 1)))
		var when: String = c.short_date(int(r.week))
		var line: String
		if String(r.winner) == "draw":
			line = "[color=%s]D[/color] · drew with %s · %s" % [CareerHub.WARN.to_html(false), other_name, when]
		elif String(r.winner) == side:
			line = "[color=%s]W[/color] · beat %s %s · %s" % [CareerHub.GOOD.to_html(false), other_name, how, when]
		else:
			line = "[color=%s]L[/color] · lost to %s %s · %s" % [CareerHub.BAD.to_html(false), other_name, how, when]
		out.append(line)
		if out.size() >= LAST_FIGHTS:
			break
	return out


func close_card() -> void:
	visible = false
	closed.emit()
