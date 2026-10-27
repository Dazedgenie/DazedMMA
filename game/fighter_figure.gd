class_name FighterFigure
extends Node3D
## One grey-box fighter in the 3D fight view (#19, D80, docs/10 §1): a capsule body,
## a head, and stick arms and legs that act out the move in progress, so a jab, a
## body kick, a shot and a sprawl each look different from above.
##
## Over the head (docs/06 §2): the move's name (coloured by phase), the delay ring
## while a call is being processed (it shrinks as the fighter gets to it), "nah" when
## a call is ignored, READ while a read call is primed, and stars when rocked. The
## tell cue (D51) lights the limb that's about to go when a scouted tell shows.
## Presentation only: it reads the fight and never changes it.

## Body sizes, in metres (the cage is 9 m across, docs/01 §3).
const HIP_HEIGHT: float = 0.92
const TORSO_LENGTH: float = 0.62
const BODY_RADIUS: float = 0.2
const HEAD_RADIUS: float = 0.14
const LIMB_RADIUS: float = 0.065
const ARM_LENGTH: float = 0.55
const LEG_LENGTH: float = 0.9
const HIP_WIDTH: float = 0.12
const SHOULDER_WIDTH: float = 0.24
const OVERHEAD: float = 2.05
## How quickly the pose follows the move (per second; higher is snappier).
const POSE_SPEED: float = 14.0
## How far each phase of a move goes, as a share of the full extension.
const PHASE_REACH := { "telegraph": 0.3, "windup": 0.55, "active": 1.0, "recovery": 0.35 }
const PHASE_COLOURS := {
	"telegraph": Color("#ffe066"), "windup": Color("#ffa94d"), "active": Color("#ff6b6b"), "recovery": Color("#adb5bd"),
}
## Real seconds a "nah" (call ignored) stays up.
const IGNORED_SECONDS: float = 1.5
const TELL_COLOUR := Color("#fff3a0")
const RING_COLOUR := Color("#ffc94d")
const READ_COLOUR := Color("#66d9e8")

var colour: Color
## Overhead labels and marks are sized in metres; the view shrinks them as the camera moves in.
var label_scale: float = 1.0
## Lead side: -1 (left, orthodox) or +1 (southpaw), along the figure's own x.
var lead: float = -1.0

var _hips: Node3D
var _torso: MeshInstance3D
var _head: MeshInstance3D
var _arms: Array[Node3D] = []  # [lead, rear] shoulder pivots
var _legs: Array[Node3D] = []  # [lead, rear] hip pivots
var _arm_meshes: Array[Node3D] = []  # arm pivots at the shoulder (stretch from there)
var _leg_meshes: Array[Node3D] = []  # leg pivots at the hip
var _move_label: Label3D
var _call_label: Label3D
var _ring: MeshInstance3D
var _stars: Node3D
var _tell: MeshInstance3D
var _tell_label: Label3D
var _body_material: StandardMaterial3D
var _pose := {}
var _ignored_left: float = 0.0
var _time: float = 0.0


func _init(p_colour: Color = Color.WHITE, southpaw: bool = false) -> void:
	colour = p_colour
	lead = 1.0 if southpaw else -1.0
	_body_material = _material(colour)
	_build()
	_pose = _rest_pose()


## Puts the figure where the fighter is, facing `toward`, posed for what they're doing.
## `delta` is real seconds since the last frame (for smoothing).
func show_state(sim: FightSim, i: int, at: Vector2, toward: Vector2, delta: float) -> void:
	_time += delta
	var f: FighterState = sim.fighters[i]
	position = Vector3(at.x, 0.0, at.y)
	var facing: Vector2 = toward - at
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.y)
	var target: Dictionary = pose_for(sim, i)
	var k: float = 1.0 - exp(-POSE_SPEED * delta)
	for key: String in target:
		_pose[key] = lerpf(float(_pose.get(key, target[key])), float(target[key]), k)
	_apply_pose(f)
	_show_overhead(sim, i, delta)
	for label: Label3D in [_move_label, _call_label, _tell_label]:
		label.scale = Vector3.ONE * label_scale


