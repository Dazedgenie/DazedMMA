"""Bakes the skinned body's region mask (D364, docs/13 "Fighters who look different").

The body (game/bodies/tripo_fighter.glb) has one texture with skin, hair and shorts painted in. The look shader
(SkinnedBody.set_look) recolours them, and needs to know which texels are which. This finds them from where each
texel sits on the body (in the file's bind pose: +X forward, Y up, the body 1.0 tall) and what colour it is, and
writes game/bodies/tripo_fighter_regions.png (1024 x 1024, RGBA):
  red    the hair on his head (dark texels over the hairline, down the back and the sides)
  green  where a beard grows (skin on the jaw, chin and upper lip, fading out at the cheeks; not the lips)
  blue   his eyebrows
  alpha  his shorts (colourless texels round the hips)
and game/bodies/tripo_fighter_clothes.png, the referee's clothes over the same body (D373):
  red    his shirt (the trunk from the waist to the collar, and short sleeves)
  green  the shirt's black stripes, upright round the trunk and round each sleeve; with no red, his bare hands
  blue   his trousers (the hips and legs down to the ankles)
  alpha  his shoes
and game/bodies/tripo_fighter_damage.png, where damage shows on a fighter (D375-D378):
  red    round his left eye (it swells and bruises), green round his right eye
  blue   his ribs and stomach (body shots mark them)
  alpha  where he flushes when he's tired (his face, neck and upper chest)
and game/bodies/tripo_fighter_marks.png:
  red    a cut over his left eyebrow and the line its blood trickles down (1 at the cut, falling to 0.05 at the end of
         the trickle, so the trickle grows by showing more of it), green the same over his right eyebrow
  blue   his left leg where kicks mark it (outside and front of the thigh, and the calf), alpha his right leg
His left is -Z in the file.
Only needed again if the body file changes:  python3 tools/body_regions.py
Needs numpy and Pillow. The heights and limits below are this body's; another body needs its own.
"""
import json, os, struct, sys
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GLB = os.path.join(HERE, '..', 'game', 'bodies', 'tripo_fighter.glb')
TEX = os.path.join(HERE, '..', 'game', 'bodies', 'tripo_fighter_low-poly_fighter_3d_model_basecolor.jpg')
OUT = os.path.join(HERE, '..', 'game', 'bodies', 'tripo_fighter_regions.png')
CLOTHES = os.path.join(HERE, '..', 'game', 'bodies', 'tripo_fighter_clothes.png')
DAMAGE = os.path.join(HERE, '..', 'game', 'bodies', 'tripo_fighter_damage.png')
MARKS = os.path.join(HERE, '..', 'game', 'bodies', 'tripo_fighter_marks.png')
SIZE = 1024
COMPONENT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def load(path):
    """The body's first mesh: positions, UVs, joints, weights and triangles, and the skin's joint names."""
    data = open(path, 'rb').read()
    length = struct.unpack('<I', data[12:16])[0]
    doc = json.loads(data[20:20 + length])
    at = 20 + length
    blob = data[at + 8:at + 8 + struct.unpack('<I', data[at:at + 4])[0]]

    def accessor(i):
        a = doc['accessors'][i]
        view = doc['bufferViews'][a['bufferView']]
        n, kind = WIDTH[a['type']], COMPONENT[a['componentType']]
        start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = view.get('byteStride', n * np.dtype(kind).itemsize)
        rows = [np.frombuffer(blob, dtype=kind, count=n, offset=start + k * stride) for k in range(a['count'])]
        return np.array(rows)

    prim = doc['meshes'][0]['primitives'][0]
    attrs = prim['attributes']
    mesh = {
        'pos': accessor(attrs['POSITION']).astype(float), 'uv': accessor(attrs['TEXCOORD_0']).astype(float),
        'joints': accessor(attrs['JOINTS_0']).astype(int), 'weights': accessor(attrs['WEIGHTS_0']).astype(float),
        'tris': accessor(prim['indices']).reshape(-1, 3).astype(int),
    }
    names = [doc['nodes'][k]['name'] for k in doc['skins'][0]['joints']]
    return mesh, names


