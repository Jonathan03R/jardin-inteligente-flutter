"""Genera la mascota "Brotito" desde cero: geometria, esqueleto, caras y animaciones.

Uso (Blender 5.x):
  blender --background --factory-startup --python tools/mascot/build_mascot.py -- <salida.glb> [carpeta_previews]

Diseno del esqueleto
--------------------
Root            suelo; saltos y desplazamientos
 ├ Foot.L/R     pies rigidos
 └ Body         maceta; pivote en la base para squash & stretch
    ├ Arm.L/R   brazos-rama con mano-hoja (rigidos)
    ├ Face      pivote en el eje de la maceta: girarlo desliza la cara sobre el cilindro (mirar)
    │  └ F_*    un grupo por emocion; el visor muestra uno via materiales "<mat>@<emocion>"
    │     └ E_* parpados (parpadeo = escala vertical)
    └ Stem.1 → Stem.2 → Stem.3   unico mesh deformable (pesos suaves por altura)
           ├ Leaf.L/R (en Stem.2)
           └ Bud      (en Stem.3)

Solo el tallo usa skinning, con pesos calculados (no automaticos). Todo lo demas cuelga
rigido de un hueso: no puede deformarse ni "romperse" en ninguna pose.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
GLB_OUT = Path(argv[0]) if argv else Path(__file__).resolve().parents[2] / 'assets' / 'mascot' / 'brotito.glb'
PREVIEW_DIR = Path(argv[1]) if len(argv) > 1 else None
FPS = 24

# ---------------------------------------------------------------- escena limpia
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
col = bpy.data.collections.new('Brotito')
scene.collection.children.link(col)


# ---------------------------------------------------------------- materiales
def srgb(h: str) -> tuple[float, float, float, float]:
    h = h.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def material(name: str, color: str, rough: float = 0.6, emit: float = 0.0, double: bool = False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = srgb(color)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = 0.0
    if emit:
        bsdf.inputs['Emission Color'].default_value = srgb(color)
        bsdf.inputs['Emission Strength'].default_value = emit
    m.use_backface_culling = not double
    return m


MAT = {
    'Pot': material('Pot', '#DE7B4C', 0.72),
    'Rim': material('Rim', '#C8643A', 0.7),
    'Soil': material('Soil', '#4B3021', 0.95),
    'Feet': material('Feet', '#B9583A', 0.7),
    'Stem': material('Stem', '#5C9A3A', 0.55),
    'Leaf': material('Leaf', '#7DC24B', 0.5, double=True),
    'Vein': material('Vein', '#5A9A33', 0.5),
    'Eye': material('Eye', '#2A1A14', 0.22),
    'Shine': material('Shine', '#FFFFFF', 0.2, emit=0.6),
    'Mouth': material('Mouth', '#6E2A22', 0.5),
    'Tongue': material('Tongue', '#F2807A', 0.5),
    'Blush': material('Blush', '#F59C8E', 0.8),
    'Frost': material('Frost', '#93C9F5', 0.8),
    'Brow': material('Brow', '#3A2418', 0.5),
    'Sweat': material('Sweat', '#8FD6FF', 0.15, emit=0.15),
    'Zzz': material('Zzz', '#EEF3FF', 0.4, emit=0.8),
}


# ---------------------------------------------------------------- geometria base
def new_object(name: str, mesh: bpy.types.Mesh, mat_key: str, smooth: bool = True) -> bpy.types.Object:
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    mesh.materials.append(MAT[mat_key])
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    return obj


def lathe(name: str, profile: list[tuple[float, float]], mat_key: str, seg: int = 56) -> bpy.types.Object:
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-6:
            rings.append([bm.verts.new((0.0, 0.0, z))])
            continue
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1:
            for i in range(seg):
                bm.faces.new((a[0], b[(i + 1) % seg], b[i]))
        elif len(b) == 1:
            for i in range(seg):
                bm.faces.new((a[i], a[(i + 1) % seg], b[0]))
        else:
            for i in range(seg):
                bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return new_object(name, me, mat_key)


def ellipsoid(name: str, loc, scale, mat_key: str, seg: int = 24, rings: int = 14) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return new_object(name, me, mat_key)


def from_eval(name: str, src: bpy.types.Object, mat_key: str, smooth: bool) -> bpy.types.Object:
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(src.evaluated_get(dg))
    me.name = name
    data = src.data
    bpy.data.objects.remove(src)
    bpy.data.curves.remove(data)
    me.materials.clear()
    return new_object(name, me, mat_key, smooth)


def tube(name: str, pts, radius: float, mat_key: str) -> bpy.types.Object:
    cu = bpy.data.curves.new(name + '_c', 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new('POLY')
    sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1.0)
    obj = bpy.data.objects.new(name + '_tmp', cu)
    col.objects.link(obj)
    t = from_eval(name, obj, mat_key, True)
    # cerrar extremos con esferas para puntas redondeadas
    caps = [ellipsoid(name + '_a', pts[0], (radius,) * 3, mat_key, 12, 8),
            ellipsoid(name + '_b', pts[-1], (radius,) * 3, mat_key, 12, 8)]
    return join([t, *caps], name)


def flat_shape(name: str, outline2d, d0: float, d1: float, mat_key: str) -> bpy.types.Object:
    """Contorno en plano XZ (x, z), extruido hacia la camara: y de -d0 a -d1."""
    bm = bmesh.new()
    back = [bm.verts.new((x, -d0, z)) for x, z in outline2d]
    front = [bm.verts.new((x, -d1, z)) for x, z in outline2d]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline2d)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='EAR_CLIP')
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return new_object(name, me, mat_key, smooth=False)


def ellipse_outline(cx, cz, a, b, n=40):
    return [(cx + a * math.cos(2 * math.pi * i / n), cz + b * math.sin(2 * math.pi * i / n)) for i in range(n)]


def text_mesh(name: str, body: str, size: float, mat_key: str) -> bpy.types.Object:
    cu = bpy.data.curves.new(name + '_c', 'FONT')
    cu.body = body
    cu.size = size
    cu.extrude = size * 0.12
    cu.bevel_depth = size * 0.03
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    obj = bpy.data.objects.new(name + '_tmp', cu)
    col.objects.link(obj)
    t = from_eval(name, obj, mat_key, False)
    t.data.transform(Matrix.Rotation(math.radians(90), 4, 'X'))  # de pie, mirando a -Y
    return t


def join(objs, name: str) -> bpy.types.Object:
    target = objs[0]
    bm = bmesh.new()
    for o in objs:
        mats = o.data.materials[:]
        tmp = bmesh.new()
        tmp.from_mesh(o.data)
        tmp.transform(o.matrix_world)
        me = bpy.data.meshes.new('tmp')
        tmp.to_mesh(me)
        tmp.free()
        # conservar indice de material
        for p in me.polygons:
            p.material_index = 0
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        if o is not target:
            for m in mats:
                if m.name not in [x.name for x in target.data.materials]:
                    target.data.materials.append(m)
    # Todas las piezas de un join usan el material del primero: (las juntas son del mismo material)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    keep = objs[0].data.materials[0]
    for o in objs:
        old = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(old)
    me.materials.clear()
    me.materials.append(keep)
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    col.objects.link(obj)
    return obj


# ---------------------------------------------------------------- cuerpo: maceta
def pot_r(z: float) -> float:
    zz = min(max(z, 0.08), 0.5)
    t = (zz - 0.08) / 0.42
    return 0.272 + 0.058 * t + 0.016 * math.sin(math.pi * t)


body_profile = [(0.0, 0.03), (0.17, 0.03), (0.225, 0.037), (0.255, 0.052), (0.27, 0.07)]
body_profile += [(pot_r(z), z) for z in [0.08 + 0.42 * i / 16 for i in range(17)]]
body_profile += [(0.33, 0.505)]
pot = lathe('Pot', body_profile, 'Pot')
rim = lathe('Rim', [(0.322, 0.49), (0.36, 0.497), (0.383, 0.515), (0.392, 0.545), (0.392, 0.6),
                    (0.384, 0.626), (0.366, 0.638), (0.347, 0.632), (0.338, 0.6), (0.335, 0.585)], 'Rim')
soil = lathe('Soil', [(0.0, 0.612), (0.12, 0.61), (0.25, 0.602), (0.34, 0.59)], 'Soil', seg=40)
foot_l = ellipsoid('Foot_L', (-0.125, -0.07, 0.034), (0.078, 0.095, 0.042), 'Feet')
foot_r = ellipsoid('Foot_R', (0.125, -0.07, 0.034), (0.078, 0.095, 0.042), 'Feet')


# ---------------------------------------------------------------- hojas
def leaf_mesh(name: str, length: float, width: float, cup: float, bend: float, nu=16, nv=8) -> bpy.types.Object:
    bm = bmesh.new()
    grid = []
    for i in range(nu + 1):
        u = i / nu
        w = width * (math.sin(math.pi * min(u * 1.05, 1.0)) ** 0.75) * (1.0 - 0.25 * u)
        row = []
        for j in range(nv + 1):
            v = -1 + 2 * j / nv
            row.append(bm.verts.new((length * u, v * w, cup * (v * v) * (w / max(width, 1e-6)) + bend * u * u)))
        grid.append(row)
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    leaf = new_object(name, me, 'Leaf')
    vein_pts = [(length * u, 0.0, bend * u * u + 0.004) for u in [k / 10 * 0.9 for k in range(11)]]
    vein = tube(name + '_vein', vein_pts, 0.0045, 'Vein')
    return leaf, vein


def place(objs, matrix: Matrix):
    for o in objs:
        o.data.transform(matrix)


def leaf_at(name, base, yaw_deg, pitch_deg, roll_deg, length, width, cup, bend):
    leaf, vein = leaf_mesh(name, length, width, cup, bend)
    m = (Matrix.Translation(Vector(base)) @ Matrix.Rotation(math.radians(yaw_deg), 4, 'Z')
         @ Matrix.Rotation(math.radians(-pitch_deg), 4, 'Y') @ Matrix.Rotation(math.radians(roll_deg), 4, 'X'))
    place([leaf, vein], m)
    return [leaf, vein]


leaf_l = leaf_at('Leaf_L', (-0.012, 0.0, 0.83), 180, 28, 0, 0.34, 0.15, 0.035, -0.05)
leaf_r = leaf_at('Leaf_R', (0.012, 0.0, 0.83), 0, 28, 0, 0.34, 0.15, 0.035, -0.05)
bud_parts = leaf_at('Bud_L', (-0.005, 0.0, 0.97), 180, 62, 0, 0.15, 0.065, 0.02, -0.01)
bud_parts += leaf_at('Bud_R', (0.005, 0.0, 0.97), 0, 62, 0, 0.15, 0.065, 0.02, -0.01)
bud_parts.append(ellipsoid('Bud_tip', (0.0, 0.0, 0.985), (0.028, 0.028, 0.035), 'Stem'))

# tallo deformable
stem_profile = [(0.0, 0.57)] + [(0.03 - 0.008 * (k / 24), 0.57 + 0.42 * k / 24) for k in range(25)] + [(0.0, 0.995)]
stem = lathe('Stem', stem_profile, 'Stem', seg=14)

# brazos: rama corta + mano-hoja
arm_l = [tube('Arm_L_twig', [(-0.31, -0.01, 0.34), (-0.38, -0.014, 0.362), (-0.445, -0.02, 0.39)], 0.019, 'Stem'),
         ellipsoid('Arm_L_hand', (-0.492, -0.022, 0.41), (0.058, 0.022, 0.04), 'Leaf')]
arm_r = [tube('Arm_R_twig', [(0.31, -0.01, 0.34), (0.38, -0.014, 0.362), (0.445, -0.02, 0.39)], 0.019, 'Stem'),
         ellipsoid('Arm_R_hand', (0.492, -0.022, 0.41), (0.058, 0.022, 0.04), 'Leaf')]
for hand, sign in ((arm_l[1], -1), (arm_r[1], 1)):
    piv = Vector((0.492 * sign, -0.022, 0.41))
    hand.data.transform(Matrix.Translation(piv) @ Matrix.Rotation(math.radians(-25 * sign), 4, 'Y') @ Matrix.Translation(-piv))


# ---------------------------------------------------------------- cara (espacio plano -> envuelta en la maceta)
EYE_Z, MOUTH_Z, EYE_X = 0.355, 0.265, 0.105


def wrap(obj: bpy.types.Object):
    """Convierte coordenadas planas (x, -profundidad, z) a la superficie cilindrica de la maceta."""
    for v in obj.data.vertices:
        x, y, z = v.co
        r = pot_r(z) - y  # y negativo = sobresale
        th = x / pot_r(z)
        v.co = (r * math.sin(th), -r * math.cos(th), z)
    obj.data.update()
    return obj


def arc_pts(cx, cz, half, h, n=14):
    """Arco suave: h>0 forma ∩, h<0 forma ∪."""
    return [(cx + half * (2 * i / n - 1), cz + h * (1 - (2 * i / n - 1) ** 2)) for i in range(n + 1)]


def line_tube(name, pts2d, r, mat, depth=0.006):
    return wrap(tube(name, [(x, -depth, z) for x, z in pts2d], r, mat))


def eye_round(prefix, sx=0.036, sz=0.047, shine=0.013):
    parts = []
    for s in (-1, 1):
        parts.append(wrap(ellipsoid(f'{prefix}_eye{s}', (s * EYE_X, 0.0, EYE_Z), (sx, 0.013, sz), 'Eye', 20, 12)))
        parts.append(wrap(ellipsoid(f'{prefix}_shine{s}', (s * EYE_X + sx * 0.32, -0.011, EYE_Z + sz * 0.38),
                                    (shine, 0.005, shine), 'Shine', 10, 6)))
    return parts


def blush(prefix, mat='Blush', a=0.04, b=0.021):
    return [wrap(flat_shape(f'{prefix}_blush{s}', ellipse_outline(s * 0.175, 0.295, a, b, 28), -0.003, 0.004, mat))
            for s in (-1, 1)]


def d_mouth(prefix, half=0.058, depth=0.052, cz=MOUTH_Z + 0.022, tongue=True):
    outline = [(half * (1 - 2 * i / 12), cz) for i in range(13)]
    outline += [(-half * math.cos(math.pi * i / 20), cz - depth * math.sin(math.pi * i / 20)) for i in range(1, 20)]
    parts = [wrap(flat_shape(f'{prefix}_mouth', outline, -0.003, 0.009, 'Mouth'))]
    if tongue:
        parts.append(wrap(flat_shape(f'{prefix}_tongue', ellipse_outline(0, cz - depth * 0.68, half * 0.5, depth * 0.27, 24),
                                     -0.003, 0.0105, 'Tongue')))
    return parts


def oval_mouth(prefix, a, b, cz=MOUTH_Z - 0.005, tongue=False):
    parts = [wrap(flat_shape(f'{prefix}_mouth', ellipse_outline(0, cz, a, b, 32), -0.003, 0.009, 'Mouth'))]
    if tongue:
        parts.append(wrap(flat_shape(f'{prefix}_tongue', ellipse_outline(0, cz - b * 0.55, a * 0.62, b * 0.32, 24),
                                     -0.003, 0.0105, 'Tongue')))
    return parts


def brows(prefix, inner_up: float, z=0.432, tilt=1.0):
    out = []
    for s in (-1, 1):
        a = (s * 0.145, z - 0.006 * tilt)
        b = (s * 0.07, z + inner_up)
        out.append(line_tube(f'{prefix}_brow{s}', [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + 0.006), b], 0.0065, 'Brow'))
    return out


def sweat(prefix, x=0.205, z=0.435):
    drop = [(x + 0.018 * math.cos(a), z - 0.012 + 0.018 * math.sin(a)) for a in [math.pi + math.pi * k / 16 for k in range(17)]]
    tip = [(x, z + 0.03)]
    shape = [drop[0]] + drop[1:] + tip
    return [wrap(flat_shape(f'{prefix}_sweat', shape, -0.003, 0.009, 'Sweat'))]


def wavy(prefix, half=0.045, amp=0.007, cz=MOUTH_Z):
    pts = [(-half + 2 * half * i / 24, cz + amp * math.sin(i / 24 * 4 * math.pi)) for i in range(25)]
    return [line_tube(f'{prefix}_mouth', pts, 0.0075, 'Mouth')]


faces: dict[str, dict[str, list[bpy.types.Object]]] = {}
# cada cara: 'eyes' (parpadean) y 'rest' (boca, cejas, rubor...)
faces['Neutral'] = {'eyes': eye_round('neu'),
                    'rest': [line_tube('neu_mouth', arc_pts(0, MOUTH_Z, 0.045, -0.02), 0.0078, 'Mouth')] + blush('neu')}
faces['Joy'] = {'eyes': [],
                'rest': [line_tube(f'joy_eye{s}', arc_pts(s * EYE_X, EYE_Z - 0.012, 0.036, 0.026), 0.0095, 'Eye') for s in (-1, 1)]
                + d_mouth('joy') + blush('joy', a=0.046, b=0.024)}
faces['Sad'] = {'eyes': eye_round('sad', 0.031, 0.04, 0.011),
                'rest': brows('sad', 0.02) + [line_tube('sad_mouth', arc_pts(0, MOUTH_Z - 0.012, 0.036, 0.014), 0.0075, 'Mouth')]
                + sweat('sad')}
faces['Sleep'] = {'eyes': [],
                  'rest': [line_tube(f'slp_eye{s}', arc_pts(s * EYE_X, EYE_Z - 0.004, 0.034, -0.017), 0.008, 'Eye') for s in (-1, 1)]
                  + oval_mouth('slp', 0.012, 0.014) + blush('slp', a=0.036, b=0.018)}
faces['Surprise'] = {'eyes': eye_round('sur', 0.044, 0.058, 0.016),
                     'rest': brows('sur', 0.006, z=0.455, tilt=-1.2) + oval_mouth('sur', 0.026, 0.032)}
faces['Hot'] = {'eyes': [],
                'rest': [line_tube(f'hot_eye{s}', [(s * EYE_X - 0.03 * s, EYE_Z + 0.022), (s * EYE_X + 0.018 * s, EYE_Z),
                                                    (s * EYE_X - 0.03 * s, EYE_Z - 0.022)], 0.0085, 'Eye') for s in (-1, 1)]
                + oval_mouth('hot', 0.03, 0.02, tongue=True) + sweat('hot', x=-0.2) + sweat('hot2', x=0.215, z=0.40)
                + blush('hot', a=0.05, b=0.026)}
faces['Cold'] = {'eyes': eye_round('cld', 0.032, 0.042, 0.012),
                 'rest': wavy('cld') + blush('cld', 'Frost', a=0.045, b=0.024) + brows('cld', 0.012)}
faces['Curious'] = {'eyes': eye_round('cur', 0.038, 0.05, 0.014),
                    'rest': oval_mouth('cur', 0.013, 0.016) + [line_tube('cur_brow', arc_pts(0.11, 0.45, 0.04, 0.012), 0.0065, 'Brow')]
                    + blush('cur', a=0.034, b=0.018)}
faces['Yawn'] = {'eyes': [],
                 'rest': [line_tube(f'yaw_eye{s}', arc_pts(s * EYE_X, EYE_Z, 0.035, 0.008), 0.0085, 'Eye') for s in (-1, 1)]
                 + oval_mouth('yaw', 0.036, 0.05, cz=MOUTH_Z - 0.015, tongue=True) + blush('yaw', a=0.036, b=0.018)}

zzz = [text_mesh(f'Zzz{i}', 'z', s, 'Zzz') for i, s in enumerate((0.11, 0.14, 0.17))]
zzz_pos = [(0.27, -0.34, 0.72), (0.37, -0.34, 0.84), (0.48, -0.34, 0.98)]
for o, p in zip(zzz, zzz_pos):
    o.data.transform(Matrix.Translation(Vector(p)))


# Cada cara usa materiales propios ("Eye@Joy", "Mouth@Sad"...). El visor muestra una sola cara
# poniendo alfa 1/0 en esos materiales, al instante: asi el fundido entre animaciones mezcla el
# movimiento, pero nunca dos caras a la vez.
_face_mats: dict[str, bpy.types.Material] = {}


def face_material(base: bpy.types.Material, face: str) -> bpy.types.Material:
    key = f'{base.name}@{face}'
    if key not in _face_mats:
        m = base.copy()
        m.name = key
        _face_mats[key] = m
    return _face_mats[key]


for face_name, parts in faces.items():
    for o in parts['eyes'] + parts['rest']:
        o.data.materials[0] = face_material(o.data.materials[0], face_name)
for o in zzz:
    o.data.materials[0] = face_material(o.data.materials[0], 'Sleep')


# ---------------------------------------------------------------- esqueleto
arm_data = bpy.data.armatures.new('Brotito_Rig')
rig = bpy.data.objects.new('Brotito_Rig', arm_data)
col.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')

FACE_R = pot_r(0.33)
bones_spec = {
    'Root': ((0, 0, 0), (0, 0, 0.12), None),
    'Foot.L': ((-0.125, -0.06, 0.0), (-0.125, -0.06, 0.08), 'Root'),
    'Foot.R': ((0.125, -0.06, 0.0), (0.125, -0.06, 0.08), 'Root'),
    'Body': ((0, 0, 0.04), (0, 0, 0.6), 'Root'),
    'Arm.L': ((-0.31, -0.01, 0.34), (-0.5, -0.02, 0.41), 'Body'),
    'Arm.R': ((0.31, -0.01, 0.34), (0.5, -0.02, 0.41), 'Body'),
    'Face': ((0, 0, 0.33), (0, 0, 0.45), 'Body'),
    'Stem.1': ((0, 0, 0.6), (0, 0, 0.73), 'Body'),
    'Stem.2': ((0, 0, 0.73), (0, 0, 0.86), 'Stem.1'),
    'Stem.3': ((0, 0, 0.86), (0, 0, 0.98), 'Stem.2'),
    'Leaf.L': ((-0.012, 0, 0.83), (-0.3, 0, 0.98), 'Stem.2'),
    'Leaf.R': ((0.012, 0, 0.83), (0.3, 0, 0.98), 'Stem.2'),
    'Bud': ((0, 0, 0.96), (0, 0, 1.06), 'Stem.3'),
}
for name in faces:
    bones_spec[f'F_{name}'] = ((0, -FACE_R, 0.31), (0, -FACE_R, 0.43), 'Face')
    if faces[name]['eyes']:
        bones_spec[f'E_{name}'] = ((0, -FACE_R, EYE_Z), (0, -FACE_R, EYE_Z + 0.08), f'F_{name}')
for i, p in enumerate(zzz_pos):
    bones_spec[f'Zzz.{i}'] = (p, (p[0], p[1], p[2] + 0.08), 'F_Sleep')

eb = {}
for name, (h, t, parent) in bones_spec.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = h, t
    b.roll = 0.0
    if parent:
        b.parent = eb[parent]
    b.use_deform = name.startswith('Stem')
    eb[name] = b
bpy.ops.object.mode_set(mode='OBJECT')


def bone_parent(obj: bpy.types.Object, bone: str):
    mw = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = 'BONE'
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = mw


rigid = {
    'Body': [pot, rim, soil],
    'Foot.L': [foot_l], 'Foot.R': [foot_r],
    'Arm.L': arm_l, 'Arm.R': arm_r,
    'Leaf.L': leaf_l, 'Leaf.R': leaf_r,
    'Bud': bud_parts,
}
for name, parts in faces.items():
    rigid[f'F_{name}'] = parts['rest']
    if parts['eyes']:
        rigid[f'E_{name}'] = parts['eyes']
for i, o in enumerate(zzz):
    rigid[f'Zzz.{i}'] = [o]

# Unir piezas del mismo hueso y material -> menos nodos y draw calls.
for bone, parts in rigid.items():
    by_mat: dict[str, list] = {}
    for o in parts:
        by_mat.setdefault(o.data.materials[0].name, []).append(o)
    merged = [join(objs, f'{bone}_{m}') if len(objs) > 1 else objs[0] for m, objs in by_mat.items()]
    for o in merged:
        o.name = f'{bone.replace(".", "_")}_{o.data.materials[0].name}'
        bone_parent(o, bone)

# Pesos del tallo: suaves por altura, normalizados. Sin pesos automaticos.
centers = {'Stem.1': 0.665, 'Stem.2': 0.795, 'Stem.3': 0.925}
for b in centers:
    stem.vertex_groups.new(name=b)
for v in stem.data.vertices:
    z = v.co.z
    ws = {b: max(0.0, 1 - abs(z - c) / 0.13) for b, c in centers.items()}
    if z < 0.665:
        ws = {'Stem.1': 1.0, 'Stem.2': 0.0, 'Stem.3': 0.0}
    if z > 0.925:
        ws = {'Stem.1': 0.0, 'Stem.2': 0.0, 'Stem.3': 1.0}
    total = sum(ws.values()) or 1.0
    for b, w in ws.items():
        if w > 0:
            stem.vertex_groups[b].add([v.index], w / total, 'REPLACE')
mod = stem.modifiers.new('Rig', 'ARMATURE')
mod.object = rig
stem.parent = rig

# ---------------------------------------------------------------- animacion procedural
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'

REST = {b.name: b.matrix_local.to_3x3() for b in arm_data.bones}
FACE_NAMES = list(faces)
EYE_BONES = [n for n in FACE_NAMES if faces[n]['eyes']]


def to_local(bone: str, r=(0, 0, 0), l=(0, 0, 0), s=(1, 1, 1)):
    B = REST[bone]
    Bq = B.to_quaternion()
    rw = Euler([math.radians(a) for a in r], 'XYZ').to_quaternion()
    q = Bq.inverted() @ rw @ Bq
    loc = B.inverted() @ Vector(l)
    sl = []
    for i in range(3):
        axis = B.col[i]
        j = max(range(3), key=lambda k: abs(axis[k]))
        sl.append(s[j])
    return q, loc, Vector(sl)


def sn(t, n=1.0, ph=0.0):
    return math.sin(2 * math.pi * (t * n + ph))


def smooth(a, b, t):
    if t <= a:
        return 0.0
    if t >= b:
        return 1.0
    x = (t - a) / (b - a)
    return x * x * (3 - 2 * x)


def window(t, a, b, c, d):
    """0 -> 1 entre a..b, 1 -> 0 entre c..d."""
    return smooth(a, b, t) * (1 - smooth(c, d, t))


def blink(t, times, width=0.035):
    v = 1.0
    for c in times:
        d = abs(t - c)
        if d < width:
            v = min(v, 0.08 + 0.92 * (d / width) ** 1.6)
    return v


def env(t, a=0.12, b=0.88):
    return smooth(0.0, a, t) * (1 - smooth(b, 1.0, t))


# Por encima de ~58 grados la mano quedaria oculta tras el borde de la maceta.
ARM_MAX = 38.0


def AL(up, fwd=None):
    """Brazo izquierdo: up>0 sube (con tope suave), fwd>0 lo lleva al frente."""
    up = ARM_MAX * math.tanh(up / ARM_MAX) if up > 0 else up
    return dict(r=(0, up, fwd or 0.0))


def AR(up, fwd=None):
    up = ARM_MAX * math.tanh(up / ARM_MAX) if up > 0 else up
    return dict(r=(0, -up, -(fwd or 0.0)))


def zzz_pose(t):
    out = {}
    for i in range(3):
        p = (t + i / 3) % 1.0
        sc = math.sin(math.pi * p) ** 0.6
        out[f'Zzz.{i}'] = dict(l=(0.02 * math.sin(2 * math.pi * p), 0, 0.09 * p), s=(sc, sc, sc), r=(0, 0, 8 * sn(p)))
    return out


# Cada animacion devuelve poses por hueso en espacio "armature" (grados, metros).
def a_idle(t):
    b = sn(t, 2)
    look = 12 * (window(t, 0.18, 0.28, 0.4, 0.5) - window(t, 0.55, 0.65, 0.78, 0.88))
    return {
        'Body': dict(r=(0, 2.2 * sn(t), 0), s=(1 - 0.01 * b, 1 - 0.01 * b, 1 + 0.02 * b)),
        'Stem.1': dict(r=(2 * sn(t, 1, .1), 4 * sn(t, 1, .15), 0)),
        'Stem.2': dict(r=(2 * sn(t, 1, .2), 5 * sn(t, 1, .25), 0)),
        'Stem.3': dict(r=(3 * sn(t, 1, .3), 6 * sn(t, 1, .35), 0)),
        'Leaf.L': dict(r=(0, 7 * sn(t, 2, .1), 3 * sn(t, 1))),
        'Leaf.R': dict(r=(0, -7 * sn(t, 2, .35), -3 * sn(t, 1))),
        'Bud': dict(r=(0, 6 * sn(t, 2, .5), 0)),
        'Arm.L': AL(6 * sn(t, 2, .05)),
        'Arm.R': AR(6 * sn(t, 2, .3)),
        'Face': dict(r=(0, 0, look)),
    }, 'Neutral', blink(t, [0.33, 0.37, 0.8])


def a_thirsty(t):
    sigh = window(t, 0.45, 0.55, 0.62, 0.75)
    return {
        'Body': dict(r=(4 + 2 * sigh, 2.5 * sn(t), 0), s=(1 + 0.02 * sigh, 1 + 0.02 * sigh, 0.97 - 0.04 * sigh)),
        'Stem.1': dict(r=(14 + 2 * sn(t), 3 * sn(t, 1, .2), 0)),
        'Stem.2': dict(r=(20 + 3 * sn(t, 1, .1) + 4 * sigh, 4 * sn(t, 1, .3), 0)),
        'Stem.3': dict(r=(26 + 4 * sn(t, 1, .2) + 6 * sigh, 5 * sn(t, 1, .4), 0)),
        'Leaf.L': dict(r=(0, -30 - 5 * sigh + 3 * sn(t), 0)),
        'Leaf.R': dict(r=(0, 30 + 5 * sigh - 3 * sn(t, 1, .3), 0)),
        'Bud': dict(r=(20, 0, 0)),
        'Arm.L': AL(-38 + 3 * sn(t)),
        'Arm.R': AR(-38 + 3 * sn(t, 1, .2)),
        'Face': dict(r=(-4 * sigh, 0, 4 * sn(t))),
    }, 'Sad', blink(t, [0.2, 0.72], 0.05)


def a_sleep(t):
    b = sn(t, 1)
    d = {
        'Root': dict(),
        'Body': dict(r=(3, 5 + 1.2 * b, 0), s=(1 - 0.015 * b, 1 - 0.015 * b, 1 + 0.028 * b)),
        'Stem.1': dict(r=(8, 8 + 1.5 * b, 0)),
        'Stem.2': dict(r=(10, 10 + 2 * b, 0)),
        'Stem.3': dict(r=(14, 12 + 2 * b, 0)),
        'Leaf.L': dict(r=(0, 22 + 3 * b, 0)),
        'Leaf.R': dict(r=(0, -22 - 3 * b, 0)),
        'Bud': dict(r=(25, 0, 0)),
        'Arm.L': AL(-30),
        'Arm.R': AR(-30),
        'Face': dict(r=(0, 0, -6)),
    }
    d.update(zzz_pose(t))
    return d, 'Sleep', 1.0


def a_rain(t):
    hop = abs(sn(t, 2)) * 0.022
    return {
        'Root': dict(l=(0, 0, hop)),
        'Body': dict(r=(0, 6 * sn(t), 0), s=(1, 1, 1 + 0.03 * sn(t, 4))),
        'Stem.1': dict(r=(0, -4 * sn(t, 1, .1), 0)),
        'Stem.2': dict(r=(0, -6 * sn(t, 1, .2), 0)),
        'Stem.3': dict(r=(-4, -8 * sn(t, 1, .3), 0)),
        'Leaf.L': dict(r=(0, 18 + 12 * sn(t, 4), 0)),
        'Leaf.R': dict(r=(0, -18 - 12 * sn(t, 4, .5), 0)),
        'Bud': dict(r=(0, 10 * sn(t, 2), 0)),
        'Arm.L': AL(40 + 12 * sn(t, 4)),
        'Arm.R': AR(40 + 12 * sn(t, 4, .5)),
        'Face': dict(r=(-6, 0, 6 * sn(t))),
    }, 'Joy', 1.0


def a_hot(t):
    pant = sn(t, 6)
    return {
        'Body': dict(r=(2, 2 * sn(t), 0), s=(1 + 0.008 * pant, 1 + 0.008 * pant, 0.985 - 0.012 * pant)),
        'Stem.1': dict(r=(6, 2 * sn(t), 0)),
        'Stem.2': dict(r=(9, 3 * sn(t, 1, .2), 0)),
        'Stem.3': dict(r=(12, 4 * sn(t, 1, .3), 0)),
        'Leaf.L': dict(r=(0, -16 + 3 * sn(t, 2), 0)),
        'Leaf.R': dict(r=(0, 16 - 3 * sn(t, 2, .3), 0)),
        'Arm.L': AL(-25),
        'Arm.R': AR(22 + 16 * sn(t, 5), 58),
        'Face': dict(r=(0, 0, -5)),
    }, 'Hot', 1.0


def a_cold(t):
    sh = sn(t, 8)
    return {
        'Root': dict(l=(0.005 * sh, 0, 0)),
        'Body': dict(r=(0, 2.5 * sh, 0), s=(0.98, 0.98, 0.97)),
        'Stem.1': dict(r=(4, 3 * sn(t, 8, .2), 0)),
        'Stem.2': dict(r=(4, 4 * sn(t, 8, .4), 0)),
        'Stem.3': dict(r=(6, 4 * sn(t, 8, .6), 0)),
        'Leaf.L': dict(r=(0, 26 + 4 * sh, 0)),
        'Leaf.R': dict(r=(0, -26 - 4 * sh, 0)),
        'Arm.L': AL(-18, 55 + 4 * sh),
        'Arm.R': AR(-18, 55 + 4 * sh),
        'Face': dict(r=(0, 0, 2 * sh)),
    }, 'Cold', blink(t, [0.5], 0.06)


def a_wave(t):
    e = env(t, 0.15, 0.82)
    hop = math.sin(math.pi * smooth(0.0, 0.3, t)) * 0.03 * (1 - smooth(0.25, 0.35, t))
    return {
        'Root': dict(l=(0, 0, hop)),
        'Body': dict(r=(0, -6 * e, 0)),
        'Stem.2': dict(r=(0, 5 * e * sn(t, 3), 0)),
        'Stem.3': dict(r=(0, 7 * e * sn(t, 3, .2), 0)),
        'Leaf.L': dict(r=(0, 10 * e * sn(t, 3), 0)),
        'Leaf.R': dict(r=(0, -10 * e * sn(t, 3, .3), 0)),
        'Arm.R': AR(e * (48 + 18 * sn(t, 3.5)), 35 * e),
        'Arm.L': AL(10 * e),
        'Face': dict(r=(0, 0, 8 * e)),
    }, 'Joy', 1.0


def a_dance(t):
    e = env(t, 0.08, 0.92)
    return {
        'Root': dict(l=(0.045 * e * sn(t, 2), 0, e * 0.03 * abs(sn(t, 4)))),
        'Body': dict(r=(0, 11 * e * sn(t, 2), 4 * e * sn(t, 2, .25)), s=(1, 1, 1 + 0.04 * e * sn(t, 4))),
        'Foot.L': dict(l=(0, 0, e * 0.02 * max(0, sn(t, 2)))),
        'Foot.R': dict(l=(0, 0, e * 0.02 * max(0, -sn(t, 2)))),
        'Stem.1': dict(r=(0, -6 * e * sn(t, 2, .1), 0)),
        'Stem.2': dict(r=(0, -9 * e * sn(t, 2, .2), 0)),
        'Stem.3': dict(r=(0, -12 * e * sn(t, 2, .3), 0)),
        'Leaf.L': dict(r=(0, e * (20 + 20 * sn(t, 4)), 0)),
        'Leaf.R': dict(r=(0, -e * (20 + 20 * sn(t, 4, .5)), 0)),
        'Bud': dict(r=(0, 14 * e * sn(t, 4), 0)),
        'Arm.L': AL(e * (30 + 22 * sn(t, 4))),
        'Arm.R': AR(e * (30 + 22 * sn(t, 4, .5))),
        'Face': dict(r=(0, 0, 10 * e * sn(t, 2))),
    }, 'Joy', 1.0


def a_jump(t):
    ant = window(t, 0.0, 0.18, 0.22, 0.3)
    air = window(t, 0.24, 0.3, 0.58, 0.64)
    h = math.sin(math.pi * min(max((t - 0.26) / 0.36, 0), 1)) * 0.2
    land = window(t, 0.6, 0.66, 0.72, 0.85)
    sz = 1 - 0.14 * ant + 0.09 * air - 0.12 * land
    sx = 1 + 0.08 * ant - 0.04 * air + 0.08 * land
    return {
        'Root': dict(l=(0, 0, h)),
        'Body': dict(s=(sx, sx, sz)),
        'Foot.L': dict(r=(0, 0, -12 * air)), 'Foot.R': dict(r=(0, 0, 12 * air)),
        'Stem.1': dict(r=(-6 * air + 8 * land, 0, 0)),
        'Stem.2': dict(r=(-8 * air + 12 * land, 0, 0)),
        'Stem.3': dict(r=(-10 * air + 14 * land, 0, 0)),
        'Leaf.L': dict(r=(0, 35 * air - 15 * land, 0)),
        'Leaf.R': dict(r=(0, -35 * air + 15 * land, 0)),
        'Arm.L': AL(45 * air - 20 * ant),
        'Arm.R': AR(45 * air - 20 * ant),
    }, 'Joy', 1.0


def a_surprise(t):
    jolt = window(t, 0.0, 0.12, 0.45, 0.8)
    face = 'Surprise' if t < 0.82 else 'Neutral'
    return {
        'Root': dict(l=(0, 0.04 * jolt, 0.05 * math.sin(math.pi * smooth(0, 0.3, t)) * (1 - smooth(0.2, 0.35, t)))),
        'Body': dict(r=(-8 * jolt, 0, 0), s=(1 - 0.03 * jolt, 1 - 0.03 * jolt, 1 + 0.06 * jolt)),
        'Stem.1': dict(r=(-6 * jolt, 0, 0)), 'Stem.2': dict(r=(-8 * jolt, 0, 0)), 'Stem.3': dict(r=(-10 * jolt, 0, 0)),
        'Leaf.L': dict(r=(0, 40 * jolt, 0)), 'Leaf.R': dict(r=(0, -40 * jolt, 0)),
        'Arm.L': AL(48 * jolt), 'Arm.R': AR(48 * jolt),
    }, face, blink(t, [0.9]) if face == 'Neutral' else 1.0


def a_curious(t):
    look = 26 * window(t, 0.08, 0.2, 0.38, 0.48) - 26 * window(t, 0.5, 0.6, 0.78, 0.88)
    lean = look / 26
    return {
        'Body': dict(r=(0, -6 * lean, 0), s=(1, 1, 1 + 0.015 * abs(lean))),
        'Face': dict(r=(0, 0, look)),
        'Stem.1': dict(r=(0, -5 * lean, 0)), 'Stem.2': dict(r=(0, -7 * lean, 0)),
        'Stem.3': dict(r=(-6 * abs(lean), -9 * lean, 0)),
        'Bud': dict(r=(0, -10 * lean, 0)),
        'Leaf.L': dict(r=(0, 6 * abs(lean) + 4 * sn(t, 3), 0)),
        'Leaf.R': dict(r=(0, -6 * abs(lean) - 4 * sn(t, 3, .3), 0)),
        'Arm.L': AL(-5 + 15 * max(0, lean)),
        'Arm.R': AR(-5 + 15 * max(0, -lean)),
    }, 'Curious', blink(t, [0.49, 0.95])


def a_yawn(t):
    st = window(t, 0.1, 0.3, 0.6, 0.8)
    face = 'Yawn' if 0.14 < t < 0.68 else 'Neutral'
    return {
        'Body': dict(r=(-4 * st, 0, 0), s=(1 - 0.03 * st, 1 - 0.03 * st, 1 + 0.08 * st)),
        'Stem.1': dict(r=(-4 * st, 0, 0)), 'Stem.2': dict(r=(-5 * st, 0, 0)), 'Stem.3': dict(r=(-6 * st, 0, 0)),
        'Leaf.L': dict(r=(0, 45 * st, 0)), 'Leaf.R': dict(r=(0, -45 * st, 0)),
        'Arm.L': AL(58 * st, 28 * st), 'Arm.R': AR(58 * st, 28 * st),
        'Face': dict(r=(0, 0, 0)),
    }, face, blink(t, [0.85, 0.89]) if face == 'Neutral' else 1.0


def a_giggle(t):
    e = env(t, 0.1, 0.8)
    return {
        'Root': dict(l=(0, 0, 0.018 * e * abs(sn(t, 3)))),
        'Body': dict(r=(0, 7 * e * sn(t, 4), 0), s=(1 + 0.02 * e * sn(t, 6), 1, 1 - 0.03 * e * sn(t, 6))),
        'Stem.2': dict(r=(0, -6 * e * sn(t, 4, .2), 0)), 'Stem.3': dict(r=(0, -8 * e * sn(t, 4, .3), 0)),
        'Leaf.L': dict(r=(0, 22 * e + 8 * e * sn(t, 6), 0)), 'Leaf.R': dict(r=(0, -22 * e - 8 * e * sn(t, 6), 0)),
        'Arm.L': AL(20 * e, 40 * e), 'Arm.R': AR(20 * e, 40 * e),
    }, 'Joy', 1.0


def a_refresh(t):
    e = env(t, 0.1, 0.85)
    up = window(t, 0.05, 0.25, 0.7, 0.95)
    face = 'Joy'
    return {
        'Body': dict(r=(0, 0, 14 * e * sn(t, 5)), s=(1, 1, 1 + 0.05 * up)),
        'Root': dict(l=(0, 0, 0.03 * up * abs(sn(t, 2)))),
        'Stem.1': dict(r=(-4 * up, 4 * e * sn(t, 5, .1), 0)),
        'Stem.2': dict(r=(-6 * up, 6 * e * sn(t, 5, .2), 0)),
        'Stem.3': dict(r=(-8 * up, 8 * e * sn(t, 5, .3), 0)),
        'Leaf.L': dict(r=(0, 40 * up + 10 * e * sn(t, 5), 0)),
        'Leaf.R': dict(r=(0, -40 * up - 10 * e * sn(t, 5, .5), 0)),
        'Bud': dict(r=(0, 15 * e * sn(t, 5), 0)),
        'Arm.L': AL(45 * up), 'Arm.R': AR(45 * up),
    }, face, 1.0


ANIMS = {
    # bucles (estado de animo de base)
    'Idle': (a_idle, 96), 'Thirsty': (a_thirsty, 120), 'Sleep': (a_sleep, 120),
    'Rain': (a_rain, 72), 'Hot': (a_hot, 72), 'Cold': (a_cold, 48),
    # reacciones / emociones propias (una vez)
    'Wave': (a_wave, 48), 'Dance': (a_dance, 96), 'Jump': (a_jump, 36), 'Surprise': (a_surprise, 36),
    'Curious': (a_curious, 84), 'Yawn': (a_yawn, 72), 'Giggle': (a_giggle, 36), 'Refresh': (a_refresh, 60),
}
FACE_TIMELINE: dict[str, list] = {}
rig.animation_data_create()
for name, (fn, length) in ANIMS.items():
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for f in range(0, length + 1):
        t = (f % length) / length if f < length else 1.0
        if f == length:
            t = 0.0 if name in ('Idle', 'Thirsty', 'Sleep', 'Rain', 'Hot', 'Cold') else 1.0
        poses, face, eye = fn(t)
        frame = f + 1
        line = FACE_TIMELINE.setdefault(name, [])
        if f < length and (not line or line[-1][1] != face):
            line.append([round(f / length, 4), face])
        for pb in rig.pose.bones:
            n = pb.name
            if n.startswith('F_'):
                q, loc, sc = Quaternion(), Vector(), Vector((1, 1, 1))
            elif n.startswith('E_'):
                q, loc, sc = to_local(n, s=(1, 1, eye))
            else:
                p = poses.get(n, {})
                q, loc, sc = to_local(n, p.get('r', (0, 0, 0)), p.get('l', (0, 0, 0)), p.get('s', (1, 1, 1)))
            pb.rotation_quaternion, pb.location, pb.scale = q, loc, sc
            for path in ('rotation_quaternion', 'location', 'scale'):
                pb.keyframe_insert(data_path=path, frame=frame, group=n)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:
                        k.interpolation = 'LINEAR'
    print('ANIM', name, length, flush=True)

rig.animation_data.action = bpy.data.actions['Idle']
scene.frame_set(1)

# ---------------------------------------------------------------- previews opcionales
if PREVIEW_DIR:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
    scene.collection.objects.link(cam)
    target = Vector((0, 0, 0.52))
    cam.location = target + Vector((0.9, -3.0, 0.75))
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = 55
    scene.camera = cam
    world = bpy.data.worlds.new('W')
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.75, 0.8, 0.7, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
    for nm, off, pw in (('Key', (1.5, -2.5, 2.5), 300), ('Fill', (-2.5, -1.5, 1.2), 120), ('Rim', (0, 2, 2.2), 250)):
        ld = bpy.data.lights.new(nm, 'AREA')
        ld.energy, ld.size = pw, 2.5
        lo = bpy.data.objects.new(nm, ld)
        scene.collection.objects.link(lo)
        lo.location = target + Vector(off)
        lo.rotation_euler = (target - lo.location).to_track_quat('-Z', 'Y').to_euler()
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = next(e for e in engines if 'EEVEE' in e)
    scene.view_settings.view_transform = 'Standard'
    scene.render.resolution_x = scene.render.resolution_y = 420
    scene.render.film_transparent = False
    shots = {'Idle': 0.1, 'Thirsty': 0.6, 'Sleep': 0.3, 'Rain': 0.3, 'Hot': 0.3, 'Cold': 0.2,
             'Wave': 0.5, 'Dance': 0.3, 'Jump': 0.45, 'Surprise': 0.3, 'Curious': 0.3, 'Yawn': 0.4,
             'Giggle': 0.4, 'Refresh': 0.5}
    for name, frac in shots.items():
        rig.animation_data.action = bpy.data.actions[name]
        scene.frame_set(1 + int(frac * ANIMS[name][1]))
        scene.render.filepath = str(PREVIEW_DIR / f'{name}.png')
        bpy.ops.render.render(write_still=True)
    rig.animation_data.action = bpy.data.actions['Idle']
    scene.frame_set(1)

# ---------------------------------------------------------------- exportar
GLB_OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=str(GLB_OUT),
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_skins=True,
    export_def_bones=False,
    export_force_sampling=True,
    export_optimize_animation_size=True,
    export_optimize_animation_keep_anim_armature=True,
    export_texcoords=False,
    export_normals=True,
    export_materials='EXPORT',
    export_yup=True,
)
import json  # noqa: E402

(GLB_OUT.parent / 'faces.json').write_text(json.dumps(FACE_TIMELINE, ensure_ascii=False), encoding='utf-8')
print('EXPORTED', GLB_OUT, GLB_OUT.stat().st_size, flush=True)
