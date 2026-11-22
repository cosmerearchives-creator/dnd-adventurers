import bpy, math, os
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.light='STUDIO'
scene.display.shading.show_shadows=True
scene.render.resolution_x=192
scene.render.resolution_y=256
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
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=(x,y,z))
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
# More sculpted adult silhouette and detailed fantasy costume.
moss=mat('light moss',(.28,.43,.17))
dark=mat('deep forest',(.075,.14,.085))
copper=mat('copper hair highlights',(.54,.23,.095))
ivory=mat('ivory',(.82,.72,.52))
def tapered(name,x,y,z,r1,r2,depth,material):
    bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r1,radius2=r2,depth=depth,location=(x,y,z))
    obj=bpy.context.object
    obj.name=name
    obj.data.materials.append(material)
    obj.parent=rig
    parts.append(obj)
    return obj
# A fitted corset, shaped waist, decorative neckline and layered skirt panels.
ball('fitted corset',0,-.13,1.61,.265,.145,.29,leather)
ball('waist belt',0,-.17,1.43,.31,.12,.055,gold)
ball('corset clasp',0,-.283,1.66,.055,.035,.10,gold)
ball('neckline trim',0,-.18,1.99,.29,.10,.05,gold)
ball('neckline inset',0,-.218,2.015,.16,.055,.075,skin)
ball('leaf mantle',0,.09,1.98,.46,.19,.11,dark)
for side in [-1,1]:
    ball('sculpted thigh',side*.19,-.025,.88,.165,.18,.31,skin)
    ball('hip shaping',side*.30,-.005,1.27,.16,.21,.20,green)
    ball('skirt leaf',side*.34,-.14,1.14,.17,.09,.36,moss)
    ball('skirt seam',side*.25,-.227,1.17,.045,.027,.29,gold)
    ball('boot top',side*.19,-.045,.66,.18,.19,.075,gold)
    ball('boot heel',side*.19,-.13,.12,.19,.24,.105,leather)
    ball('boot buckle',side*.19,-.218,.40,.07,.028,.04,gold)
    ball('shoulder mantle',side*.39,.02,1.94,.18,.16,.10,moss)
    ball('upper arm band',side*.45,-.055,1.82,.12,.14,.045,gold)
    ball('wrist cuff',side*.45,-.03,1.47,.13,.13,.08,leather)
    ball('glove trim',side*.45,-.155,1.47,.08,.03,.04,gold)
    ball('long curled hair',side*.29,.075,2.11,.12,.13,.55,copper)
    ball('hair tip',side*.33,-.03,1.68,.09,.11,.22,hair)
    ball('eyebrow',side*.10,-.235,2.49,.08,.017,.019,hair)
    ball('cheek',side*.14,-.206,2.33,.09,.028,.06,skin)
    ball('leaf circlet',side*.17,-.14,2.64,.12,.06,.055,gold)
    tapered('antler',side*.33,.03,2.84,.025,.006,.37,ivory)
    tapered('antler tine',side*.40,-.02,2.94,.018,.004,.20,ivory)
ball('hair fringe',0,-.10,2.66,.24,.14,.105,copper)
ball('nose',0,-.25,2.34,.045,.04,.065,skin)
ball('lips',0,-.243,2.26,.09,.023,.025,copper)
ball('central leaf brooch',0,-.30,1.91,.065,.04,.10,gold)
ball('jaw',0,-.065,2.255,.185,.175,.13,skin)
for side in [-1,1]:
    ball('ear',side*.235,-.015,2.37,.07,.065,.11,skin)
    ball('elbow',side*.455,-.035,1.58,.105,.11,.11,skin)
    ball('forearm',side*.47,-.065,1.43,.092,.10,.22,skin)
    ball('hand',side*.48,-.085,1.24,.085,.08,.115,skin)
    ball('knee',side*.19,-.04,.60,.135,.15,.13,skin)
    ball('foot',side*.19,-.16,.11,.16,.27,.11,leather)
    ball('hair lock',side*.23,-.19,2.14,.09,.09,.38,copper)
    ball('leaf cape edge',side*.52,.13,1.38,.095,.09,.58,moss)
ball('chin',0,-.21,2.255,.10,.045,.05,skin)
ball('nose bridge',0,-.238,2.40,.035,.035,.11,skin)
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
    for animation,count in [('idle',1),('walk',6),('cast',2),('hit',1)]:
        for frame in range(count):
            rig.rotation_euler.z=direction*math.pi/4
            rig.location.z=0
            for obj,position in base:
                obj.location=position.copy()
            if animation=='walk':
                phase=frame*math.pi/3
                stride=math.sin(phase)
                rig.location.z=.035*abs(math.sin(phase))
                for obj in parts:
                    side=1 if obj.location.x>0 else -1
                    if obj.name in ('leg','sculpted thigh','knee','boot','boot top','boot heel','boot buckle','foot'):
                        obj.location.y+=side*.27*stride
                        obj.location.z+=max(0.0,side*math.cos(phase))*.12
                    elif obj.name in ('arm','elbow','forearm','hand','wrist cuff','glove trim'):
                        obj.location.y-=side*.20*stride
                        obj.location.z+=.03*math.sin(phase)
                    elif obj.name in ('hip','hip shaping','skirt leaf','skirt seam'):
                        obj.location.x+=.025*stride
                    elif obj.name in ('hair strand','long curled hair','hair tip','hair lock','leaf cape edge'):
                        obj.location.y+=.055*math.sin(phase-.7)
            elif animation=='cast':
                for obj in parts:
                    if obj.name=='arm':
                        obj.location.z+=.25
            elif animation=='hit':
                rig.location.z=-.07
            scene.render.filepath=os.path.join(output,f'{animation}_{direction}_{frame}.png')
            bpy.ops.render.render(write_still=True)
print('Rendered 80 druid frames')
