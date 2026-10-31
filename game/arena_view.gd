class_name ArenaView
extends Node3D
## The local-fight-night view (docs/13): a low-poly octagon seen through a
## three-quarter perspective camera, the two fighters (FighterFigure), the range or
## position tag on the canvas between them, and the camera moving in for the clinch
## and the ground. Presentation only: it reads the fight through the FightDriver.
##
## Sim spots are metres on the canvas: sim (x, y) is 3D (x, 0, y), the cage's centre
## is the origin, and the fence panels face the axes and diagonals (Octagon.NORMALS).
## The debug overlay (F3) adds what the old top-down cage view (D106) showed: the
## near-the-fence and pinned lines and the distance each fighter is walking toward.

const FIGHTER_COLOURS: Array[Color] = [Color("#e8484a"), Color("#3d8bff")]
## Vertical metres of view at the focus point, standing, in the clinch, and on the ground.
const ZOOM_STANDING: float = 5.8
const ZOOM_CLINCH: float = 4.8
const ZOOM_GROUND: float = 4.6
## How fast the camera follows and zooms (per second).
const CAMERA_SPEED: float = 2.5
## The camera follows this share of the way from the cage's centre to the fighters.
const FOLLOW_SHARE: float = 0.85
## Lower three-quarter view, about 28° down; enough elevation to read grappling.
const CAMERA_FROM := Vector3(1.0, 0.76, 1.0)
const TAG_COLOURS := {
	"out": Color("#adb5bd"), "long": Color("#69db7c"), "mid": Color("#ffd43b"),
	"pocket": Color("#ffa94d"), "clinch": Color("#da77f2"),
}
const TAG_NAMES := { "out": "Out of range", "long": "Long range", "mid": "Mid range", "pocket": "Pocket", "clinch": "Clinch" }
## Where the top fighter is against the man underneath in each ground position (D210), in the bottom man's
## own frame: `at` is (metres from his hips toward his feet, metres to his side; negative along is toward
## his head; positive across is his side away from the camera) and `face` the way the top man faces
## (Vector2(1, 0) faces the same way as him, toward his feet). He lies across the screen, or with
## `facing_camera` sits facing it.
## The sim only knows the two are tangled up; the view lays them out. A position not here (and leg locks)
## keeps them face to face, as the sim has them.
const GROUND_LAYOUTS := {
	"full_guard": { "at": Vector2(0.55, 0.0), "face": Vector2(-1.0, 0.0) },
	"half_guard": { "at": Vector2(0.2, 0.25), "face": Vector2(-1.0, -0.45) },
	"side_control": { "at": Vector2(-0.35, 0.55), "face": Vector2(0.0, -1.0) },
	"mount": { "at": Vector2(-0.2, 0.0), "face": Vector2(-1.0, 0.0) },
	"back_control": { "at": Vector2(-0.5, 0.0), "face": Vector2(1.0, 0.0), "facing_camera": true },
}
## The man underneath lies across the screen, feet turned this far (radians) away from the camera (D210).
const LIE_TURN: float = 0.45
## How fast a fighter slides and turns to his spot in a new position (per second).
const LAYOUT_SPEED: float = 6.0
## Space for the two leaning torsos in the clinch; affects only their drawn positions.
const CLINCH_BODY_GAP: float = 0.82
## The tag grows this much when the range or position changes, then settles (docs/06 §2).
const TAG_BUMP: float = 1.7
## Standing, the sim's ranges are wider than a person's reach (pocket up to 1.5 m, long range 3 m apart), so
## the view draws the gap at human scale (D281): a gap of DRAWN_FROM metres or less is drawn as it is, each
## metre more out to DRAWN_UNTIL is drawn as DRAWN_SHARE of a metre, and beyond that a metre is a metre again.
const DRAWN_FROM: float = 0.9
const DRAWN_SHARE: float = 0.45
const DRAWN_UNTIL: float = 3.0
## A strike thrown out of range (the sim says "out of range") steps in this much less than it would need.
const SHORT_BY: float = 0.3
## The most a strike steps in (metres), and the closest two stepping strikers get (D281).
const LUNGE_MAX: float = 0.75
const LUNGE_CLOSEST: float = 0.85