## The pose (joint angles and heights) for fighter i right now: plain numbers, so it can be tested.
## Keys: hip_y, lean (radians, forward is negative), lie (0 standing, 1 flat on the back),
## arm_lead/arm_rear and leg_lead/leg_rear (radians forward from hanging down),
## reach_lead/reach_rear (arm stretch, 1 = normal).
func pose_for(sim: FightSim, i: int) -> Dictionary:
	var f: FighterState = sim.fighters[i]
	var p: Dictionary = _rest_pose()
	var role: String = sim.situation.role(i)
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		role = String(hold.from_roles[i])  # In a submission (D126): posed as where it was locked from.
	if f.is_down() or role == PositionLibrary.BOTTOM:
		p.lie = 1.0
		p.hip_y = 0.22
		p.arm_lead = 2.4
		p.arm_rear = 2.4
		p.leg_lead = 0.4
		p.leg_rear = 0.4
	elif role == PositionLibrary.TOP:
		p.hip_y = 0.6
		p.lean = -0.75
		p.leg_lead = 0.9
		p.leg_rear = 0.9
		p.arm_lead = 1.2
		p.arm_rear = 1.2
		if f.tied_up_ticks > 0:  # Pulled down into the guard (D121).
			p.lean = -1.1
			p.arm_lead = 0.6
			p.arm_rear = 0.6
	elif sim.situation.position == PositionLibrary.SCRAMBLE:
		p.hip_y = 0.6
		p.lean = -0.6
		p.leg_lead = 0.9
		p.leg_rear = 0.5
	elif not hold.is_empty():
		p.lean = -0.9 if int(hold.attacker) != i else -0.3  # The guillotine: head trapped under the arm.
		p.arm_lead = 1.75
		p.arm_rear = 1.75
	elif sim.situation.position == PositionLibrary.CLINCH:
		p.lean = -0.3
		p.arm_lead = 1.75
		p.arm_rear = 1.75
		p.reach_lead = 1.2
		p.reach_rear = 1.2
	if f.action_id == "" or not sim.actions.has(f.action_id):
		return p
	var reach: float = float(PHASE_REACH.get(f.phase, 0.0))
	var action: Dictionary = sim.actions.get_action(f.action_id)
	match f.action_id:
		"jab":
			p.arm_lead = lerpf(p.arm_lead, 1.57, reach)
			p.reach_lead = lerpf(1.0, 1.45, reach)
		"cross":
			p.arm_rear = lerpf(p.arm_rear, 1.57, reach)
			p.reach_rear = lerpf(1.0, 1.5, reach)
			p.lean = lerpf(p.lean, -0.2, reach)
		"hook":
			p.arm_lead = lerpf(p.arm_lead, 1.7, reach)
			p.reach_lead = lerpf(1.0, 1.2, reach)
			p.twist = lerpf(0.0, 0.5, reach)
		"leg_kick":
			p.leg_rear = lerpf(0.0, 0.9, reach)
			p.twist = lerpf(0.0, 0.4, reach)
		"body_kick":
			p.leg_rear = lerpf(0.0, 1.45, reach)
			p.twist = lerpf(0.0, 0.6, reach)
			p.lean = lerpf(p.lean, 0.25, reach)
		"head_kick":
			p.leg_rear = lerpf(0.0, 2.1, reach)
			p.twist = lerpf(0.0, 0.7, reach)
			p.lean = lerpf(p.lean, 0.4, reach)
		"teep":
			p.leg_lead = lerpf(0.0, 1.5, reach)
			p.lean = lerpf(p.lean, 0.2, reach)
		"knee":
			p.leg_rear = lerpf(p.leg_rear, 1.6, reach)
			p.knee_short = reach
		"double_leg", "catch_kick_single":
			p.hip_y = lerpf(p.hip_y, 0.5, reach)
			p.lean = lerpf(p.lean, -0.95, reach)
			p.arm_lead = lerpf(p.arm_lead, 1.5, reach)
			p.arm_rear = lerpf(p.arm_rear, 1.5, reach)
			p.leg_lead = lerpf(p.leg_lead, 0.8, reach)
		"sprawl":
			p.hip_y = lerpf(p.hip_y, 0.35, reach)
			p.lean = lerpf(p.lean, -1.25, reach)
			p.leg_lead = lerpf(p.leg_lead, -0.9, reach)
			p.leg_rear = lerpf(p.leg_rear, -1.0, reach)
		"stance_shift":
			p.hip_y = lerpf(p.hip_y, 0.75, maxf(reach, 0.6))
			p.lean = lerpf(p.lean, -0.3, maxf(reach, 0.6))
		"clinch_entry":
			p.arm_lead = lerpf(p.arm_lead, 1.7, reach)
			p.arm_rear = lerpf(p.arm_rear, 1.7, reach)
			p.reach_lead = lerpf(1.0, 1.3, reach)
			p.reach_rear = lerpf(1.0, 1.3, reach)
			p.lean = lerpf(p.lean, -0.35, reach)
		"clinch_break":
			p.arm_lead = lerpf(p.arm_lead, 1.4, reach)
			p.arm_rear = lerpf(p.arm_rear, 1.4, reach)
			p.lean = lerpf(p.lean, 0.3, reach)
		"get_up":
			p.lie = lerpf(p.lie, 0.0, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT, reach)
		"ground_punch":  # Postures up, then drives the rear hand down (D121).
			p.lean = lerpf(p.lean, -0.4, reach)
			p.arm_rear = lerpf(p.arm_rear, 0.5, reach)
			p.reach_rear = lerpf(1.0, 1.35, reach)
		"ground_elbow":
			p.lean = lerpf(p.lean, -0.35, reach)
			p.arm_rear = lerpf(p.arm_rear, 2.7 if f.phase == "telegraph" or f.phase == "windup" else 0.5, reach)
		"tie_up":
			p.arm_lead = lerpf(p.arm_lead, 3.0, reach)
			p.arm_rear = lerpf(p.arm_rear, 3.0, reach)
			p.reach_lead = lerpf(1.0, 1.3, reach)
			p.reach_rear = lerpf(1.0, 1.3, reach)
		_:
			if action.category == "strike":
				p.arm_lead = lerpf(p.arm_lead, 1.57, reach)
	return p