def classify(p, colour, hand):
    """The regions for texels at body points `p` with texture colours `colour` (0-1) and hand weights `hand`."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    value = colour.max(1)
    sat = (value - colour.min(1)) / np.maximum(value, 1e-3)
    dark = value < 0.38
    head = y > 0.875
    brows = head & dark & (x > 0.04) & (y > 0.932) & (y < 0.946) & (np.abs(z) > 0.006)
    hair = head & dark & ((y > 0.945) | ((x < 0.0) & (y > 0.885)) | ((np.abs(z) > 0.045) & (y > 0.925) & (x < 0.035))) & ~brows
    lips = (y > 0.878) & (y < 0.889) & (np.abs(z) < 0.022) & (x > 0.05)
    beard = ((y > 0.85) & ~dark & (x > -0.012) & (np.abs(z) < 0.058) & ~lips).astype(float)
    beard *= np.clip((0.907 - y) / 0.01, 0, 1) * np.clip((y - 0.855) / 0.012, 0, 1)
    shorts = (y > 0.33) & (y < 0.64) & (hand < 0.5) & (sat < 0.25)
    return np.stack([hair, beard, brows, shorts], 1).astype(float)


# The referee's clothes (D373), in the body's bind pose (1.0 tall): the waist, the collar, where the sleeves end,
# the trousers' hem, and the stripes' width round him (a 1.8 m man's stripes about 3.5 cm).
WAIST = 0.59
COLLAR = 0.835
SLEEVE_END = 0.72
HEM = 0.075
STRIPE = 0.02
TRUNK_BONES = ['Hips', 'Spine', 'Spine1', 'Spine2', 'LeftShoulder', 'RightShoulder', 'Neck']
LEG_BONES = ['Hips', 'LeftUpLeg', 'RightUpLeg', 'LeftLeg', 'RightLeg']
FOOT_BONES = ['LeftFoot', 'RightFoot', 'LeftToeBase', 'RightToeBase']
# Each upper arm's line in the bind pose, shoulder to elbow (z mirrored), for the sleeves' stripes.
ARM_FROM = np.array([-0.02, 0.8, 0.11])
ARM_TO = np.array([-0.02, 0.655, 0.19])


def stripes(p, arm):
    """1 on the shirt's black stripes: upright round the trunk, and round the upper arm on a sleeve."""
    trunk_arc = np.arctan2(p[:, 2], p[:, 0] + 0.01) * 0.09
    side = np.where(p[:, 2] < 0, -1.0, 1.0)
    origin = ARM_FROM * np.stack([np.ones_like(side), np.ones_like(side), side], 1)
    axis = (ARM_TO - ARM_FROM) * np.stack([np.ones_like(side), np.ones_like(side), side], 1)
    axis /= np.linalg.norm(axis, axis=1, keepdims=True)
    rel = p - origin
    rel -= axis * (rel * axis).sum(1, keepdims=True)
    up = np.cross(axis, np.array([1.0, 0.0, 0.0]))
    up /= np.linalg.norm(up, axis=1, keepdims=True)
    arm_arc = np.arctan2((rel * up).sum(1), rel[:, 0]) * 0.04
    arc = np.where(arm > 0.5, arm_arc, trunk_arc)
    return (np.floor(arc / STRIPE).astype(int) % 2 == 0).astype(float)


def clothes(p, bone_names, hand):
    """The referee's clothes for texels at body points `p` whose strongest bones are `bone_names`."""
    y = p[:, 1]
    trunk = np.isin(bone_names, ['mixamorig:' + b for b in TRUNK_BONES])
    arm = np.isin(bone_names, ['mixamorig:LeftArm', 'mixamorig:RightArm'])
    legs = np.isin(bone_names, ['mixamorig:' + b for b in LEG_BONES])
    feet = np.isin(bone_names, ['mixamorig:' + b for b in FOOT_BONES])
    shirt = ((trunk & (y >= WAIST) & (y < COLLAR)) | (arm & (y > SLEEVE_END))) & (hand < 0.5)
    stripe = shirt * stripes(p, arm.astype(float))
    trousers = (legs & (y < WAIST) & (y > HEM) & (hand < 0.5)) | (trunk & (y < WAIST) & (hand < 0.5))
    shoes = feet | (y <= HEM)
    hands = (hand >= 0.5).astype(float)
    return np.stack([shirt.astype(float), np.maximum(stripe, hands), trousers.astype(float), shoes.astype(float)], 1)


# Damage (D375-D378), in the bind pose: the middle of each eye's swelling (left; the right is mirrored) and how far it
# reaches; the cut over the eyebrow (from its inner to its outer end) and the trickle from its outer end down the side
# of his face, both as (height, side) seen from in front and drawn on the face's front; how thick the cut and the
# trickle are; the ribs' band; where he flushes.
EYE = np.array([0.062, 0.925, -0.024])
EYE_REACH = 0.024
EYE_TOP = 0.932
CUT = [np.array([0.9405, -0.026]), np.array([0.937, -0.035])]
TRICKLE = [np.array([0.937, -0.035]), np.array([0.925, -0.039]), np.array([0.907, -0.036]), np.array([0.888, -0.029])]
CUT_WIDTH = 0.0018
TRICKLE_WIDTH = [0.003, 0.0018]
RIBS = (0.6, 0.79)
FLUSH_FROM = 0.75


