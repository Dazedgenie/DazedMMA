class_name SkinnedBody
extends Node3D
## A skinned, auto-rigged body (D284) driven by a FighterRig: one continuous mesh that bends at the joints, posed
## from the rig's paired poses instead of the faceted pieces. The body is a glTF file with a Mixamo-named
## humanoid skeleton (Tripo's Mixamo preset). It is scaled so its hips stand at the rig's pelvis height and
## turned to face -Z like the rig.
##
## The trunk, neck, head and feet copy the rig's turns; the arms and legs are solved again in the body's own bone
## lengths (FighterMotion.solve_bones) toward the rig's wrists and ankles, bent toward the rig's elbows and knees,
## so a hand on the other man stays on him even though the body's limbs are shorter than the rig's.
## Presentation only.

## The first body (Kyle's, made in Tripo with its Mixamo skeleton preset, 2026-10-31): imported with the game, since
## the fight screen draws both fighters with it (D285).
const TRIPO_BODY := "res://game/bodies/tripo_fighter.glb"
## Mixamo bone names (Godot turns "mixamorig:" into "mixamorig_") for the rig's joints.
const PREFIX := "mixamorig_"
## [body bone, rig bone, share]: the trunk copies the rig's pelvis and chest; the lower spine is part way between.
const TRUNK := [
	["Hips", "pelvis", 0.0], ["Spine", "waist", 0.35], ["Spine1", "waist", 0.7], ["Spine2", "waist", 1.0],
	["Neck", "neck", 1.0], ["Head", "head", 1.0],
]
## [upper bone, lower bone, end bone, rig side, rig limb]: the limbs solved again in the body's own lengths.
const LIMBS := [
	["LeftArm", "LeftForeArm", "LeftHand", "l", "arm"], ["RightArm", "RightForeArm", "RightHand", "r", "arm"],
	["LeftUpLeg", "LeftLeg", "LeftFoot", "l", "leg"], ["RightUpLeg", "RightLeg", "RightFoot", "r", "leg"],
]

var skeleton: Skeleton3D
## The bones' poses shown last frame and the easing time left (ease_over, settle).
var _shown: Array[Transform3D] = []
var _ease_left: float = 0.0
## The body's scale (the file's units to metres) and the bones' rests in the world when the body stands as the
## rig does at rest (facing -Z at the origin).
var body_scale: float = 1.0
var _rest_world := {}
var _ids := {}
## Where the hip joints' middle is at rest (the rig's pelvis point).
var _pelvis_rest := Vector3.ZERO
## His build (D364, set_size): each bone's scale in its own frame (Y runs along the bone), and how long his arms are.
var _bone_scale := {}
var _arm_length: float = 1.0


func _init() -> void:
	top_level = true  # The body's rest is taken at the world's origin; it is posed in world space.


## Loads the body from a glTF/GLB file (`path`, res:// or a file path). Returns false if it isn't a humanoid.
## `shoulder_height` (metres, 0 for none) scales the body so its shoulders stand that high instead of its hips at
## the rig's pelvis height (D285: today's figures are taller in the trunk than the body).
func load_body(path: String, shoulder_height: float = 0.0) -> bool:
	var scene: Node3D
	if ResourceLoader.exists(path, "PackedScene"):  # Imported with the game (exports with it).
		var packed: PackedScene = load(path)
		scene = packed.instantiate()
	else:  # A raw file (the tools' bodies, or one from outside the project).
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_error("SkinnedBody: could not load %s" % path)
			return false
		scene = doc.generate_scene(state)
	add_child(scene)
	return attach(scene, shoulder_height)


## Uses `scene` (already a child of this node) as the body.
func attach(scene: Node3D, shoulder_height: float = 0.0) -> bool:
	var found: Array[Node] = scene.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("SkinnedBody: no skeleton in the body")
		return false
	skeleton = found[0]
	for name_in_rig: String in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "RightShoulder",
			"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg",
			"LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]:
		var id: int = skeleton.find_bone(PREFIX + name_in_rig)
		if id < 0:
			push_error("SkinnedBody: no %s bone" % name_in_rig)
			return false
		_ids[name_in_rig] = id
	# Stand it up like the rig: hip joints at the rig's pelvis height, facing -Z (Mixamo bodies face +Z).
	var hips: float = 0.0
	for leg: String in ["LeftUpLeg", "RightUpLeg"]:
		hips += (skeleton.global_transform * skeleton.get_bone_global_rest(_ids[leg])).origin.y / 2.0
	body_scale = FighterRig.PELVIS_HEIGHT / maxf(hips, 0.01)
	if shoulder_height > 0.0:
		var shoulder: float = (skeleton.global_transform * skeleton.get_bone_global_rest(_ids.RightArm)).origin.y
		body_scale = shoulder_height / maxf(shoulder, 0.01)
	scene.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * body_scale), Vector3.ZERO) * scene.transform
	var to_world: Transform3D = global_transform.affine_inverse() * skeleton.global_transform
	for key: String in _ids:
		_rest_world[key] = to_world * skeleton.get_bone_global_rest(_ids[key])
	_pelvis_rest = (_at("LeftUpLeg") + _at("RightUpLeg")) / 2.0
	curl_fingers(FIST_CURL)
	return true


## The trunk's and the limbs' bones (D364): set_size thickens them across, and lengthens the arms' along.
const GIRTH_TRUNK: Array[String] = ["Hips", "Spine", "Spine1", "Spine2", "Neck"]
const GIRTH_LIMBS: Array[String] = ["LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "LeftUpLeg", "LeftLeg",
	"RightUpLeg", "RightLeg"]
## The neck takes this share of the trunk's thickening.
const NECK_GIRTH_SHARE: float = 0.7


