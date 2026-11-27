import bpy, math, os, sys
from mathutils import Vector, Matrix
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
source=os.environ.get('PLAYER_MODEL',os.path.join(os.environ.get('TEMP','/tmp'),'woman-base-character-rigged.glb'))
bpy.ops.import_scene.gltf(filepath=source)
scene=bpy.context.scene
arm=next(o for o in scene.objects if o.type=='ARMATURE')
mesh=next(o for o in scene.objects if o.type=='MESH' and o.parent==arm)
for o in list(scene.objects):
    if o not in (arm,mesh):
        bpy.data.objects.remove(o,do_unlink=True)
base_rotation=arm.rotation_euler.copy()
arm.rotation_mode='XYZ'
if not arm.animation_data: arm.animation_data_create()
for track in arm.animation_data.nla_tracks:
    track.mute=True
actions={a.name.lower():a for a in bpy.data.actions}
arm.animation_data.action=actions['walk']
scene.frame_set(0)
pose_a={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in arm.pose.bones}
scene.frame_set(12)
pose_b={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in arm.pose.bones}
def neutral_pose():
    arm.animation_data.action=None
    for b in arm.pose.bones:
        a,c=pose_a[b.name],pose_b[b.name]
        b.rotation_mode='QUATERNION'
        b.location=a[0].lerp(c[0],0.5)
        b.rotation_quaternion=a[1].slerp(c[1],0.5)
        b.scale=a[2].lerp(c[2],0.5)
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=320
scene.render.resolution_y=448
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.image_settings.color_depth='8'
scene.render.image_settings.compression=40
scene.render.dither_intensity=0
scene.render.engine='BLENDER_EEVEE'
scene.render.image_settings.color_mode='RGBA'
try: scene.render.image_settings.color_depth='8'
except: pass
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new('Studio ambient')
scene.world=world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(0.75,0.8,0.9,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=0.7
def area(name, location, power, size):
    data=bpy.data.lights.new(name,'AREA')
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=location
    obj.rotation_euler=(Vector((0,0,0.85))-obj.location).to_track_quat('-Z','Y').to_euler()
    data.energy=power
    data.shape='DISK'
    data.size=size
area('soft key',(-3,-4,5),550,4.0)
area('soft fill',(3,1,3),330,4.0)
area('hair rim',(1,3,4),420,2.5)
camera_data=bpy.data.cameras.new('CharacterOrthographic')
camera=bpy.data.objects.new('CharacterOrthographic',camera_data)
scene.collection.objects.link(camera)
target=Vector((0,0,0.85))
camera.location=(0,-5.0,3.15)
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=2.05
scene.camera=camera
output=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'assets','druid')
os.makedirs(output,exist_ok=True)
preview='--preview' in sys.argv
for direction in range(8):
    for animation,count in [('idle',1),('walk',8),('cast',2),('hit',1)]:
        for frame in range(count):
            if preview and (direction!=0 or animation!='idle'): continue
            if '--preview-cast' in sys.argv and (direction!=0 or animation!='cast' or frame!=1): continue
            if '--cast-only' in sys.argv and animation!='cast': continue
            if '--static-only' in sys.argv and animation=='walk': continue
            if animation=='walk':
                arm.animation_data.action=actions['walk']
                scene.frame_set(frame*3)
            else:
                neutral_pose()
            arm.rotation_euler=base_rotation.copy()
            arm.rotation_euler.z=base_rotation.z+direction*math.pi/4
            arm.location.z=0.0
            if animation=='hit':
                arm.location.z=-0.045
            if animation=='cast':
                # Aim forward while preserving the rig, skinning and source textures.
                upper=arm.pose.bones.get('RightArm')
                if upper:
                    mat=upper.matrix.copy()
                    pivot=mat.translation
                    swing=Matrix.Rotation(-1.2 if frame==0 else -1.85,4,'X')
                    upper.matrix=Matrix.Translation(pivot) @ swing @ Matrix.Translation(-pivot) @ mat
            scene.render.filepath=os.path.join(output,f'{animation}_{direction}_{frame}.png')
            bpy.ops.render.render(write_still=True)
    if preview: break
print('COMPLETE', 'preview' if preview else '96 frames', output)