var driver: FightDriver
var camera: Camera3D
var figures: Array[FighterFigure] = []
## Light up scouted tells (D51): a toggle so the playtest can compare cue on and off.
var tell_cues: bool = true
var debug_marks: bool = false:
	set(value):
		debug_marks = value
		if _debug != null:
			_debug.visible = value

var _tag: Label3D
var _tag_text: String = ""
var _tag_scale: float = 1.0
var _focus := Vector3.ZERO
var _zoom: float = ZOOM_STANDING
var _debug: Node3D
var _want_rings: Array[MeshInstance3D] = []
## Per fighter: the tell's limb and how many fight ticks it stays lit.
var _tell_limb: Array[String] = ["", ""]
var _tell_until: Array[int] = [-1, -1]
## Per fighter, smoothed: how far the view moves him off his sim spot, and the way he faces (radians).
var _offset: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _facing: Array[float] = [0.0, 0.0]
var _facing_set: bool = false
var _venue: LocalVenue


func _ready() -> void:
	_build_cage()
	_build_camera()
	_tag = FighterFigure._label(48)
	_tag.position = Vector3(0.0, 0.05, 0.0)
	add_child(_tag)
	_debug = Node3D.new()
	_debug.visible = debug_marks
	add_child(_debug)
	_build_debug_marks()


## Starts showing a fight (null clears the canvas).
func watch(p_driver: FightDriver) -> void:
	if driver != null and driver.sim.event_emitted.is_connected(_on_event):
		driver.sim.event_emitted.disconnect(_on_event)
	for f in figures:
		f.queue_free()
	figures.clear()
	_tell_limb = ["", ""]
	_tell_until = [-1, -1]
	_offset = [Vector2.ZERO, Vector2.ZERO]
	_facing_set = false
	driver = p_driver
	_tag.visible = driver != null
	if driver == null:
		return
	for i in driver.sim.fighters.size():
		var southpaw: bool = driver.sim.fighters[i].profile.get("stance", "orthodox") == "southpaw"
		var figure := FighterFigure.new(FIGHTER_COLOURS[i], southpaw, i)
		add_child(figure)
		figures.append(figure)
	for i in figures.size():
		figures[i].opponent = figures[1 - i]  # Strikes aim at the other man (D281).
	driver.sim.event_emitted.connect(_on_event)
	_focus = Vector3.ZERO
	_zoom = ZOOM_STANDING
	_tag_text = ""


func _process(delta: float) -> void:
	if driver == null:
		_place_camera(delta)
		return
	var sim: FightSim = driver.sim
	var spots: Array[Vector2] = [driver.shown_pos(0), driver.shown_pos(1)]
	var placed: Array[Dictionary] = ground_spots(sim, spots)
	if sim.situation.is_standing():
		var drawn: Array[Vector2] = standing_spots(spots)
		for i in placed.size():
			placed[i].at = drawn[i]
	var k: float = 1.0 - exp(-LAYOUT_SPEED * delta)
	var shown: Array[Vector2] = []
	for i in figures.size():
		var want: float = placed[i].facing
		_offset[i] = _offset[i].lerp(placed[i].at - spots[i], k if _facing_set else 1.0)
		_facing[i] = lerp_angle(_facing[i], want, k) if _facing_set else want
		shown.append(spots[i] + _offset[i])
	if sim.situation.is_standing() and figures.size() == 2:
		shown = strike_spots(sim, shown, [figures[0].knock, figures[1].knock], driver.alpha())
	_side_labels()
	for i in figures.size():
		var at: Vector2 = shown[i]
		figures[i].label_scale = zoom_share()
		figures[i].show_state(sim, i, at, at + Vector2.from_angle(_facing[i]), delta, delta * driver.rate())
		figures[i].show_tell(_tell_limb[i] if tell_cues and sim.now <= _tell_until[i] else "")
	_facing_set = true
	var middle: Vector2 = (spots[0] + spots[1]) / 2.0
	if _venue != null:
		_venue.show_near_fence(shown, delta)
	_show_tag(sim, middle, delta)
	_place_camera(delta, middle, sim)
	if debug_marks:
		for i in _want_rings.size():
			var want: float = sim.last_wanted_distance(i)
			_want_rings[i].visible = want > 0.0 and sim.situation.is_standing()
			var o: Vector2 = spots[1 - i]
			_want_rings[i].position = Vector3(o.x, 0.03, o.y)
			_want_rings[i].scale = Vector3(want, 1.0, want)


