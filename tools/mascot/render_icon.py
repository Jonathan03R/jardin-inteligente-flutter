"""Renderiza a Brotito de frente, cara contenta, fondo transparente (base del icono de la app).

  blender --background --factory-startup --python tools/mascot/render_icon.py -- assets/mascot/brotito.glb salida.png
"""
import math
import sys

import bpy
from mathutils import Vector

glb, out = sys.argv[sys.argv.index('--') + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
scene = bpy.context.scene

# Pose de reposo y una sola cara visible.
for o in scene.objects:
    if o.type == 'ARMATURE':
        if o.animation_data:
            o.animation_data.action = None
        for pb in o.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)
    if o.type == 'MESH':
        names = [m.name for m in o.data.materials if m]
        if any('@' in n and not n.endswith('@Joy') for n in names):
            o.hide_render = True

target = Vector((0, 0, 0.53))
cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 1.18
cam.location = target + Vector((0, -4, 0.9))
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.camera = cam

world = bpy.data.worlds.new('W')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.8, 0.85, 0.78, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
for nm, off, pw in (('Key', (1.6, -2.6, 2.6), 380), ('Fill', (-2.6, -1.6, 1.0), 160), ('Rim', (0, 2.2, 2.2), 300)):
    ld = bpy.data.lights.new(nm, 'AREA')
    ld.energy, ld.size = pw, 2.5
    lo = bpy.data.objects.new(nm, ld)
    scene.collection.objects.link(lo)
    lo.location = target + Vector(off)
    lo.rotation_euler = (target - lo.location).to_track_quat('-Z', 'Y').to_euler()

engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
scene.render.engine = next(e for e in engines if 'EEVEE' in e)
scene.view_settings.view_transform = 'Standard'
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print('ICON', out, math.pi)
