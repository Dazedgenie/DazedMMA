class_name PositionDiagram
extends Control
## A small top-down drawing of the ground position (D210, docs/06 §6.8): the man underneath lying
## with his head to the left, the man on top drawn over him, each in his corner's colour. It sits
## on the fight screen's left while the fight is on the ground, so the position reads at a glance
## even when the 3D bodies are tangled. In a submission it shows where the hold was locked from.

## The drawing's own size; it scales to fit its rect and keeps this shape.
const DESIGN := Vector2(100.0, 80.0)
const OUTLINE := Color(0.04, 0.05, 0.06)
const HEAD_RADIUS: float = 5.5
const TORSO_WIDTH: float = 7.0
const ARM_WIDTH: float = 3.2
const LEG_WIDTH: float = 4.0
## Each figure in DESIGN's box: head, hips, hands [lead, rear], knees and feet [lead, rear].
## "top" is the man on top (or fighter 0 in a scramble), "bottom" the man underneath; `top_under` draws the
## man on top first, under the other (the back, where he lies back with the other on him).
const POSES := {
	"full_guard": {  # On his knees between the legs; the legs wrapped round his waist, feet crossed behind.
		"bottom": { "head": Vector2(14, 40), "hips": Vector2(48, 40), "hands": [Vector2(34, 26), Vector2(34, 54)],
			"knees": [Vector2(62, 24), Vector2(62, 56)], "feet": [Vector2(80, 36), Vector2(80, 44)] },
		"top": { "head": Vector2(40, 40), "hips": Vector2(70, 40), "hands": [Vector2(26, 30), Vector2(26, 50)],
			"knees": [Vector2(76, 26), Vector2(76, 54)], "feet": [Vector2(93, 26), Vector2(93, 54)] },
	},
	"half_guard": {  # Chest on chest at an angle; one leg caught between his, the other free behind.
		"bottom": { "head": Vector2(14, 40), "hips": Vector2(48, 40), "hands": [Vector2(36, 22), Vector2(30, 56)],
			"knees": [Vector2(62, 30), Vector2(64, 58)], "feet": [Vector2(78, 52), Vector2(80, 46)] },
		"top": { "head": Vector2(30, 30), "hips": Vector2(62, 32), "hands": [Vector2(18, 46), Vector2(28, 16)],
			"knees": [Vector2(70, 47), Vector2(74, 20)], "feet": [Vector2(90, 50), Vector2(92, 15)] },
	},
	"side_control": {  # Across him from the side, chest on chest, knees in his ribs.
		"bottom": { "head": Vector2(14, 40), "hips": Vector2(48, 40), "hands": [Vector2(28, 54), Vector2(42, 26)],
			"knees": [Vector2(64, 32), Vector2(64, 50)], "feet": [Vector2(82, 36), Vector2(82, 48)] },
		"top": { "head": Vector2(30, 50), "hips": Vector2(36, 14), "hands": [Vector2(14, 30), Vector2(54, 34)],
			"knees": [Vector2(20, 22), Vector2(54, 22)], "feet": [Vector2(12, 8), Vector2(62, 8)] },
	},
	"mount": {  # Sat on his belly facing his head, knees by his ribs; his hands push on the hips.
		"bottom": { "head": Vector2(14, 40), "hips": Vector2(52, 40), "hands": [Vector2(44, 30), Vector2(44, 50)],
			"knees": [Vector2(68, 36), Vector2(68, 44)], "feet": [Vector2(88, 36), Vector2(88, 44)] },
		"top": { "head": Vector2(36, 40), "hips": Vector2(48, 40), "hands": [Vector2(24, 30), Vector2(24, 50)],
			"knees": [Vector2(40, 22), Vector2(40, 58)], "feet": [Vector2(58, 24), Vector2(58, 56)] },
	},
	"back_control": {  # He lies back under him, hooks in round the waist and arms round the neck (drawn underneath).
		"bottom": { "head": Vector2(32, 40), "hips": Vector2(64, 40), "hands": [Vector2(38, 28), Vector2(38, 52)],
			"knees": [Vector2(80, 34), Vector2(80, 46)], "feet": [Vector2(96, 32), Vector2(96, 48)] },
		"top": { "head": Vector2(16, 40), "hips": Vector2(46, 40), "hands": [Vector2(42, 33), Vector2(42, 47)],
			"knees": [Vector2(62, 22), Vector2(62, 58)], "feet": [Vector2(72, 35), Vector2(72, 45)] },
		"top_under": true,
	},
	"crucifix": {  # Across him from the head side, chest on his chest; his near arm trapped between the knees, the far one under an arm (D264).
		"bottom": { "head": Vector2(14, 40), "hips": Vector2(48, 40), "hands": [Vector2(30, 70), Vector2(26, 10)],
			"knees": [Vector2(64, 32), Vector2(64, 50)], "feet": [Vector2(82, 36), Vector2(82, 48)] },
		"top": { "head": Vector2(24, 24), "hips": Vector2(34, 56), "hands": [Vector2(26, 12), Vector2(10, 36)],
			"knees": [Vector2(22, 66), Vector2(42, 68)], "feet": [Vector2(12, 76), Vector2(54, 76)] },
	},
	"scramble": {  # Both up on their knees, hand fighting.
		"bottom": { "head": Vector2(60, 42), "hips": Vector2(76, 40), "hands": [Vector2(50, 34), Vector2(50, 52)],
			"knees": [Vector2(70, 28), Vector2(70, 52)], "feet": [Vector2(88, 30), Vector2(88, 50)] },
		"top": { "head": Vector2(40, 38), "hips": Vector2(24, 40), "hands": [Vector2(50, 28), Vector2(50, 46)],
			"knees": [Vector2(30, 28), Vector2(30, 52)], "feet": [Vector2(12, 30), Vector2(12, 50)] },
	},
}

