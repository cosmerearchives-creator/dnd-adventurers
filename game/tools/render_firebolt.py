import bpy, math, os
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=os.environ['FIREBOLT_MODEL'])
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
points=[o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
center=(lo+hi)/2
span=max(hi-lo)
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.color_type='TEXTURE'
scene.display.shading.light='STUDIO'
scene.display.shading.show_shadows=False
scene.render.film_transparent=True
scene.render.resolution_x=128
scene.render.resolution_y=128
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
bpy.ops.object.camera_add(location=center+Vector((0,-span*2,0)))
cam=bpy.context.object
cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=span*1.15
cam.data.clip_end=span*10
scene.camera=cam
out=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'assets','firebolt.png')
os.makedirs(os.path.dirname(out),exist_ok=True)
scene.render.filepath=out
bpy.ops.render.render(write_still=True)