## The camera's zoom against standing (1 standing, under 1 moved in), for sizing labels.
func zoom_share() -> float:
	return _zoom / ZOOM_STANDING


## The words under the fighters: the range standing, the position when tied up.
static func tag_text(sim: FightSim) -> String:
	if sim.situation.is_standing():
		return String(TAG_NAMES.get(sim.band(), sim.band()))
	var text: String = String(sim.positions.get_position(sim.situation.position).name)
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		return "%s · %s's %s" % [text, sim.fighters[int(hold.attacker)].name, String(sim.actions.get_action(hold.action_id).name).to_lower()]
	var top: int = sim.situation.roles.find(PositionLibrary.TOP)
	if top >= 0:
		text += " · %s %s" % [sim.fighters[top].name, sim.positions.top_label(sim.situation.position)]
	return text


## Standing, where the two are drawn (D281): the same line between them, the gap shrunk to a person's reach
## (drawn_gap), moving whoever has more room off the fence, so a man on the fence stays on it.
static func standing_spots(spots: Array[Vector2]) -> Array[Vector2]:
	var gap: float = spots[0].distance_to(spots[1])
	var cut: float = gap - drawn_gap(gap)
	if cut <= 0.0 or gap < 0.001:
		return spots.duplicate()
	var toward: Vector2 = (spots[1] - spots[0]) / gap
	var room: Array[float] = []
	for p: Vector2 in spots:
		room.append(clampf((Octagon.distance_to_fence(p) - Octagon.BODY_MARGIN) / Octagon.NEAR_WITHIN, 0.0, 1.0))
	var share: float = 0.5 if room[0] + room[1] < 0.001 else room[0] / (room[0] + room[1])
	return [spots[0] + toward * cut * share, spots[1] - toward * cut * (1.0 - share)]


## The drawn gap for a sim gap (D281): see DRAWN_FROM, DRAWN_SHARE and DRAWN_UNTIL.
static func drawn_gap(gap: float) -> float:
	if gap <= DRAWN_FROM:
		return gap
	var squeezed: float = DRAWN_FROM + (minf(gap, DRAWN_UNTIL) - DRAWN_FROM) * DRAWN_SHARE
	return squeezed + maxf(0.0, gap - DRAWN_UNTIL)


## How far fighter i steps in for the strike he's throwing (metres, D281), from the drawn gap: enough for it to
## land at its contact gap (FighterFigure.AIMS), less SHORT_BY when the sim has it out of range. Eased in over
## the telegraph and windup, held through the active part, and taken back over the recovery.
static func lunge_for(sim: FightSim, i: int, gap: float, fraction: float = 0.0) -> float:
	var f: FighterState = sim.fighters[i]
	if not FighterFigure.AIMS.has(f.action_id) or not sim.actions.has(f.action_id):
		return 0.0
	var action: Dictionary = sim.actions.get_action(f.action_id)
	var need: float = gap - float(FighterFigure.AIMS[f.action_id].contact)
	if not action.ranges.has(sim.band()):
		need -= SHORT_BY
	if need <= 0.0:
		return 0.0
	var total: float = maxf(1.0, sim.phase_ticks(f, f.action_id, f.phase))
	var progress: float = clampf((total - f.phase_ticks_left + fraction) / total, 0.0, 1.0)
	var ease: float = 0.0
	match f.phase:
		"telegraph": ease = 0.6 * smoothstep(0.0, 1.0, progress)
		"windup": ease = lerpf(0.6, 1.0, progress)
		"active": ease = 1.0
		"recovery": ease = 1.0 - smoothstep(0.0, 1.0, progress)
	return minf(need, LUNGE_MAX) * ease