## Draws him at his build (FighterLook.sizes, D364): `girth` thickens his trunk across, `limbs` his arms and legs,
## and `arm` lengthens his arms (upper arm and forearm alike). Run before posing, and before the rig is fitted to
## measure(), which gives the longer arms.
func set_size(sizes: Dictionary) -> void:
	var girth: float = float(sizes.get("girth", 1.0))
	var limbs: float = float(sizes.get("limbs", 1.0))
	_arm_length = float(sizes.get("arm", 1.0))
	_bone_scale.clear()
	for bone: String in GIRTH_TRUNK:
		var g: float = 1.0 + (girth - 1.0) * (NECK_GIRTH_SHARE if bone == "Neck" else 1.0)
		_bone_scale[bone] = Vector3(g, 1.0, g)
	for bone: String in GIRTH_LIMBS:
		_bone_scale[bone] = Vector3(limbs, _arm_length if bone.contains("Arm") else 1.0, limbs)


## How far each finger joint bends to make a fist (radians; the thumb folds about half as far).
const FIST_CURL: float = 1.35
## The finger bones of a Mixamo hand, each bent by curl_fingers.
const FINGERS := ["Index", "Middle", "Ring", "Pinky", "Thumb"]
## The axis each thumb's joints turn about to fold it into the palm (in the bone's own frame; the two hands'
## thumb bones are not plain mirror images, so each has its own).
const THUMB_AXIS := {"Right": Vector3(-0.87, -0.5, 0.0), "Left": Vector3(0.75, -0.5, 0.43)}


## Bends the fingers in (a gloved fist at FIST_CURL; 0 opens the hand).
func curl_fingers(amount: float) -> void:
	for side: String in ["Left", "Right"]:
		for finger: String in FINGERS:
			for joint in [1, 2, 3]:
				var id: int = skeleton.find_bone("%s%sHand%s%d" % [PREFIX, side, finger, joint])
				if id < 0:
					continue
				# Mixamo fingers bend about their own X, the left hand's the other way round (its bones are
				# mirrored); the thumb folds across the fingers about an axis found by search (THUMB_AXIS).
				var bend := Quaternion(THUMB_AXIS[side].normalized(), amount * 0.52) if finger == "Thumb" \
					else Quaternion(Vector3.LEFT if side == "Left" else Vector3.RIGHT, amount)
				skeleton.set_bone_pose_rotation(id, skeleton.get_bone_rest(id).basis.get_rotation_quaternion() * bend)


## Colours the body's light-grey shorts in a corner's colour (the rest of the texture stays as it is). The body
## file's shorts are light grey on purpose so one body serves both corners.
func set_colour(colour: Color) -> void:
	set_look(colour, {})


## The body's regions (D364): a texture over the body's own, baked from where each part of it is
## (tools/body_regions.py): red the hair on his head, green where a beard grows, blue his eyebrows, alpha his shorts.
const REGIONS := "res://game/bodies/tripo_fighter_regions.png"
## The skin and hair colours the body's own texture has (sRGB), which a look's colours replace.
const BODY_SKIN := Color(0.745, 0.525, 0.384)
const BODY_HAIR := Color(0.21, 0.17, 0.14)
## How much of the hair's colour a buzzed head keeps over the scalp's (a shaved head keeps none).
const BUZZED_HAIR: float = 0.55
## How far the hair's shell sinks toward the scalp (metres) for a buzzed or shaved head.
const HAIR_SINK := { "short": 0.0, "buzzed": 0.014, "shaved": 0.022 }
## How much of the texture's own skin colour (its blush, lips and shadows) a new skin tone keeps against an even tone
## shaded as the texture is.
const SKIN_DETAIL: float = 0.65


## Colours the body: the shorts in the corner's `colour` and the skin, hair, eyebrows and beard as `look` (FighterLook,
## D364) has them; an empty look leaves the body's own skin and hair.
func set_look(colour: Color, look: Dictionary) -> void:
	var regions: Texture2D = load(REGIONS) if ResourceLoader.exists(REGIONS) else null
	for found: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = found
		var base: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
		if base == null or base.albedo_texture == null:
			continue
		var tinted := ShaderMaterial.new()
		tinted.shader = _tint_shader()
		tinted.set_shader_parameter("albedo", base.albedo_texture)
		tinted.set_shader_parameter("tint", colour)
		tinted.set_shader_parameter("body_skin", BODY_SKIN)
		tinted.set_shader_parameter("body_hair", BODY_HAIR)
		tinted.set_shader_parameter("skin_detail", SKIN_DETAIL)
		if regions != null:
			tinted.set_shader_parameter("regions", regions)
			tinted.set_shader_parameter("has_regions", true)
		var has_look: bool = not look.is_empty()
		tinted.set_shader_parameter("skin", FighterLook.skin_colour(look) if has_look else BODY_SKIN)
		tinted.set_shader_parameter("hair", FighterLook.hair_colour(look) if has_look else BODY_HAIR)
		var style: String = String(look.get("hair_style", "short"))
		tinted.set_shader_parameter("hair_kept", 1.0 if style == "short" else (BUZZED_HAIR if style == "buzzed" else 0.0))
		tinted.set_shader_parameter("hair_sink", HAIR_SINK.get(style, 0.0) / maxf(mesh.global_basis.get_scale().y, 0.001))
		tinted.set_shader_parameter("beard", float(FighterLook.BEARD_SHADE.get(String(look.get("beard", "none")), 0.0)))
		mesh.material_override = tinted


## The referee's clothes over the body (D373, tools/body_regions.py): red his shirt, green its black stripes (with no
## red, his bare hands), blue his trousers, alpha his shoes.
const CLOTHES := "res://game/bodies/tripo_fighter_clothes.png"
## The referee's shirt (white and black stripes), trousers and shoes, before the texture's shading.
const SHIRT_WHITE := Color(0.86, 0.86, 0.84)
const SHIRT_BLACK := Color(0.05, 0.05, 0.06)
const TROUSERS := Color(0.3, 0.31, 0.33)
const SHOES := Color(0.04, 0.04, 0.045)


