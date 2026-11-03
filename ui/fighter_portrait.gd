class_name FighterPortrait
extends Control
## A fighter drawn as himself off the fight screen (docs/06 §6.11, D430): the skinned body (D284) with his height,
## build, reach and look (D364), standing in his stance (D362) and breathing, lit like the hall, on a see-through
## background so the card behind shows. Used on the hub, the fight night card, the tale of the tape, the result
## screen and the new-career screen in place of the green capsule man; the capsule (BodyDamageFigure) stays as a small
## badge in the corner when he's hurt (Kyle's pick, the D430 cards).
##
## FULL frames him head to feet at one scale for every portrait, so a taller man stands taller (the tape compares
## them); BUST frames his head and chest. The 3D is built the first time the portrait is drawn (or by build_now()),
## so a screen that's never shown costs nothing.

const FULL := "full"
const BUST := "bust"
## FULL: the view is this many metres tall, the canvas at its bottom edge, whoever stands in it.
const FULL_VIEW_HEIGHT: float = 2.25
## FULL: the canvas sits this share of the view up from the bottom edge.
const FULL_FLOOR_SHARE: float = 0.04
## BUST: the view is this many metres tall, centred this far under the top of his head.
const BUST_VIEW_HEIGHT: float = 1.15
const BUST_CENTRE_DROP: float = 0.46
## The camera's lens (degrees of vertical view) and how far round from straight on it looks at him (degrees; his
## left shoulder toward it). A long lens keeps his proportions true.
const LENS_FOV: float = 18.0
const THREE_QUARTER: float = 24.0
## His idle (D430, Kyle's pick "breathe and bounce"): a slow weight shift side to side and a small bounce, as if he's
## waiting for the bell; metres and seconds. Breathing itself is FighterFigure's own.
const SHIFT_SIDE: float = 0.018
const SHIFT_SECONDS: float = 3.4
const BOUNCE: float = 0.012
const BOUNCE_SECONDS: float = 0.9
## The hurt badge (BodyDamageFigure) shows once any area is this hurt, at this size, in the bottom-right corner.
const BADGE_FROM: float = 0.05
const BADGE_SIZE := Vector2(42.0, 70.0)
## Lights: a warm key from the front left, a cool fill and a rim from behind, as the hall's lights read.
const KEY := Color("#ffe5cc")
const FILL := Color("#b0c9e3")
const RIM := Color("#ffd9a8")

## The corner he's in (0 red, 1 blue): the colour of his shorts.
var corner: int = 0
var framing: String = FULL
## Which way he faces (degrees): 0 at the camera, + turned toward the right of the picture.
var facing: float = 0.0
## Hurt by area (head, body, legs: 0 to 1), for the badge. `badge_always` keeps it up even when he's fresh (the result).
var hurt: Dictionary = { "head": 0.0, "body": 0.0, "legs": 0.0 }
var badge_always: bool = false
var badge_size: Vector2 = BADGE_SIZE
## Moves (breathes and bounces) when true; a still pose when false.
var idle: bool = true

var profile: Dictionary = {}
var figure: FighterFigure
var view: SubViewportContainer
var viewport: SubViewport
var badge: BodyDamageFigure
var _scene: Node3D
var _camera: Camera3D
var _sim: FightSim
var _clock: float = 0.0
var _built_for: Dictionary = {}

static var _actions: ActionLibrary


func _init(p_framing: String = FULL, p_corner: int = 0, p_facing: float = 0.0) -> void:
	framing = p_framing
	corner = p_corner
	facing = p_facing
	mouse_filter = Control.MOUSE_FILTER_PASS
	view = SubViewportContainer.new()
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.add_child(viewport)
	badge = BodyDamageFigure.new()
	badge.custom_minimum_size = BADGE_SIZE
	badge.size = BADGE_SIZE
	badge.visible = false
	badge.tooltip_text = "where he's hurt: green is fine, red is badly hurt"
	add_child(badge)
	resized.connect(_place_badge)


## Shows this man (a fighter@1 profile: his frame, look, stance, stats and style). Rebuilds the 3D only when the
## man (or how he's drawn) changed.
func show_fighter(p_profile: Dictionary) -> void:
	profile = p_profile
	if is_visible_in_tree() and figure != null:
		_build()


## Sets the hurt badge (head, body, legs 0 to 1; legs may also come as the two legs apart in `leg_hurt`).
func set_hurt(p_hurt: Dictionary, leg_hurt: Array = []) -> void:
	for area: String in BodyDamageFigure.AREAS:
		hurt[area] = float(p_hurt.get(area, 0.0))
		badge.hurt[area] = hurt[area]
	var legs: float = float(hurt.legs)
	var legs_apart: Array[float] = [legs, legs]
	if leg_hurt.size() == 2:
		legs_apart = [float(leg_hurt[0]), float(leg_hurt[1])]
	badge.leg_hurt = legs_apart
	badge.queue_redraw()
	_show_badge()


