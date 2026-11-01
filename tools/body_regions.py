"""Bakes the skinned body's region mask (D364, docs/13 "Fighters who look different").

The body (game/bodies/tripo_fighter.glb) has one texture with skin, hair and shorts painted in. The look shader
(SkinnedBody.set_look) recolours them, and needs to know which texels are which. This finds them from where each
texel sits on the body (in the file's bind pose: +X forward, Y up, the body 1.0 tall) and what colour it is, and
writes game/bodies/tripo_fighter_regions.png (1024 x 1024, RGBA):
  red    the hair on his head (dark texels over the hairline, down the back and the sides)
  green  where a beard grows (skin on the jaw, chin and upper lip, fading out at the cheeks; not the lips)
  blue   his eyebrows
  alpha  his shorts (colourless texels round the hips)
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


def main():
    mesh, names = load(GLB)
    texture = np.asarray(Image.open(TEX).convert('RGB')).astype(float) / 255.0
    tex_size = texture.shape[0]
    strongest = mesh['joints'][np.arange(len(mesh['joints'])), mesh['weights'].argmax(1)]
    hand_bones = [k for k, n in enumerate(names) if 'Hand' in n]
    hand = np.isin(strongest, hand_bones).astype(float)
    mask = np.zeros((SIZE, SIZE, 4))
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
        covered[py, px] = True
    out = (mask * 255).astype(np.uint8)
    for _ in range(4):  # Grow the regions into the unused texels round them, so filtering doesn't bleed at seams.
        grown = np.stack([np.asarray(Image.fromarray(out[:, :, k]).filter(ImageFilter.MaxFilter(3))) for k in range(4)], 2)
        out[~covered] = grown[~covered]
    Image.fromarray(out, 'RGBA').save(OUT)
    print('Body regions:', os.path.normpath(OUT))


if __name__ == '__main__':
    sys.exit(main())