## The position drawn ("" draws nothing) and the colours of the man on top and the man underneath.
var where: String = ""
var top_colour: Color = Color.WHITE
var bottom_colour: Color = Color.WHITE


## The position to draw for this fight right now: the ground position, or where a hold was locked
## from; "" standing, in the clinch, or in a leg lock (no drawing for those yet).
static func position_for(sim: FightSim) -> String:
	var at: String = sim.situation.position
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		if ActionLibrary.is_leg_lock(sim.actions.get_action(hold.action_id)):
			return ""
		at = String(hold.from)
	return at if POSES.has(at) else ""


## The fighter drawn on top: whoever has the top role (where the hold was locked from), fighter 0 otherwise.
static func top_fighter(sim: FightSim) -> int:
	var roles: Array = sim.situation.roles
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		roles = hold.from_roles
	return maxi(0, roles.find(PositionLibrary.TOP))


## Reads the fight and redraws if anything changed; `colours` are the corners' colours by fighter.
func show_fight(sim: FightSim, colours: Array[Color]) -> void:
	var now: String = position_for(sim)
	var top: int = top_fighter(sim)
	if now == where and top_colour == colours[top] and bottom_colour == colours[1 - top]:
		return
	where = now
	top_colour = colours[top]
	bottom_colour = colours[1 - top]
	queue_redraw()


func _draw() -> void:
	if not POSES.has(where):
		return
	var s: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	var origin: Vector2 = (size - DESIGN * s) / 2.0
	draw_set_transform(origin, 0.0, Vector2(s, s))
	var pose: Dictionary = POSES[where]
	if pose.get("top_under", false):
		_draw_figure(pose.top, top_colour)
		_draw_figure(pose.bottom, bottom_colour)
		_draw_figure(pose.top, top_colour, true)  # His arms round the other's neck stay on top.
	else:
		_draw_figure(pose.bottom, bottom_colour)
		_draw_figure(pose.top, top_colour)
	draw_set_transform(Vector2.ZERO)


## One stick figure: an outline pass, then the colour, so where they cross reads as over and under.
func _draw_figure(pose: Dictionary, colour: Color, arms_only: bool = false) -> void:
	var head: Vector2 = pose.head
	var hips: Vector2 = pose.hips
	var down: Vector2 = (hips - head).normalized()
	var across: Vector2 = down.orthogonal()
	var neck: Vector2 = head + down * HEAD_RADIUS
	var shoulders: Array[Vector2] = [neck + down * 3.0 + across * 5.0, neck + down * 3.0 - across * 5.0]
	var hip_joints: Array[Vector2] = [hips + across * 3.0, hips - across * 3.0]
	var limbs: Array = []  # [points, width]
	for side in 2:
		limbs.append([[shoulders[side], pose.hands[side]], ARM_WIDTH])
		if not arms_only:
			limbs.append([[hip_joints[side], pose.knees[side], pose.feet[side]], LEG_WIDTH])
	if not arms_only:
		limbs.append([[neck, hips], TORSO_WIDTH])
	var limb_colour: Color = colour.lightened(0.25)
	for pass_no in 2:
		for limb: Array in limbs:
			var width: float = float(limb[1]) + (2.5 if pass_no == 0 else 0.0)
			var tint: Color = OUTLINE if pass_no == 0 else (colour if limb[1] == TORSO_WIDTH else limb_colour)
			var points := PackedVector2Array(limb[0])
			draw_polyline(points, tint, width, true)
			for p: Vector2 in points:  # Round the joints and ends.
				draw_circle(p, width / 2.0, tint, true, -1.0, true)
		if not arms_only:
			draw_circle(head, HEAD_RADIUS + (1.25 if pass_no == 0 else 0.0), OUTLINE if pass_no == 0 else colour, true, -1.0, true)
