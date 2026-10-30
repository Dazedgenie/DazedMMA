class_name TaleOfTheTape
extends Control
## The middle of the fight setup (D172, docs/06 §6.7): the two fighters side by side, red on the left and blue on
## the right, like a broadcast's tale of the tape. The frame comes first (height, reach, stance, build; the
## longer or taller man's side lit in his corner's colour), then the headline stats (TAPE_STATS) as bars growing
## out from the middle. Your fighter's numbers are exact; the opponent's are scouted, so he shows only a grade and
## his bar is the whole band that grade covers. keys() is the few lines under it.

const FACT_H: float = 36.0
const STAT_H: float = 28.0
const DIVIDER_H: float = 18.0
const MIDDLE_W: float = 190.0
const VALUE_W: float = 96.0
const BAR_H: float = 10.0
const FONT_SIZE: int = 24
const LABEL_SIZE: int = 18
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const TRACK := Color("#2b3038")
const RED := Color("#ff6b6b")
const BLUE := Color("#5fa8ff")
## The stats on the tape, top to bottom (data/enums/stats ids): what decides most fights, across the game's sides.
const TAPE_STATS: Array[String] = ["speed", "cardio", "chin", "boxing", "kicking", "power", "takedowns", "takedown_defense",
	"top_control", "submissions"]
## A frame difference this big (cm) is worth a key to the fight.
const FRAME_EDGE_CM: int = 5
## Grade steps apart before a stat is worth a key to the fight.
const STAT_EDGE_STEPS: int = 2

## { label, red, blue, edge (-1 red's, 1 blue's, 0 neither) } or { divider } or
## { stat, name, red_value, red_grade, blue_grade, blue_low, blue_high }, top to bottom.
var rows: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


## Fills the tape from two fighter@1 profiles.
func show_fighters(red: Dictionary, blue: Dictionary) -> void:
	rows.clear()
	var rf: Dictionary = red.get("frame", {})
	var bf: Dictionary = blue.get("frame", {})
	for fact: Array in [["HEIGHT", "height_cm"], ["REACH", "reach_cm"]]:
		var r: int = int(rf.get(fact[1], 0))
		var b: int = int(bf.get(fact[1], 0))
		rows.append({ "label": fact[0], "red": "%d cm" % r, "blue": "%d cm" % b, "edge": signi(b - r) })
	rows.append({ "label": "STANCE", "red": String(red.get("stance", "")).capitalize(), "blue": String(blue.get("stance", "")).capitalize(), "edge": 0 })
	rows.append({ "label": "BUILD", "red": String(rf.get("build", "")).capitalize(), "blue": String(bf.get("build", "")).capitalize(), "edge": 0 })
	rows.append({ "divider": true })
	for id in TAPE_STATS:
		var r_value: float = stat(red, id)
		var b_value: float = stat(blue, id)
		var band: Array = grade_band(b_value)
		rows.append({ "stat": id, "name": TrainingCamp.STAT_NAMES[id], "red_value": r_value, "red_grade": TrainingCamp.grade(r_value),
			"blue_grade": TrainingCamp.grade(b_value), "blue_low": band[0], "blue_high": band[1] })
	var h: float = 0.0
	for row in rows:
		h += _row_h(row)
	custom_minimum_size.y = h
	queue_redraw()


## The tape as text (tests read it).
func text() -> String:
	var lines: Array[String] = []
	for row in rows:
		if row.has("label"):
			lines.append("%s %s | %s" % [row.label, row.red, row.blue])
		elif row.has("stat"):
			lines.append("%s %d %s | %s" % [row.name, roundi(row.red_value), row.red_grade, row.blue_grade])
	return "\n".join(lines)


## A stat of this profile (one it doesn't list counts as FighterState.DEFAULT_STAT).
static func stat(profile: Dictionary, id: String) -> float:
	return float(profile.get("stats", {}).get(id, FighterState.DEFAULT_STAT))


## The range [low, high) a value's letter grade covers (docs/11 §2.4).
static func grade_band(value: float) -> Array:
	var high: float = 100.0
	for entry: Array in TrainingCamp.GRADES:
		if value >= entry[0]:
			return [float(entry[0]), high]
		high = entry[0]
	return [0.0, high]