## Standing, the drawn spots with each striker stepped in toward the other (lunge_for) and each man hit
## knocked back (`knock`, metres), kept inside the fence (D281).
static func strike_spots(sim: FightSim, spots: Array[Vector2], knock: Array[float], fraction: float = 0.0) -> Array[Vector2]:
	var gap: float = spots[0].distance_to(spots[1])
	if gap < 0.001:
		return spots.duplicate()
	var toward: Vector2 = (spots[1] - spots[0]) / gap
	var lunge: Array[float] = [lunge_for(sim, 0, gap, fraction), lunge_for(sim, 1, gap, fraction)]
	# Two men stepping in together share the step: they stop at the shorter strike's contact gap.
	var closest: float = LUNGE_CLOSEST
	if lunge[0] > 0.0 and lunge[1] > 0.0:
		closest = maxf(closest, minf(_contact(sim, 0), _contact(sim, 1)))
	var room: float = maxf(0.0, gap - closest)
	if lunge[0] + lunge[1] > room:
		var scale: float = room / (lunge[0] + lunge[1])
		lunge = [lunge[0] * scale, lunge[1] * scale]
	var a: Vector2 = spots[0] + toward * (lunge[0] - knock[0])
	var b: Vector2 = spots[1] - toward * (lunge[1] - knock[1])
	return [Octagon.keep_inside(a), Octagon.keep_inside(b)]


static func _contact(sim: FightSim, i: int) -> float:
	return float(FighterFigure.AIMS.get(sim.fighters[i].action_id, {}).get("contact", 0.0))


## The two move labels lean apart on screen when both are up, so they don't print over each other (D281).
func _side_labels() -> void:
	if figures.size() < 2 or camera == null or not camera.is_inside_tree():
		return
	var left: float = camera.unproject_position(figures[0]._head.global_position).x
	var right: float = camera.unproject_position(figures[1]._head.global_position).x
	var both: bool = figures[0]._move_label.visible and figures[1]._move_label.visible
	figures[0].label_side = (-1.0 if left <= right else 1.0) if both else 0.0
	figures[1].label_side = -figures[0].label_side