def along(p, line):
    """For points `p`: the distance to the polyline `line` and how far along it (0 to 1) the nearest point is."""
    lengths = [np.linalg.norm(line[k + 1] - line[k]) for k in range(len(line) - 1)]
    total = sum(lengths)
    best = np.full(len(p), np.inf)
    where = np.zeros(len(p))
    done = 0.0
    for k in range(len(line) - 1):
        a, b = line[k], line[k + 1]
        t = np.clip(((p - a) @ (b - a)) / max(lengths[k] ** 2, 1e-12), 0, 1)
        d = np.linalg.norm(p - (a + t[:, None] * (b - a)), axis=1)
        closer = d < best
        best[closer] = d[closer]
        where[closer] = (done + t[closer] * lengths[k]) / total
        done += lengths[k]
    return best, where


FRONT_CELL = 0.003
FRONT_SPAN = (0.85, 1.0, -0.08, 0.08)


def front_of_face(points):
    """How far forward (x) the front of his head is at each (height, side), from the body's points: a function of
    (y, z) giving the frontmost x in that 3 mm cell (or the next one round), so the inside of the head isn't marked."""
    y0, y1, z0, z1 = FRONT_SPAN
    rows, cols = int((y1 - y0) / FRONT_CELL) + 1, int((z1 - z0) / FRONT_CELL) + 1
    grid = np.full((rows, cols), -np.inf)
    head = points[(points[:, 1] >= y0) & (points[:, 1] <= y1) & (np.abs(points[:, 2]) <= z1)]
    r = ((head[:, 1] - y0) / FRONT_CELL).astype(int)
    c = ((head[:, 2] - z0) / FRONT_CELL).astype(int)
    np.maximum.at(grid, (r, c), head[:, 0])
    for _ in range(2):  # Fill cells no point fell in from their neighbours.
        padded = np.pad(grid, 1, constant_values=-np.inf)
        around = np.max([padded[1 + dr:rows + 1 + dr, 1 + dc:cols + 1 + dc] for dr in (-1, 0, 1) for dc in (-1, 0, 1)], 0)
        grid = np.where(np.isfinite(grid), grid, around)

    def front(q):
        rr = np.clip(((q[:, 1] - y0) / FRONT_CELL).astype(int), 0, rows - 1)
        cc = np.clip(((q[:, 2] - z0) / FRONT_CELL).astype(int), 0, cols - 1)
        return grid[rr, cc]
    return front


FRONT = None