## The keys to the fight for the red corner: a frame edge, the biggest stat gaps each way, then the scouting card's
## how-to-beat (`scouting`, from the opponent's style sheet, may be empty).
static func keys(red: Dictionary, blue: Dictionary, scouting: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var reach: int = int(blue.get("frame", {}).get("reach_cm", 0)) - int(red.get("frame", {}).get("reach_cm", 0))
	var height: int = int(blue.get("frame", {}).get("height_cm", 0)) - int(red.get("frame", {}).get("height_cm", 0))
	if reach >= FRAME_EDGE_CM:
		out.append("He has %d cm more reach: close the distance or he picks you off." % reach)
	elif reach <= -FRAME_EDGE_CM:
		out.append("You have %d cm more reach: keep him on the end of your strikes." % -reach)
	elif absi(height) >= FRAME_EDGE_CM:
		out.append("He's %d cm %s than you." % [absi(height), "taller" if height > 0 else "shorter"])
	var southpaws: Array = [red.get("stance", "") == "southpaw", blue.get("stance", "") == "southpaw"]
	if southpaws[1] and not southpaws[0]:
		out.append("He's a southpaw: mind his left hand.")
	elif southpaws[0] and not southpaws[1]:
		out.append("You're the southpaw: he has to deal with your left hand.")
	var best: String = ""
	var worst: String = ""
	var best_gap: int = 0
	var worst_gap: int = 0
	for id in TAPE_STATS:
		var gap: int = _grade_steps(stat(red, id)) - _grade_steps(stat(blue, id))
		if gap > best_gap:
			best_gap = gap
			best = id
		if gap < worst_gap:
			worst_gap = gap
			worst = id
	if best_gap >= STAT_EDGE_STEPS:
		out.append("A big edge to you in %s (%s against his %s): take it there." % [String(TrainingCamp.STAT_NAMES[best]).to_lower(),
			TrainingCamp.grade(stat(red, best)), TrainingCamp.grade(stat(blue, best))])
	if worst_gap <= -STAT_EDGE_STEPS:
		out.append("A big edge to him in %s (%s against your %s): don't fight him there." % [String(TrainingCamp.STAT_NAMES[worst]).to_lower(),
			TrainingCamp.grade(stat(blue, worst)), TrainingCamp.grade(stat(red, worst))])
	if String(scouting.get("how_to_beat", "")) != "":
		out.append("Scouting: " + String(scouting.how_to_beat))
	return out


## How many grades from the bottom this value is (F is 0).
static func _grade_steps(value: float) -> int:
	for i in TrainingCamp.GRADES.size():
		if value >= TrainingCamp.GRADES[i][0]:
			return TrainingCamp.GRADES.size() - 1 - i
	return 0


func _row_h(row: Dictionary) -> float:
	if row.has("divider"):
		return DIVIDER_H
	return STAT_H if row.has("stat") else FACT_H


func _draw() -> void:
	var display: Font = DisplayFont.font()
	var mid_x: float = (size.x - MIDDLE_W) * 0.5
	var bar_w: float = maxf(20.0, mid_x - VALUE_W - 12.0)
	var y: float = 0.0
	for row in rows:
		var h: float = _row_h(row)
		if row.has("divider"):
			draw_line(Vector2(0.0, y + h * 0.5), Vector2(size.x, y + h * 0.5), TRACK, 2.0)
		elif row.has("label"):
			var base_line: float = y + h * 0.5 + FONT_SIZE * 0.35
			var edge: int = int(row.edge)
			draw_string(display, Vector2(0.0, base_line), String(row.red), HORIZONTAL_ALIGNMENT_RIGHT, mid_x - 12.0, FONT_SIZE,
				RED if edge < 0 else TEXT)
			draw_string(display, Vector2(mid_x, y + h * 0.5 + LABEL_SIZE * 0.35), String(row.label), HORIZONTAL_ALIGNMENT_CENTER,
				MIDDLE_W, LABEL_SIZE, DIM)
			draw_string(display, Vector2(mid_x + MIDDLE_W + 12.0, base_line), String(row.blue), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
				BLUE if edge > 0 else TEXT)
		else:
			var base_line: float = y + h * 0.5 + FONT_SIZE * 0.35
			var bar_y: float = y + (h - BAR_H) * 0.5
			# Red's bar grows left from the middle, to his exact average.
			var red_right: float = mid_x - 6.0
			draw_rect(Rect2(red_right - bar_w, bar_y, bar_w, BAR_H), TRACK)
			var red_len: float = bar_w * clampf(float(row.red_value), 0.0, 100.0) / 100.0
			draw_rect(Rect2(red_right - red_len, bar_y, red_len, BAR_H), RED)
			draw_string(display, Vector2(0.0, base_line), "%d %s" % [roundi(float(row.red_value)), row.red_grade],
				HORIZONTAL_ALIGNMENT_LEFT, VALUE_W, FONT_SIZE, TEXT)
			# Blue's grows right; scouted, so it's solid to his grade's floor and faint across the rest of the band.
			var blue_left: float = mid_x + MIDDLE_W + 6.0
			draw_rect(Rect2(blue_left, bar_y, bar_w, BAR_H), TRACK)
			var low: float = bar_w * float(row.blue_low) / 100.0
			var high: float = bar_w * float(row.blue_high) / 100.0
			draw_rect(Rect2(blue_left, bar_y, low, BAR_H), BLUE)
			draw_rect(Rect2(blue_left + low, bar_y, high - low, BAR_H), Color(BLUE, 0.35))
			draw_string(display, Vector2(size.x - VALUE_W, base_line), String(row.blue_grade), HORIZONTAL_ALIGNMENT_RIGHT,
				VALUE_W, FONT_SIZE, TEXT)
			draw_string(display, Vector2(mid_x, y + h * 0.5 + LABEL_SIZE * 0.35), String(row.name).to_upper(),
				HORIZONTAL_ALIGNMENT_CENTER, MIDDLE_W, LABEL_SIZE, DIM)
		y += h