## Where each fighter is drawn and the way he faces (radians on the canvas), from their sim spots:
## face to face standing, laid out by GROUND_LAYOUTS on the ground (D210). Plain numbers, so it can be tested.
static func ground_spots(sim: FightSim, spots: Array[Vector2]) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	for i in spots.size():
		placed.append({ "at": spots[i], "facing": (spots[1 - i] - spots[i]).angle() })
	var where: String = sim.situation.position
	var roles: Array = sim.situation.roles
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		if ActionLibrary.is_leg_lock(sim.actions.get_action(hold.action_id)):
			return placed
		where = String(hold.from)  # Held where it was locked from (D126).
		roles = hold.from_roles
	if where == PositionLibrary.CLINCH:
		var direction: Vector2 = (spots[1] - spots[0]).normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		var middle: Vector2 = (spots[0] + spots[1]) / 2.0
		var a: Vector2 = middle - direction * CLINCH_BODY_GAP / 2.0
		var b: Vector2 = middle + direction * CLINCH_BODY_GAP / 2.0
		# Shift the pair together at the fence, preserving the physical room between bodies.
		for normal: Vector2 in Octagon.NORMALS:
			var over: float = maxf(a.dot(normal), b.dot(normal)) - (Octagon.APOTHEM - Octagon.BODY_MARGIN)
			if over > 0.0:
				a -= normal * over
				b -= normal * over
		return [{"at": a, "facing": direction.angle()}, {"at": b, "facing": (-direction).angle()}]
	var top: int = roles.find(PositionLibrary.TOP)
	if not GROUND_LAYOUTS.has(where) or top < 0:
		return placed
	var bottom: int = 1 - top
	var layout: Dictionary = GROUND_LAYOUTS[where]
	# He lies across the screen, so neither man hides the other from the camera: feet toward whichever
	# side of the screen the sim has the top man on. The top man's side (positive `at.y`) is the far one.
	var across: Vector2 = Vector2(CAMERA_FROM.z, -CAMERA_FROM.x).normalized()
	var away: Vector2 = -Vector2(CAMERA_FROM.x, CAMERA_FROM.z).normalized()
	var feet: Vector2 = across if (spots[top] - spots[bottom]).dot(across) >= 0.0 else -across
	if layout.get("facing_camera", false):  # Sat up facing you, so the man behind him is behind him on screen too.
		feet = (feet * tan(LIE_TURN) - away).normalized()
	else:
		feet = (feet + away * tan(LIE_TURN)).normalized()  # Turned a little, so a man across him isn't end-on.
	var side: Vector2 = feet.orthogonal()
	if side.dot(away) < 0.0:
		side = -side
	var at: Vector2 = layout.at
	var face: Vector2 = layout.face
	placed[bottom] = { "at": spots[bottom], "facing": feet.angle() }
	placed[top] = { "at": spots[bottom] + feet * at.x + side * at.y, "facing": (feet * face.x + side * face.y).angle() }
	return placed


func _show_tag(sim: FightSim, middle: Vector2, delta: float) -> void:
	var text: String = tag_text(sim)
	if text != _tag_text:
		_tag_text = text
		_tag_scale = TAG_BUMP
	_tag_scale = lerpf(_tag_scale, 1.0, 1.0 - exp(-3.0 * delta))
	_tag.text = text
	_tag.modulate = TAG_COLOURS.get(sim.band(), Color.WHITE)
	# Labels are sized in metres: shrink them as the camera moves in so they stay the same on screen.
	_tag.scale = Vector3.ONE * _tag_scale * zoom_share()
	# Just in front of the fighters as the camera sees them, on the canvas.
	_tag.position = Vector3(middle.x, 0.05, middle.y) + Vector3(0.9, 0.0, 0.9)


func _place_camera(delta: float, middle: Vector2 = Vector2.ZERO, sim: FightSim = null) -> void:
	var want_zoom: float = ZOOM_STANDING
	if sim != null and not sim.situation.is_standing():
		want_zoom = ZOOM_CLINCH if sim.situation.position == PositionLibrary.CLINCH else ZOOM_GROUND
	var k: float = 1.0 - exp(-CAMERA_SPEED * delta)
	var follow: float = FOLLOW_SHARE if sim == null or sim.situation.is_standing() else 1.0
	if sim != null and sim.situation.is_standing():
		# Wide separation needs the whole tactical space, including the retreating fighter.
		want_zoom = maxf(want_zoom, sim.fighters[0].pos.distance_to(sim.fighters[1].pos) * 0.92 + 2.8)
	_focus = _focus.lerp(Vector3(middle.x, 0.6, middle.y) * follow, k)
	_zoom = lerpf(_zoom, want_zoom, k)
	camera.size = _zoom
	var distance: float = _zoom / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
	camera.position = _focus + CAMERA_FROM.normalized() * distance
	camera.look_at(_focus, Vector3.UP)