## Which body part a move is thrown with ("lead_arm", "rear_leg", "hips" …), for the tell cue.
static func limb_for(action_id: String) -> String:
	match action_id:
		"jab", "hook":
			return "lead_arm"
		"cross", "ground_punch", "ground_elbow":
			return "rear_arm"
		"teep":
			return "lead_leg"
		"leg_kick", "body_kick", "head_kick", "knee":
			return "rear_leg"
	return "hips"


## Lights up the limb a scouted tell says is coming (D51), or switches the cue off ("").
func show_tell(limb: String) -> void:
	_tell.visible = limb != ""
	_tell_label.visible = limb != ""
	if limb == "":
		return
	var at: Node3D = _hips
	var down: float = 0.0
	match limb:
		"lead_arm":
			at = _arm_meshes[0]
			down = ARM_LENGTH * 0.6
		"rear_arm":
			at = _arm_meshes[1]
			down = ARM_LENGTH * 0.6
		"lead_leg":
			at = _leg_meshes[0]
			down = LEG_LENGTH * 0.55
		"rear_leg":
			at = _leg_meshes[1]
			down = LEG_LENGTH * 0.55
	if _tell.get_parent() != at:
		_tell.reparent(at, false)
	_tell.position = Vector3(0.0, -down, 0.0)


## Shows "nah" over the fighter for a moment: they ignored a call.
func show_ignored() -> void:
	_ignored_left = IGNORED_SECONDS