## Dresses the body as the referee (D373): his skin and hair as `look` (FighterLook), the striped shirt, grey
## trousers, black shoes and bare hands over the fighter's body.
func set_referee(look: Dictionary) -> void:
	set_clothes(look, SHIRT_WHITE, SHIRT_BLACK, TROUSERS, SHOES)


## A cornerman's clothes (D391): a plain shirt in his corner's `colour`, dark trousers and shoes.
const CORNER_TROUSERS := Color(0.08, 0.08, 0.09)


## Dresses the body as one of a fighter's corner team (D391): his skin and hair as `look`, a shirt in the corner's
## `colour` (the referee's clothes without the stripes) and dark trousers.
func set_cornerman(look: Dictionary, colour: Color) -> void:
	var shirt: Color = colour.lerp(Color.WHITE, 0.1)
	set_clothes(look, shirt, shirt, CORNER_TROUSERS, SHOES)


## Clothes over the body from the clothes mask (D373): the shirt and its stripes, trousers and shoes in these colours,
## his skin and hair as `look`.
func set_clothes(look: Dictionary, shirt: Color, stripes: Color, trousers: Color, shoes: Color) -> void:
	set_look(Color.WHITE, look)
	var clothes: Texture2D = load(CLOTHES) if ResourceLoader.exists(CLOTHES) else null
	if clothes == null:
		return
	for found: Node in find_children("*", "MeshInstance3D", true, false):
		var dressed: ShaderMaterial = (found as MeshInstance3D).material_override as ShaderMaterial
		if dressed == null:
			continue
		dressed.set_shader_parameter("clothes", clothes)
		dressed.set_shader_parameter("has_clothes", true)
		dressed.set_shader_parameter("shirt_white", shirt)
		dressed.set_shader_parameter("shirt_black", stripes)
		dressed.set_shader_parameter("trousers", trousers)
		dressed.set_shader_parameter("shoes", shoes)


## Damage on the body (D375-D378, tools/body_regions.py): round each eye, his ribs and where he flushes (damage.png),
## the cuts over his eyebrows with their trickles, and each leg (marks.png).
const DAMAGE_ZONES := "res://game/bodies/tripo_fighter_damage.png"
const DAMAGE_MARKS := "res://game/bodies/tripo_fighter_marks.png"
## How far (metres) an eye swells out at its worst.
const SWELL_SIZE: float = 0.008


## Shows `marks` (BodyMarks) on the body: swelling and bruises, cuts and their blood, blood on his gloves, sweat and
## flush. Call after set_look; again whenever the marks change.
func set_damage(marks: BodyMarks) -> void:
	for found: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = found
		var skin: ShaderMaterial = mesh.material_override as ShaderMaterial
		if skin == null:
			continue
		if skin.get_shader_parameter("has_damage") != true:
			if not ResourceLoader.exists(DAMAGE_ZONES) or not ResourceLoader.exists(DAMAGE_MARKS):
				return
			skin.set_shader_parameter("damage_zones", load(DAMAGE_ZONES))
			skin.set_shader_parameter("damage_marks", load(DAMAGE_MARKS))
			if ResourceLoader.exists(CLOTHES):
				skin.set_shader_parameter("clothes", load(CLOTHES))  # Only its hands, for blood on his gloves.
			skin.set_shader_parameter("swell_size", SWELL_SIZE / maxf(mesh.global_basis.get_scale().y, 0.001))
			skin.set_shader_parameter("has_damage", true)
		skin.set_shader_parameter("swell", Vector2(marks.swell[0], marks.swell[1]))
		skin.set_shader_parameter("body_mark", marks.body)
		skin.set_shader_parameter("leg_mark", Vector2(marks.legs[0], marks.legs[1]))
		skin.set_shader_parameter("cut", Vector2(float(marks.cut[0]), float(marks.cut[1])))
		skin.set_shader_parameter("bleed", Vector2(marks.bleed[0], marks.bleed[1]))
		skin.set_shader_parameter("glove_blood", marks.glove_blood)
		skin.set_shader_parameter("sweat", marks.sweat)
		skin.set_shader_parameter("flush", marks.flush)


## Where his hips are now, in the world.
func hips_at() -> Vector3:
	return _world_at("Hips")


static var _shader: Shader


