import bpy, math, os
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=128
scene.render.resolution_y=176
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
def mat(name,color):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    return m
skin=mat('warm skin',(.76,.49,.38))
hair=mat('auburn hair',(.33,.12,.06))
green=mat('forest green',(.14,.3,.15))
leather=mat('fitted leather',(.2,.12,.075))
gold=mat('bronze trim',(.62,.44,.17))
rig=bpy.data.objects.new('druid',None)
bpy.context.collection.objects.link(rig)
parts=[]
def ball(name,x,y,z,sx,sy,sz,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=(x,y,z))
    obj=bpy.context.object
    obj.name=name
    obj.scale=(sx,sy,sz)
    obj.data.materials.append(material)
    obj.parent=rig
    parts.append(obj)
ball('cloak',0,.18,1.37,.56,.15,.79,green)
for side in [-1,1]:
    ball('leg',side*.19,0,.7,.14,.17,.45,skin)
    ball('boot',side*.19,-.02,.39,.16,.19,.36,leather)
    ball('hip',side*.24,0,1.19,.2,.24,.30,green)
    ball('bodice',side*.16,-.18,1.85,.18,.12,.20,leather)
    ball('arm',side*.45,0,1.72,.12,.13,.34,skin)
    ball('hair strand',side*.26,.12,2.15,.13,.15,.52,hair)
    ball('eye',side*.10,-.225,2.42,.035,.02,.026,leather)
ball('waist',0,0,1.53,.25,.21,.26,leather)
ball('torso',0,0,1.84,.35,.25,.31,green)
ball('neck',0,0,2.15,.12,.12,.16,skin)
ball('face',0,-.035,2.4,.24,.21,.29,skin)
ball('hair cap',0,.06,2.59,.27,.22,.19,hair)
ball('brooch',0,-.25,1.72,.08,.05,.08,gold)
camera_data=bpy.data.cameras.new('camera')
camera=bpy.data.objects.new('camera',camera_data)
bpy.context.collection.objects.link(camera)
camera.location=(0,-7,4.5)
camera.rotation_euler=(Vector((0,0,1.5))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=3.7
scene.camera=camera
light_data=bpy.data.lights.new('softbox','AREA')
light=bpy.data.objects.new('softbox',light_data)
bpy.context.collection.objects.link(light)
light.location=(-3,-4,6)
light_data.energy=700
light_data.size=5
light.rotation_euler=(Vector((0,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()
output=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'assets','druid')
os.makedirs(output,exist_ok=True)
base=[(obj,obj.location.copy()) for obj in parts]
for direction in range(8):
    for animation,count in [('idle',1),('walk',3),('cast',2),('hit',1)]:
        for frame in range(count):
            rig.rotation_euler.z=direction*math.pi/4
            rig.location.z=0
            for obj,position in base:
                obj.location=position.copy()
            if animation=='walk':
                for obj in parts:
                    if obj.name in ('leg','boot'):
                        obj.location.y+=math.sin(frame*2*math.pi/3)*(1 if obj.location.x>0 else -1)*.14
            elif animation=='cast':
                for obj in parts:
                    if obj.name=='arm':
                        obj.location.z+=.25
            elif animation=='hit':
                rig.location.z=-.07
            scene.render.filepath=os.path.join(output,f'{animation}_{direction}_{frame}.png')
            bpy.ops.render.render(write_still=True)
print('Rendered 56 druid frames')