func _show_overhead(sim: FightSim, i: int, delta: float) -> void:
	var f: FighterState = sim.fighters[i]
	# The move in progress, coloured by phase.
	if f.action_id != "" and sim.actions.has(f.action_id):
		_move_label.text = String(sim.actions.get_action(f.action_id).name)
		_move_label.modulate = PHASE_COLOURS.get(f.phase, Color.WHITE)
		_move_label.visible = true
	else:
		_move_label.visible = false
	# The delay ring: a call heard and not acted on yet. Shrinks as the fighter gets to it.
	var calls: LiveCalls = sim.decisions[i].calls
	var left: float = -1.0
	for heard: Dictionary in calls.pending:
		var total: float = maxf(1.0, float(heard.ready_at - heard.heard))
		left = maxf(left, clampf(float(heard.ready_at - sim.now) / total, 0.0, 1.0))
	_ring.visible = left >= 0.0
	if _ring.visible:
		var s: float = lerpf(0.35, 1.0, left)
		_ring.scale = Vector3(s, 1.0, s)
	_ignored_left = maxf(0.0, _ignored_left - delta)
	if _ignored_left > 0.0:
		_call_label.text = "nah"
		_call_label.modulate = Color("#ff8787")
		_call_label.visible = true
	elif not calls.reads.is_empty():
		_call_label.text = "READ"
		_call_label.modulate = READ_COLOUR
		_call_label.visible = true
	else:
		_call_label.visible = false
	_stars.visible = f.is_rocked() and not f.is_down()
	if _stars.visible:
		_stars.rotation.y = _time * 4.0
	if _tell.visible:
		var pulse: float = 0.6 + 0.4 * sin(_time * 12.0)
		(_tell.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5 + 2.0 * pulse


func _apply_pose(f: FighterState) -> void:
	var lie: float = _pose.lie
	_hips.position.y = _pose.hip_y
	var sway: float = 0.0
	if f.is_rocked() and not f.is_down():
		sway = 0.18 * sin(_time * 7.0)
	_hips.rotation = Vector3(lerpf(_pose.lean, PI / 2.0, lie), _pose.twist * lead, sway)
	_arms[0].rotation.x = _pose.arm_lead
	_arms[1].rotation.x = _pose.arm_rear
	_arm_meshes[0].scale.y = _pose.reach_lead
	_arm_meshes[1].scale.y = _pose.reach_rear
	_legs[0].rotation.x = _pose.leg_lead
	_legs[1].rotation.x = _pose.leg_rear
	_leg_meshes[1].scale.y = lerpf(1.0, 0.55, _pose.knee_short)
	_body_material.albedo_color = colour.darkened(0.45) if f.is_down() else colour


static func _rest_pose() -> Dictionary:
	return { "hip_y": HIP_HEIGHT, "lean": -0.08, "lie": 0.0, "twist": 0.0, "arm_lead": 2.0, "arm_rear": 1.85,
		"leg_lead": 0.12, "leg_rear": -0.12, "reach_lead": 1.0, "reach_rear": 1.0, "knee_short": 0.0 }


func _build() -> void:
	_hips = Node3D.new()
	_hips.position.y = HIP_HEIGHT
	add_child(_hips)
	_torso = _capsule(BODY_RADIUS, TORSO_LENGTH + BODY_RADIUS, _body_material)
	_torso.position.y = TORSO_LENGTH / 2.0 + 0.05
	_hips.add_child(_torso)
	_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = HEAD_RADIUS
	head_mesh.height = HEAD_RADIUS * 2.0
	_head.mesh = head_mesh
	_head.material_override = _body_material
	_head.position.y = TORSO_LENGTH / 2.0 + HEAD_RADIUS + 0.12
	_torso.add_child(_head)
	var limb_material: StandardMaterial3D = _material(colour.lightened(0.25))
	for side: float in [lead, -lead]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * SHOULDER_WIDTH, TORSO_LENGTH / 2.0 - 0.02, 0.0)
		_torso.add_child(shoulder)
		var arm: MeshInstance3D = _capsule(LIMB_RADIUS, ARM_LENGTH, limb_material)
		arm.position.y = -ARM_LENGTH / 2.0
		var arm_pivot := Node3D.new()  # Stretches from the shoulder, not the arm's middle.
		arm_pivot.add_child(arm)
		shoulder.add_child(arm_pivot)
		_arms.append(shoulder)
		_arm_meshes.append(arm_pivot)
		var hip := Node3D.new()
		hip.position = Vector3(side * HIP_WIDTH, 0.0, 0.0)
		_hips.add_child(hip)
		var leg: MeshInstance3D = _capsule(LIMB_RADIUS * 1.25, LEG_LENGTH, limb_material)
		leg.position.y = -LEG_LENGTH / 2.0
		var leg_pivot := Node3D.new()
		leg_pivot.add_child(leg)
		hip.add_child(leg_pivot)
		_legs.append(hip)
		_leg_meshes.append(leg_pivot)

	_move_label = _label(44)
	_move_label.position.y = OVERHEAD + 0.32
	add_child(_move_label)
	_call_label = _label(40)
	_call_label.position.y = OVERHEAD + 0.62
	add_child(_call_label)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.32
	_ring.mesh = torus
	var ring_material: StandardMaterial3D = _material(RING_COLOUR)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_material
	_ring.position.y = OVERHEAD
	_ring.visible = false
	add_child(_ring)

	_stars = Node3D.new()
	_stars.position.y = OVERHEAD - 0.05
	var star_material: StandardMaterial3D = _material(Color("#ffe066"))
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for n in 3:
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		star_mesh.radius = 0.05
		star_mesh.height = 0.1
		star.mesh = star_mesh
		star.material_override = star_material
		star.position = Vector3.FORWARD.rotated(Vector3.UP, n * TAU / 3.0) * 0.25
		_stars.add_child(star)
	_stars.visible = false
	add_child(_stars)

	_tell = MeshInstance3D.new()
	var glow := SphereMesh.new()
	glow.radius = 0.16
	glow.height = 0.32
	_tell.mesh = glow
	var glow_material: StandardMaterial3D = _material(TELL_COLOUR)
	glow_material.emission_enabled = true
	glow_material.emission = TELL_COLOUR
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color.a = 0.7
	glow_material.no_depth_test = true
	_tell.material_override = glow_material
	_tell.visible = false
	_hips.add_child(_tell)
	# Shape as well as colour (colour-blind safe, docs/06 §2): a "!" over the fighter.
	_tell_label = _label(72)
	_tell_label.text = "!"
	_tell_label.modulate = TELL_COLOUR
	_tell_label.position = Vector3(0.0, OVERHEAD + 0.05, 0.0)
	_tell_label.visible = false
	add_child(_tell_label)


static func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


static func _capsule(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 4
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node


static func _label(font_size: int) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.0045
	label.font_size = font_size
	label.outline_size = 14
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.render_priority = 10
	label.outline_render_priority = 9
	label.visible = false
	return label