func _on_event(event: FightEvent) -> void:
	# Tell cues (D51): the playtest's opponents are scouted, so their tells show.
	if event.type == FightEvent.ROUND_ENDED:
		_tell_until = [-1, -1]
		return
	if event.actor in [0, 1] and figures.size() == 2:
		_show_strike(event)
	var sim: FightSim = driver.sim
	var triggers: TriggerLibrary = TriggerLibrary.shared()
	for i in sim.fighters.size():
		if i == driver.player:
			continue
		for tell: Dictionary in sim.fighters[i].tells:
			if triggers.has(tell.trigger) and triggers.matches(tell.trigger, event, i):
				_tell_limb[i] = FighterFigure.limb_for(String(tell.action))
				_tell_until[i] = event.tick + int(tell.get("within_ms", 1000)) / FightClock.TICK_MS
		# The tell's move is under way: the cue's job is done.
		if event.actor == i and event.type == FightEvent.ACTION_PHASE and event.data.phase == "active":
			_tell_until[i] = -1
	if event.type == FightEvent.CALL_ANSWERED and event.data.outcome == LiveCalls.IGNORED and event.actor < figures.size():
		figures[event.actor].show_ignored()


## A strike's outcome on both men (D281): the thrower's aim follows it, the man hit reacts.
func _show_strike(event: FightEvent) -> void:
	var a: int = event.actor
	var action: String = String(event.data.get("action_id", ""))
	match event.type:
		FightEvent.STRIKE_LANDED:
			var covered: bool = bool(event.data.get("covered", false))
			figures[a].show_outcome(action, "covered" if covered else "landed")
			var hook: bool = FighterFigure.AIMS.has(action) and String(FighterFigure.AIMS[action].bend) in ["out", "round"]
			var turn: float = 0.0
			if hook:  # A hook or round kick turns his head away from the side it came from.
				turn = 1.0 if String(FighterFigure.AIMS[action].limb).begins_with("lead") == (figures[a].lead < 0.0) else -1.0
			figures[1 - a].show_hit(String(event.data.target), float(event.data.damage), covered, turn)
		FightEvent.STRIKE_MISSED:
			var reason: String = String(event.data.get("reason", ""))
			var outcome: String = "missed"
			if reason == "out of range":
				outcome = "short"
			elif String(event.data.get("by_action", "")) == "check_kick":
				outcome = "checked"
			figures[a].show_outcome(action, outcome)


func _build_cage() -> void:
	_venue = LocalVenue.new()
	add_child(_venue)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	camera.size = ZOOM_STANDING
	camera.near = 0.1
	camera.far = 60.0
	add_child(camera)
	camera.current = true
	_place_camera(1.0)


func _build_debug_marks() -> void:
	for within: float in [Octagon.NEAR_WITHIN, Octagon.PINNED_WITHIN]:
		var line := MeshInstance3D.new()
		line.mesh = _octagon_outline(Octagon.APOTHEM - Octagon.BODY_MARGIN - within)
		var m: StandardMaterial3D = FighterFigure._material(Color(1.0, 1.0, 1.0, 0.45))
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = m
		line.position.y = 0.02
		_debug.add_child(line)
	for i in 2:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.985
		torus.outer_radius = 1.0
		torus.rings = 64
		ring.mesh = torus
		var m: StandardMaterial3D = FighterFigure._material(Color(FIGHTER_COLOURS[i], 0.6))
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = m
		ring.visible = false
		_debug.add_child(ring)
		_want_rings.append(ring)


## A flat octagon `height` thick, corners at `corner` metres. CylinderMesh puts a corner on
## the z axis, so turn it PI / 8 to line it up with the fence (Octagon.NORMALS).
static func _octagon_slab(corner: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = corner
	mesh.bottom_radius = corner
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


## An octagon outline on the canvas, `apothem` metres from the centre to each side.
static func _octagon_outline(apothem: float) -> ImmediateMesh:
	var corner: float = apothem / cos(PI / 8.0)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in 9:
		var p: Vector2 = Vector2.from_angle(PI / 8.0 + k * PI / 4.0) * corner
		mesh.surface_add_vertex(Vector3(p.x, 0.0, p.y))
	mesh.surface_end()
	return mesh