def damage(p, bone_names, hand, normal):
    """Where damage shows for texels at body points `p` on a face of the mesh turned to `normal` (D375-D378):
    (damage.png, marks.png) channels."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    head = np.isin(bone_names, ['mixamorig:Head', 'mixamorig:Neck'])
    trunk = np.isin(bone_names, ['mixamorig:' + b for b in TRUNK_BONES])
    front = np.clip((x - 0.02) / 0.03, 0, 1)
    eyes = []
    marks = []
    for side in (-1.0, 1.0):
        mirror = np.array([1.0, 1.0, -side])  # The constants are his left side (-Z).
        reach = np.linalg.norm(p - EYE * mirror, axis=1) / EYE_REACH
        under_brow = np.clip((EYE_TOP - y) / 0.01, 0, 1)  # Puffs under the brow and round the eye, not the brow.
        eyes.append(np.clip(1.0 - reach, 0, 1) ** 0.7 * front * head * under_brow)
        seen = p[:, 1:]  # Seen from in front: (height, side).
        flip = np.array([1.0, -side])
        cut_d, _ = along(seen, [q * flip for q in CUT])
        trickle_d, t = along(seen, [q * flip for q in TRICKLE])
        width = TRICKLE_WIDTH[0] + (TRICKLE_WIDTH[1] - TRICKLE_WIDTH[0]) * t
        trickle = np.where(trickle_d < width, 0.95 - 0.9 * t, 0.0)
        cut = np.where(cut_d < CUT_WIDTH, 1.0, 0.0)
        facing = (normal[0] > -0.1) | (normal[2] * side > 0.4)
        outer = x > FRONT(p) - 0.004  # The face's front surface, not the inside of the head or the eyes behind it.
        on_side = (z * side > 0.004) & head & (x > 0.02) & facing & outer
        marks.append(np.maximum(cut, trickle) * on_side)
    ribs = trunk & (y > RIBS[0]) & (y < RIBS[1]) & (x > -0.035) & (hand < 0.5)
    body = ribs * np.clip(1.0 - np.abs(y - 0.7) / 0.1, 0.3, 1.0)
    flush = (head & (x > -0.01)) * 1.0 + (trunk & (y > FLUSH_FROM) & (x > 0.0) & (hand < 0.5)) * 0.6
    legs = []
    for name, side in (('Left', -1.0), ('Right', 1.0)):
        leg = np.isin(bone_names, ['mixamorig:%sUpLeg' % name, 'mixamorig:%sLeg' % name])
        # Kicks land on the outside and front of the thigh, and the back and outside of the calf.
        middle = np.where(np.abs(z) > 0.0, z, 0.0)
        outward = np.clip((np.abs(middle) - 0.05) / 0.05, 0, 1) * (z * side > 0)
        thigh = np.clip(np.maximum(outward, np.clip(x / 0.06, 0, 1) * 0.6), 0, 1) * np.clip((y - 0.3) / 0.04, 0, 1) * np.clip((0.56 - y) / 0.06, 0, 1)
        calf = np.clip(np.maximum(outward, np.clip(-x / 0.04, 0, 1)), 0, 1) * np.clip((y - 0.1) / 0.04, 0, 1) * np.clip((0.26 - y) / 0.04, 0, 1)
        legs.append(leg * np.maximum(thigh, calf * 0.8))
    return (np.stack([eyes[0], eyes[1], body, np.minimum(flush, 1.0)], 1),
            np.stack([marks[0], marks[1], legs[0], legs[1]], 1))


def grow(out, covered):
    for _ in range(4):  # Grow the regions into the unused texels round them, so filtering doesn't bleed at seams.
        grown = np.stack([np.asarray(Image.fromarray(out[:, :, k]).filter(ImageFilter.MaxFilter(3))) for k in range(4)], 2)
        out[~covered] = grown[~covered]
    return out


def main():
    global FRONT
    mesh, names = load(GLB)
    FRONT = front_of_face(mesh['pos'])
    texture = np.asarray(Image.open(TEX).convert('RGB')).astype(float) / 255.0
    tex_size = texture.shape[0]
    strongest = mesh['joints'][np.arange(len(mesh['joints'])), mesh['weights'].argmax(1)]
    hand_bones = [k for k, n in enumerate(names) if 'Hand' in n]
    hand = np.isin(strongest, hand_bones).astype(float)
    mask = np.zeros((SIZE, SIZE, 4))
    dressed = np.zeros((SIZE, SIZE, 4))
    hurt = np.zeros((SIZE, SIZE, 4))
    marked = np.zeros((SIZE, SIZE, 4))
    bone_of = np.array(names)[strongest]
    covered = np.zeros((SIZE, SIZE), bool)
    for tri in mesh['tris']:
        uv = mesh['uv'][tri] * SIZE
        x0, y0 = np.maximum(np.floor(uv.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(uv.max(0)).astype(int), SIZE - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a, b, c = uv
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        l3 = 1 - l1 - l2
        inside = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not inside.any():
            continue
        bary = np.stack([l1[inside], l2[inside], l3[inside]], 1)
        px, py = xs[inside].astype(int), ys[inside].astype(int)
        colour = texture[np.minimum((py + 0.5) * tex_size / SIZE, tex_size - 1).astype(int),
                         np.minimum((px + 0.5) * tex_size / SIZE, tex_size - 1).astype(int)]
        regions = classify(bary @ mesh['pos'][tri], colour, bary @ hand[tri])
        mask[py, px] = np.maximum(mask[py, px], regions)
        nearest = tri[bary.argmax(1)]
        worn = clothes(bary @ mesh['pos'][tri], bone_of[nearest], bary @ hand[tri])
        dressed[py, px] = np.maximum(dressed[py, px], worn)
        corners = mesh['pos'][tri]
        normal = np.cross(corners[1] - corners[0], corners[2] - corners[0])
        normal = normal / max(np.linalg.norm(normal), 1e-12)
        zones, marks = damage(bary @ corners, bone_of[nearest], bary @ hand[tri], normal)
        hurt[py, px] = np.maximum(hurt[py, px], zones)
        marked[py, px] = np.maximum(marked[py, px], marks)
        covered[py, px] = True
    Image.fromarray(grow((mask * 255).astype(np.uint8), covered), 'RGBA').save(OUT)
    print('Body regions:', os.path.normpath(OUT))
    Image.fromarray(grow((dressed * 255).astype(np.uint8), covered), 'RGBA').save(CLOTHES)
    print('Referee clothes:', os.path.normpath(CLOTHES))
    Image.fromarray(grow((hurt * 255).astype(np.uint8), covered), 'RGBA').save(DAMAGE)
    print('Damage zones:', os.path.normpath(DAMAGE))
    Image.fromarray(grow((marked * 255).astype(np.uint8), covered), 'RGBA').save(MARKS)
    print('Cuts and leg marks:', os.path.normpath(MARKS))


if __name__ == '__main__':
    sys.exit(main())