## Light, colourless texels in the shorts take the corner's tint; skin takes the look's tone (each texel shaded as the
## body's own skin is there), hair and eyebrows its hair colour (a shaved scalp shows skin), and the beard's zone
## darkens toward the hair colour by the beard. Gloves, eyes and the shorts' dark panels stay as they are.
static func _tint_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D regions : hint_default_black, filter_linear_mipmap;
uniform bool has_regions = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 skin : source_color = vec4(0.745, 0.525, 0.384, 1.0);
uniform vec4 hair : source_color = vec4(0.21, 0.17, 0.14, 1.0);
uniform vec4 body_skin : source_color = vec4(0.745, 0.525, 0.384, 1.0);
uniform vec4 body_hair : source_color = vec4(0.21, 0.17, 0.14, 1.0);
uniform float skin_detail = 0.5;
uniform float hair_kept = 1.0;
uniform float beard = 0.0;
uniform float hair_sink = 0.0;
uniform sampler2D clothes : hint_default_black, filter_linear_mipmap;
uniform bool has_clothes = false;
uniform vec4 shirt_white : source_color = vec4(0.86, 0.86, 0.84, 1.0);
uniform vec4 shirt_black : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 trousers : source_color = vec4(0.3, 0.31, 0.33, 1.0);
uniform vec4 shoes : source_color = vec4(0.04, 0.04, 0.045, 1.0);
uniform sampler2D damage_zones : hint_default_black, filter_linear_mipmap;
uniform sampler2D damage_marks : hint_default_black, filter_linear_mipmap;
uniform bool has_damage = false;
uniform vec2 swell = vec2(0.0);
uniform float swell_size = 0.0;
uniform float body_mark = 0.0;
uniform vec2 leg_mark = vec2(0.0);
uniform vec2 cut = vec2(0.0);
uniform vec2 bleed = vec2(0.0);
uniform float glove_blood = 0.0;
uniform float sweat = 0.0;
uniform float flush = 0.0;
uniform vec3 bruise_fresh = vec3(1.0, 0.45, 0.4);
uniform vec3 bruise_old = vec3(0.45, 0.25, 0.45);
uniform vec4 blood : source_color = vec4(0.42, 0.02, 0.03, 1.0);
uniform vec3 flushed = vec3(1.08, 0.84, 0.8);
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
void vertex() {
	// A buzzed or shaved head: the hair's shell sinks in toward the scalp.
	if (has_regions && hair_sink > 0.0) {
		VERTEX -= NORMAL * hair_sink * textureLod(regions, UV, 0.0).r;
	}
	// A swollen eye (D377) puffs out round it.
	if (has_damage) {
		vec4 z = textureLod(damage_zones, UV, 0.0);
		float brows = has_regions ? textureLod(regions, UV, 0.0).b : 0.0;
		VERTEX += NORMAL * swell_size * (z.r * swell.x + z.g * swell.y) * (1.0 - brows);
	}
}
float blot(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	vec4 m = has_regions ? texture(regions, UV) : vec4(0.0, 0.0, 0.0, 1.0);
	float top = max(c.r, max(c.g, c.b));
	float sat = (top - min(c.r, min(c.g, c.b))) / max(top, 0.001);
	float grey = (1.0 - smoothstep(0.1, 0.22, sat)) * smoothstep(0.3, 0.5, top) * m.a;
	// Skin: an even tone shaded as the body's skin is here, with some of the texture's own colour kept.
	float shade = lum(c) / lum(body_skin.rgb);
	vec3 toned = mix(skin.rgb * shade, c * skin.rgb / max(body_skin.rgb, vec3(0.001)), skin_detail);
	float is_skin = smoothstep(0.3, 0.5, sat) * (1.0 - m.r) * (1.0 - m.b) * (1.0 - m.a);
	vec3 out_c = mix(c, toned, is_skin);
	// Hair and eyebrows in his hair colour, shaded as the body's hair is; a shaved scalp is skin in the hair's shading.
	float hair_shade = clamp(lum(c) / lum(body_hair.rgb), 0.0, 3.0);
	vec3 dyed = hair.rgb * hair_shade;
	vec3 scalp = skin.rgb * clamp(hair_shade * 0.55 + 0.35, 0.0, 1.1);
	out_c = mix(out_c, mix(scalp, dyed, hair_kept), m.r);
	out_c = mix(out_c, dyed, m.b);
	// The beard darkens the skin toward his hair colour.
	out_c = mix(out_c, hair.rgb * shade * 1.2, m.g * beard * is_skin);
	out_c = mix(out_c, tint.rgb * (0.35 + 0.75 * top), grey);
	float wet = 0.0;
	if (has_damage) {
		// Damage on the body (D375-D378): bruises red going purple round each eye, on his ribs and each leg; the
		// flush of a tired man; a cut over an eyebrow and the blood trickling from it; blood on his gloves.
		vec4 z = texture(damage_zones, UV);
		vec4 k = texture(damage_marks, UV);
		float skin_only = is_skin * (1.0 - m.r) * (1.0 - m.b);
		vec2 eyes = vec2(z.r, z.g) * swell;
		float limbs = max(min(z.b * 1.3, 1.0) * body_mark, max(k.b * leg_mark.x, k.a * leg_mark.y)) * mix(0.45, 1.0, blot(UV * 45.0));
		float marked = max(max(eyes.x, eyes.y) * 1.25, limbs);
		vec3 bruise = mix(bruise_fresh, bruise_old, smoothstep(0.35, 0.9, marked));
		out_c *= mix(vec3(1.0), bruise, clamp(marked * 0.9, 0.0, 0.75) * skin_only);
		out_c *= mix(vec3(1.0), flushed, z.a * flush * skin_only);
		vec2 run = vec2(k.r, k.g);
		vec2 shown = cut * smoothstep(1.0 - bleed - 0.04, 1.0 - bleed, run) * step(0.03, run);
		vec2 opened = cut * smoothstep(0.96, 0.99, run);
		float bloody = max(max(shown.x, shown.y), 0.0);
		out_c = mix(out_c, blood.rgb, bloody);
		out_c = mix(out_c, blood.rgb * 0.45, max(opened.x, opened.y));
		wet = max(bloody, max(opened.x, opened.y));
		if (has_clothes == false && glove_blood > 0.0) {
			vec4 h = texture(clothes, UV);
			float hands = h.g * (1.0 - h.r) * (1.0 - h.b) * (1.0 - h.a);
			float smear = smoothstep(0.78 - 0.45 * glove_blood, 0.92 - 0.45 * glove_blood, blot(UV * 140.0));
			out_c = mix(out_c, blood.rgb * 0.8, hands * smear * 0.85);
			wet = max(wet, hands * smear);
		}
		ROUGHNESS = mix(0.85, 0.4, max(sweat * skin_only, wet * 0.8));
		SPECULAR = 0.5 + 0.25 * sweat * skin_only;
	} else {
		ROUGHNESS = 0.85;
	}
	if (has_clothes) {
		// The referee (D373): clothes shaded as the body's own texture is shaded there, and his gloves bare hands.
		vec4 k = texture(clothes, UV);
		float cloth_shade = clamp(lum(c) / lum(body_skin.rgb), 0.55, 1.15);
		vec3 shirt = mix(shirt_white.rgb, shirt_black.rgb, smoothstep(0.35, 0.65, k.g)) * cloth_shade;
		out_c = mix(out_c, trousers.rgb * cloth_shade, k.b * (1.0 - k.r));
		out_c = mix(out_c, shirt, k.r);
		out_c = mix(out_c, shoes.rgb * cloth_shade, k.a);
		out_c = mix(out_c, skin.rgb * 0.85, k.g * (1.0 - k.r) * (1.0 - k.b) * (1.0 - k.a));
	}
	ALBEDO = out_c;
}
"""
	return _shader


## The body's sizes at rest, in metres, for FighterRig.fit: the rig it follows gets its trunk and limbs.
func measure() -> Dictionary:
	var arm: Vector3 = _at("RightArm") - _at("Spine1")
	return {
		"waist_up": _at("Spine1").y - _pelvis_rest.y,
		"neck_up": _at("Neck").y - _at("Spine1").y,
		"head_up": Vector3(0, _at("Head").y - _at("Neck").y, _at("Head").z - _at("Neck").z),
		"shoulder": Vector3(absf(arm.x), arm.y, arm.z),
		"hip_x": absf(_at("RightUpLeg").x - _pelvis_rest.x),
		"upper_arm": _at("RightArm").distance_to(_at("RightForeArm")) * _arm_length,
		"forearm": _at("RightForeArm").distance_to(_at("RightHand")) * _arm_length,
		"thigh": _at("RightUpLeg").distance_to(_at("RightLeg")),
		"shin": _at("RightLeg").distance_to(_at("RightFoot")),
		"ankle_up": _at("RightFoot").y,
	}


func _at(bone: String) -> Vector3:
	return Transform3D(_rest_world[bone]).origin


## Poses the body as `rig` stands now (call after FighterRig.pose_pair).
func follow(rig: FighterRig) -> void:
	var pose := {}
	for key: String in ["pelvis", "waist", "neck", "head", "foot_l", "foot_r"]:
		var node: Node3D = rig.bones[key]
		pose["chest" if key == "waist" else key] = node.global_basis.orthonormalized()
	pose.pelvis_at = rig.bones.pelvis.global_position
	pose.merge(rig.joints)
	follow_joints(pose)


## Poses the body from joints in the world (D284, D285): `pelvis_at` (the hip joints' middle); the turns of
## `pelvis`, `chest`, `neck`, `head`, `foot_l` and `foot_r` (bases, the identity standing facing -Z); and the
## positions `shoulder_l`, `elbow_l`, `wrist_l`, `hip_l`, `knee_l`, `ankle_l` and the right side's; and,
## optionally, `ankle_up`, the driver's ankle height over the sole (the body's ankle sits higher or lower, so
## its ankles are moved along the feet to keep the soles where the driver's are). Any skeleton (the rig,
## today's figures) can drive the body through this. `only` ("arm_l", "leg_r", ...) re-poses just those limbs
## and leaves the rest as it is (D286: a strike thrown from the clinch pose).
func follow_joints(pose: Dictionary, only: Array[String] = []) -> void:
	var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
	if only.is_empty():
		_follow_trunk(pose, Vector3(pose.pelvis_at), to_skeleton)
	var sink: float = 0.0
	if only.is_empty() and pose.has("shoulders_at"):
		# A driver with a longer trunk than the body's (the faceted pieces): the body's hips move along so its
		# shoulders are where the driver's are and the arms start from the right place. Its legs take up the gap.
		var shoulders: Vector3 = (_anchored("LeftArm") + _anchored("RightArm")) / 2.0
		var hips_at: Vector3 = Vector3(pose.pelvis_at) + Vector3(pose.shoulders_at) - shoulders
		_follow_trunk(pose, hips_at, to_skeleton)
		# Lifting his hips to the pieces' shoulders can leave a foot on the canvas out of reach: the leg locked straight
		# and the foot hanging off the canvas or sliding (D395). He sinks until both planted feet reach.
		sink = _sink_to_feet(pose)
		if sink > 0.0:
			_follow_trunk(pose, hips_at + Vector3.DOWN * sink, to_skeleton)
	# The limbs, in the body's own lengths, to the driver's wrists and ankles.
	for limb: Array in LIMBS:
		var side: String = limb[3]
		var arm: bool = limb[4] == "arm"
		if not only.is_empty() and not only.has(String(limb[4]) + "_" + side):
			continue
		var upper: String = limb[0]
		var lower: String = limb[1]
		var end: String = limb[2]
		var root: Vector3 = _anchored(upper)
		var middle_at: Vector3 = pose[("elbow_" if arm else "knee_") + side]
		var end_at: Vector3 = pose[("wrist_" if arm else "ankle_") + side]
		if not arm and pose.has("ankle_up"):
			end_at += Basis(pose["foot_" + side]).y * (_at("RightFoot").y - float(pose.ankle_up))
		# Nothing reaches through the canvas (D396), whatever drives him.
		end_at.y = maxf(end_at.y, FighterRig.HAND_FLOOR if arm else _at("RightFoot").y * FighterRig.FOOT_FLOOR)
		var first: float = Transform3D(_rest_world[upper]).origin.distance_to(Transform3D(_rest_world[lower]).origin)
		var second: float = Transform3D(_rest_world[lower]).origin.distance_to(Transform3D(_rest_world[end]).origin)
		if arm:
			first *= _arm_length
			second *= _arm_length
		if arm and pose.has("shoulders_at"):
			# The pieces' arms are longer: a bent arm keeps the pieces' bend (so an arm round a man's back goes
			# round him, not straight through), and only a nearly straight one, a punch, reaches for the glove.
			var shoulder_at: Vector3 = pose["shoulder_" + side]
			var piece_reach: float = shoulder_at.distance_to(middle_at) + middle_at.distance_to(end_at)
			var straight: float = shoulder_at.distance_to(end_at) / maxf(piece_reach, 0.001)
			var reaching: float = smoothstep(STRAIGHT_FROM, STRAIGHT_AT, straight)
			# Sunk to his feet (D395): a bent arm comes down with him, keeping his guard where it is on him.
			end_at += Vector3.DOWN * sink * (1.0 - reaching)
			middle_at += Vector3.DOWN * sink * (1.0 - reaching)
			var bent_at: Vector3 = root + (end_at - root).normalized() * straight * (first + second)
			end_at = bent_at.lerp(end_at, reaching)
		if arm and root.distance_to(end_at) > first + second:
			root = _reach_with_shoulder(("Left" if side == "l" else "Right") + "Shoulder", root, end_at,
				root.distance_to(end_at) - first - second, to_skeleton)
		var root_at: Vector3 = pose[("shoulder_" if arm else "hip_") + side]
		var bend: Vector3 = middle_at - root_at.lerp(end_at, 0.5)
		if not arm:
			# A nearly straight leg's knee barely leaves the line from hip to ankle, so which way it bends would swing
			# about from frame to frame (sunk to his feet, his legs bend more than the driver's): knees bend forward,
			# so they lean that way unless the driver's knee points somewhere clearly (D395).
			bend += Basis(pose.pelvis) * Vector3.FORWARD * KNEE_FORWARD
		elif pose.has("shoulders_at"):
			# The same for the pieces' nearly straight arm (a punch at full stretch, from the feet, the clinch or the
			# ground): elbows hang down and out, so it leans that way instead of turning over from one frame to the next
			# (D396). A rig's arms (round a man's back) bend where their poles put them.
			var out: Vector3 = Vector3.LEFT if side == "l" else Vector3.RIGHT
			bend += Basis(pose.chest) * (Vector3.DOWN + out * 0.5).normalized() * ELBOW_DOWN
		var chain: Array[Vector3] = FighterMotion.solve_bones(root, end_at, bend, first, second)
		var strike_key: String = "joint_strike_" + String(limb[4]) + "_" + side
		if pose.has(strike_key):
			var strike: Dictionary = pose[strike_key]
			chain = FighterMotion.strike_joint(root, chain, strike.target, strike.fold, float(strike.weight), first, second)
		var middle: Vector3 = chain[0]
		var tip: Vector3 = chain[1]
		_aim_bone(upper, lower, root, middle, bend, arm, to_skeleton)
		_aim_bone(lower, end, middle, tip, bend, arm, to_skeleton)
		var end_turn: Basis
		if arm:  # The hand carries on along the forearm.
			var fore: Basis = (skeleton.global_transform.basis * skeleton.get_bone_global_pose(_ids[lower]).basis).orthonormalized()
			end_turn = fore * Transform3D(_rest_world[lower]).basis.orthonormalized().inverse()
		else:  # The foot copies the driver's foot.
			end_turn = pose["foot_" + side]
		_set_world(end, Transform3D(end_turn * Transform3D(_rest_world[end]).basis, tip), to_skeleton)


## The trunk: each bone turned as the driver's bone is turned from standing, the hips at `pelvis_at`.
func _follow_trunk(pose: Dictionary, pelvis_at: Vector3, to_skeleton: Transform3D) -> void:
	var rig_bone := {"pelvis": "pelvis", "waist": "chest", "neck": "neck", "head": "head"}
	for entry: Array in TRUNK:
		var bone: String = entry[0]
		var turn: Basis = pose[rig_bone[entry[1]]]
		if float(entry[2]) < 1.0:
			turn = Basis(Quaternion(Basis(pose.pelvis)).slerp(Quaternion(turn), float(entry[2])))
		var rest: Transform3D = _rest_world[bone]
		var world := Transform3D(turn * rest.basis, rest.origin)
		if bone == "Hips":
			world.origin = pelvis_at + turn * (rest.origin - _pelvis_rest)
		else:
			world.origin = _anchored(bone)
		_set_world(bone, world, to_skeleton)
		if bone == "Spine2":
			for shoulder: String in ["LeftShoulder", "RightShoulder"]:
				_set_world(shoulder, Transform3D(turn * Transform3D(_rest_world[shoulder]).basis, _anchored(shoulder)), to_skeleton)


## Sinking his hips to his feet (D395): a foot this low (metres) is on the canvas; the leg reaching it may be this
## straight (hip to ankle over the leg's length) at most; and he sinks this far at most.
const PLANTED_BELOW: float = 0.2
const LEG_REACH: float = 0.985
const SINK_MAX: float = 0.2
## How hard (metres) a knee leans forward of his hips when the driver's knee hardly says which way it bends.
const KNEE_FORWARD: float = 0.08
## How hard (metres) an elbow leans down and out when the driver's elbow hardly says which way it bends (D396).
const ELBOW_DOWN: float = 0.04


## How far (metres) his hips must come down, as posed now, for each foot on the canvas in `pose` to be in reach.
func _sink_to_feet(pose: Dictionary) -> float:
	var sink: float = 0.0
	for limb: Array in LIMBS:
		if limb[4] != "leg":
			continue
		var side: String = limb[3]
		var end_at: Vector3 = _foot_target(pose, side)
		if end_at.y > PLANTED_BELOW:
			continue  # A kick or a knee up: free to straighten.
		var reach: float = (_at(limb[0]).distance_to(_at(limb[1])) + _at(limb[1]).distance_to(_at(limb[2]))) * LEG_REACH
		var gap: Vector3 = _anchored(limb[0]) - end_at
		var across: float = Vector2(gap.x, gap.z).length()
		if across >= reach:
			continue  # Out of reach whatever the height: sinking wouldn't bring it back.
		sink = maxf(sink, gap.y - sqrt(reach * reach - across * across))
	return minf(sink, SINK_MAX)


## Where the driver's `side` ankle wants this body's ankle (its ankle height over the sole may differ).
func _foot_target(pose: Dictionary, side: String) -> Vector3:
	var end_at: Vector3 = pose["ankle_" + side]
	if pose.has("ankle_up"):
		end_at += Basis(pose["foot_" + side]).y * (_at("RightFoot").y - float(pose.ankle_up))
	return end_at


## How far a shoulder blade may turn to carry a hand that's out of reach (radians): a punch throws the shoulder.
const SHOULDER_REACH: float = 0.5
## Following a longer-armed driver, an arm straighter than STRAIGHT_FROM (shoulder to wrist over the arm's length)
## starts reaching for the driver's hand, and from STRAIGHT_AT on goes all the way; a more bent arm keeps its bend.
const STRAIGHT_FROM: float = 0.85
const STRAIGHT_AT: float = 0.96


## Turns the shoulder blade `bone` so the arm's root at `root` comes `short` metres toward `target` (as far as
## SHOULDER_REACH allows), as a man throws his shoulder into a long punch. Returns where the arm now starts.
func _reach_with_shoulder(bone: String, root: Vector3, target: Vector3, short: float, to_skeleton: Transform3D) -> Vector3:
	var pivot: Vector3 = _world_at(bone)
	var out: Vector3 = root - pivot
	var axis: Vector3 = out.cross(target - pivot)
	if axis.length() < 0.0001:
		return root
	var angle: float = minf(short / out.length(), SHOULDER_REACH)
	var turn := Basis(axis.normalized(), angle)
	var now: Basis = (skeleton.global_transform.basis * skeleton.get_bone_global_pose(_ids[bone]).basis).orthonormalized()
	_set_world(bone, Transform3D(turn * now, pivot), to_skeleton)
	return pivot + turn * out


## Shows the next poses easing in over `seconds` from the pose shown now, instead of jumping to them (D286: from
## today's figures into the clinch from the rig and back, or from one grip to the next). Run settle after each pose.
func ease_over(seconds: float) -> void:
	_ease_left = seconds


## Call once a frame after posing the body: while easing (ease_over), each bone is shown part of the way from
## last frame's pose to the new one, arriving when the time is up.
##
## A new pose that would throw a hand, foot, elbow, knee or his head further from his hips in one frame than a body
## can move (POP_SPEED: one move handing over to another, the pair turned round, a pose built afresh) is eased in
## too, over the time it takes at EASE_SPEED (D396), and an ease_over too short for how far the pose moves is
## lengthened the same way.
func settle(delta: float) -> void:
	var count: int = skeleton.get_bone_count()
	if _shown.size() == count and not _shown_world.is_empty() and delta > 0.0:
		var moved: float = _furthest_move()
		if moved > POP_SPEED * delta or _ease_left > 0.0:
			_ease_left = maxf(_ease_left, minf(moved / EASE_SPEED, EASE_MAX))
		if _furthest_turn() > FLIP_TURN:  # An elbow or knee swinging right round its limb in a frame.
			_ease_left = maxf(_ease_left, FLIP_EASE)
	if _ease_left > 0.0 and _shown.size() == count:
		var t: float = clampf(delta / _ease_left, 0.0, 1.0)
		for id in count:
			skeleton.set_bone_pose(id, _shown[id].interpolate_with(skeleton.get_bone_pose(id), t))
		_ease_left -= delta
		_lift_off_canvas()
	_keep_out()
	_remember_shown()


## Keeps this body out of the other man's trunk again (`avoid` set afresh), once he's settled too (D397).
func keep_out() -> void:
	_keep_out()
	_remember_shown()


## Moves the whole posed body without changing its limbs, and remembers the corrected result (D422).
func translate_pose(offset: Vector3) -> void:
	var id: int = _ids.Hips
	var local_offset: Vector3 = skeleton.global_transform.basis.inverse() * offset
	skeleton.set_bone_pose_position(id, skeleton.get_bone_pose_position(id) + local_offset)
	_remember_shown()


## What's shown now, to ease the next pose from and to measure its jumps against.
func _remember_shown() -> void:
	var count: int = skeleton.get_bone_count()
	_shown.resize(count)
	for id in count:
		_shown[id] = skeleton.get_bone_pose(id)
	for bone: String in TRACKED + LIMB_ROOTS:
		_shown_world[bone] = _world_at(bone)


## Part way between two poses each bone is turned part of the way, which can swing a limb down through the canvas (a
## man lying turned over, a scramble): he's lifted until his lowest joint is back on it (D396).
func _lift_off_canvas() -> void:
	var lowest: float = INF
	for bone: String in TRACKED:
		lowest = minf(lowest, _world_at(bone).y)
	if lowest >= CANVAS_FLOOR:
		return
	var id: int = _ids.Hips
	var up: Vector3 = skeleton.global_transform.basis.inverse() * Vector3.UP * (CANVAS_FLOOR - lowest)
	skeleton.set_bone_pose_position(id, skeleton.get_bone_pose_position(id) + up)


## The other man's trunk, the line from his hips to his chest in the world (set each frame before settle; empty
## when there's no one to keep out of): no hand, foot, elbow or knee of this body is shown inside it (D397).
var avoid: Array[Vector3] = []


## The line up the middle of this body's trunk, its hips to its chest, in the world (D397).
func trunk() -> Array[Vector3]:
	return [_world_at("Hips"), _world_at("Spine2")]


## Any limb with its hand or foot, elbow or knee inside the other man's trunk (`avoid`) is posed again, the hand or
## foot put on him and the elbow or knee turned round the limb out of him (FighterRig.out_of, clear_of; D397). The
## rig keeps its poses out of him already; this catches what the body adds: easing between two poses (a sweep turning
## them over, getting up from underneath), its own lengths and the pieces' strikes.
func _keep_out() -> void:
	if avoid.size() != 2 or skeleton == null:
		return
	var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
	for limb: Array in LIMBS:
		var upper: String = limb[0]
		var lower: String = limb[1]
		var end: String = limb[2]
		var root: Vector3 = _world_at(upper)
		var middle: Vector3 = _world_at(lower)
		var tip: Vector3 = _world_at(end)
		if _out_by(middle) >= FighterRig.TRUNK_RADIUS and _out_by(tip) >= FighterRig.TRUNK_RADIUS:
			continue
		var tip_turn: Basis = (skeleton.global_transform.basis * skeleton.get_bone_global_pose(_ids[end]).basis).orthonormalized()
		var to: Vector3 = FighterRig.out_of(tip, avoid[0], avoid[1])
		var chain: Array[Vector3] = FighterMotion.solve_bones(root, to, middle - root.lerp(to, 0.5),
			root.distance_to(middle), middle.distance_to(tip))
		var bent_at: Vector3 = FighterRig.clear_of(root, chain[0], chain[1], avoid)
		var bend: Vector3 = bent_at - root.lerp(chain[1], 0.5)
		var arm: bool = limb[4] == "arm"
		_aim_bone(upper, lower, root, bent_at, bend, arm, to_skeleton)
		_aim_bone(lower, end, bent_at, chain[1], bend, arm, to_skeleton)
		_set_world(end, Transform3D(tip_turn, chain[1]), to_skeleton)


## How far `point` is from the middle line of the other man's trunk.
func _out_by(point: Vector3) -> float:
	return point.distance_to(FighterRig.closest_on(point, avoid[0], avoid[1]))


## The lowest a joint's middle may be shown while easing (metres above the canvas).
const CANVAS_FLOOR: float = 0.03


## Faster than this (m/s, a hand, foot, elbow, knee or the head against his hips) a pose has jumped, not moved: the
## quickest kicks are about 15.
const POP_SPEED: float = 20.0
## How fast a jumped pose is eased in (m/s, the joint that moves furthest), taking at most EASE_MAX seconds.
const EASE_SPEED: float = 5.0
const EASE_MAX: float = 0.4
## The joints watched for a jump (and the hips they're measured from).
const TRACKED: Array[String] = ["Hips", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "LeftForeArm",
	"RightForeArm", "LeftLeg", "RightLeg"]
## Further than this (radians) round its limb in one frame an elbow or knee has flipped, not moved, and the pose is
## eased in over FLIP_EASE seconds (D396): a strike's arm handed from one way of bending to another.
const FLIP_TURN: float = PI / 3.0
const FLIP_EASE: float = 0.12
## Bent less than this (metres off the line from its root to its end) a limb's bend isn't watched: a straight limb
## can turn its elbow any way without it showing.
const FLIP_BENT: float = 0.06
## The limbs' roots, watched with TRACKED to see a bend flip.
const LIMB_ROOTS: Array[String] = ["LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg"]
## Where TRACKED were shown last frame, in the world.
var _shown_world := {}


## How far (radians) the elbow or knee that turns furthest round its limb has turned from how it was shown last frame
## to the pose set now, counting only limbs bent at least FLIP_BENT both times.
func _furthest_turn() -> float:
	var furthest: float = 0.0
	for limb: Array in LIMBS:
		if not _shown_world.has(limb[0]):
			continue
		var was: Vector3 = _bend(_shown_world[limb[0]], _shown_world[limb[1]], _shown_world[limb[2]])
		var now: Vector3 = _bend(_world_at(limb[0]), _world_at(limb[1]), _world_at(limb[2]))
		if was.length() >= FLIP_BENT and now.length() >= FLIP_BENT:
			furthest = maxf(furthest, was.angle_to(now))
	return furthest


## Which way and how far a limb's middle sits off the line from its root to its end.
static func _bend(root: Vector3, middle: Vector3, end: Vector3) -> Vector3:
	var line: Vector3 = end - root
	var off: Vector3 = middle - root
	return off - off.project(line) if line.length() > 0.001 else off


## How far (metres) the joint that moves furthest against his hips has gone from where it was shown last frame to the
## pose set now.
func _furthest_move() -> float:
	var hips: Vector3 = _world_at("Hips")
	var hips_was: Vector3 = _shown_world.Hips
	var furthest: float = 0.0
	for bone: String in TRACKED:
		if bone != "Hips":
			furthest = maxf(furthest, ((_world_at(bone) - hips) - (Vector3(_shown_world[bone]) - hips_was)).length())
	return furthest


## Where `bone` is in the world as posed now.
func _world_at(bone: String) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(_ids[bone])).origin


## Where `bone` belongs in the world: its rest place on its parent as the parent is posed now. Posing a bone from
## where it already was let a stale reading carry it a little further each frame, until an arm hung metres from
## its shoulder by the end of a long fight; starting each bone from its parent keeps it joined on.
func _anchored(bone: String) -> Vector3:
	var id: int = _ids[bone]
	var parent: int = skeleton.get_bone_parent(id)
	if parent < 0:
		return _world_at(bone)
	return (skeleton.global_transform * skeleton.get_bone_global_pose(parent) * skeleton.get_bone_rest(id)).origin


## Turns `bone` (whose child is `child`) so it runs from `from` to `to`, bent toward `bend`.
func _aim_bone(bone: String, child: String, from: Vector3, to: Vector3, bend: Vector3, arm: bool, to_skeleton: Transform3D) -> void:
	var rest: Transform3D = _rest_world[bone]
	var rest_dir: Vector3 = Transform3D(_rest_world[child]).origin - rest.origin
	# At rest an elbow bends back (+Z for a body facing -Z) and a knee forward (-Z).
	var rest_bend := Vector3(0, 0, 1) if arm else Vector3(0, 0, -1)
	var turn: Basis = _frame(to - from, bend) * _frame(rest_dir, rest_bend).inverse()
	_set_world(bone, Transform3D(turn * rest.basis, from), to_skeleton)


## An orthonormal basis whose Y runs along `along` and whose Z leans toward `toward`.
static func _frame(along: Vector3, toward: Vector3) -> Basis:
	var y: Vector3 = along.normalized()
	var z: Vector3 = toward - toward.project(y)
	if z.length() < 0.0001:
		z = Vector3.FORWARD - Vector3.FORWARD.project(y)
	z = z.normalized()
	return Basis(y.cross(z), y, z)


func _set_world(bone: String, world: Transform3D, to_skeleton: Transform3D) -> void:
	var local: Transform3D = to_skeleton * world
	# Keep the bones' own scale (the body's scale lives on the scene above the skeleton).
	local.basis = local.basis.orthonormalized()
	if _bone_scale.has(bone):
		local.basis = local.basis * Basis.from_scale(_bone_scale[bone])  # His build (D364), in the bone's own frame.
	skeleton.set_bone_global_pose(_ids[bone], local)