## Builds the 3D now instead of when first drawn (tests, and a screen about to show).
func build_now() -> void:
	_build()


func _ready() -> void:
	_place_badge()
	_show_badge()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_RESIZED:
		_show_badge()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or profile.is_empty():
		return
	if figure == null or _built_for != _key():
		_build()
	if figure == null:
		return
	_clock += delta if idle else 0.0
	var side: float = SHIFT_SIDE * sin(TAU * _clock / SHIFT_SECONDS)
	var bounce: float = BOUNCE * absf(sin(TAU * _clock / BOUNCE_SECONDS / 2.0))
	var at := Vector2(side, 0.0)
	var turn: float = deg_to_rad(facing)
	figure.show_state(_sim, 0, at, at + Vector2(sin(turn), cos(turn)), delta if idle else 0.0)
	figure.hide_overhead()
	figure.position.y = bounce


## Who's drawn and how: a change rebuilds him.
func _key() -> Dictionary:
	return { "id": profile.get("id", ""), "name": profile.get("name", ""), "look": profile.get("look", {}),
		"frame": profile.get("frame", {}), "stance": profile.get("stance", ""), "home": profile.get("home", ""),
		"corner": corner, "framing": framing }


func _build() -> void:
	if profile.is_empty():
		return
	if _scene == null:
		_build_scene()
	if figure != null:
		figure.queue_free()
		figure = null
	var me: FighterState = FighterState.from_profile(_filled(profile))
	var other: FighterState = FighterState.from_profile(_filled({ "id": "portrait_other", "name": "" }))
	if _actions == null:
		_actions = ActionLibrary.load_dir()
	_sim = FightSim.new(1, [me, other], _actions)
	figure = FighterFigure.new(ArenaView.FIGHTER_COLOURS[clampi(corner, 0, 1)],
		String(profile.get("stance", "")) == "southpaw", corner)
	_scene.add_child(figure)
	figure.use_body(ArenaView.BODY, profile)
	figure.hide_overhead()
	_built_for = _key()
	_frame_camera()
	# One step to put him in his stance before the first frame shows.
	var turn: float = deg_to_rad(facing)
	figure.show_state(_sim, 0, Vector2.ZERO, Vector2(sin(turn), cos(turn)), 1.0)
	figure.hide_overhead()


## A profile with the fields FighterState.from_profile reads, where it left them out (a new career's preview).
static func _filled(p: Dictionary) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if not out.has("name"):
		out.name = ""
	if not (out.get("stats") is Dictionary):
		out.stats = {}
	return out


func _build_scene() -> void:
	_scene = Node3D.new()
	viewport.add_child(_scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a9bad0")
	environment.environment.ambient_light_energy = 0.5
	_scene.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -25, 0)
	key.light_color = KEY
	key.light_energy = 1.05
	_scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 40, 0)
	fill.light_color = FILL
	fill.light_energy = 0.35
	_scene.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 170, 0)
	rim.light_color = RIM
	rim.light_energy = 0.7
	_scene.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = LENS_FOV
	_camera.current = true
	_scene.add_child(_camera)


## Places the camera: FULL at one scale for everyone (feet on the bottom edge), BUST on his head and chest.
func _frame_camera() -> void:
	var view_height: float = FULL_VIEW_HEIGHT
	var centre_y: float = view_height * (0.5 - FULL_FLOOR_SHARE)
	if framing == BUST:
		var top: float = 1.82 * figure.scale.y  # FighterLook.sizes scales the whole figure by his height.
		view_height = BUST_VIEW_HEIGHT
		centre_y = top - BUST_CENTRE_DROP
	var distance: float = (view_height / 2.0) / tan(deg_to_rad(LENS_FOV) / 2.0)
	var round_by: float = deg_to_rad(THREE_QUARTER * (-1.0 if facing < 0.0 else 1.0))  # From the side he turns to.
	_camera.position = Vector3(sin(round_by) * distance, centre_y, cos(round_by) * distance)
	_camera.look_at(Vector3(0.0, centre_y, 0.0))


func _show_badge() -> void:
	var worst: float = 0.0
	for area: String in BodyDamageFigure.AREAS:
		worst = maxf(worst, float(hurt.get(area, 0.0)))
	badge.visible = badge_always or worst >= BADGE_FROM


func _place_badge() -> void:
	badge.custom_minimum_size = badge_size
	badge.size = badge_size
	badge.position = size - badge_size - Vector2(4.0, 4.0)
