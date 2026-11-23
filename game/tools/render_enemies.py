import bpy, math, os
from mathutils import Vector
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.light='STUDIO'
scene.display.shading.show_shadows=True
scene.render.resolution_x=128
scene.render.resolution_y=160
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
def material(name,rgb):
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);return m
fur=material('ash wolf fur',(.36,.31,.28))
fur_light=material('wolf muzzle',(.62,.55,.44))
black=material('dark nose and claws',(.075,.06,.055))
eye=material('amber eyes',(.85,.50,.12))
green=material('goblin olive skin',(.32,.48,.15))
green_light=material('goblin ears',(.45,.62,.22))
leather=material('worn brown leather',(.28,.15,.075))
metal=material('iron',(.42,.44,.43))
bone=material('aged bone',(.82,.78,.65))
bone_dark=material('skull recesses',(.15,.13,.11))
cloth=material('ragged dark cloth',(.21,.18,.19))
def ell(name,loc,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat);return o
def cone(name,loc,r1,r2,depth,mat,rotation=None):
 bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=r1,radius2=r2,depth=depth,location=loc)
 o=bpy.context.object;o.name=name;o.data.materials.append(mat)
 if rotation:o.rotation_euler=rotation
 return o
def rod(name,a,b,r,mat):
 a,b=Vector(a),Vector(b)
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(b-a).length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat);return o
def build(kind):
 if kind=='wolf':
  ell('wolf barrel',(0,0,.77),(.40,.69,.35),fur)
  ell('wolf chest',(0,-.40,.88),(.39,.34,.42),fur_light)
  ell('wolf neck',(0,-.59,1.05),(.30,.27,.32),fur)
  ell('wolf head',(0,-.80,1.19),(.28,.31,.25),fur)
  ell('long muzzle',(0,-1.06,1.09),(.19,.31,.13),fur_light)
  ell('nose',(0,-1.33,1.12),(.12,.07,.065),black)
  for s in [-1,1]:
   cone('pointed ear',(s*.21,-.70,1.48),.14,.015,.38,fur)
   ell('amber eye',(s*.20,-1.02,1.25),(.055,.035,.047),eye)
   for y in [-.42,.47]:
    ell('leg upper',(s*.29,y,.46),(.115,.15,.37),fur)
    ell('paw',(s*.29,y-.12,.12),(.13,.21,.09),fur_light)
  ell('bushy tail',(0,.85,.96),(.16,.36,.19),fur)
 elif kind=='goblin':
  ell('short muscular torso',(0,0,1.13),(.38,.27,.46),green)
  ell('leather vest',(0,-.18,1.12),(.32,.13,.37),leather)
  ell('goblin head',(0,-.07,1.83),(.34,.29,.34),green)
  ell('broad hooked nose',(0,-.37,1.76),(.12,.19,.10),green_light)
  for s in [-1,1]:
   cone('long pointed ear',(s*.47,-.02,1.87),.16,.015,.48,green_light,(0,s*.85,0))
   ell('yellow eye',(s*.16,-.34,1.91),(.073,.04,.055),eye)
   ell('arm',(s*.43,-.02,1.18),(.13,.14,.38),green)
   ell('hand',(s*.48,-.12,.78),(.13,.12,.14),green_light)
   ell('leg',(s*.19,0,.52),(.17,.18,.41),leather)
   ell('foot',(s*.19,-.14,.13),(.19,.26,.12),black)
  ell('belt',(0,-.19,.85),(.36,.12,.08),metal)
  rod('rusty dagger',(.48,-.15,.78),(.57,-.30,.31),.035,metal)
 else:
  ell('ribcage',(0,0,1.35),(.34,.22,.40),bone)
  ell('skull',(0,-.03,2.08),(.30,.25,.31),bone)
  ell('jaw',(0,-.17,1.86),(.24,.15,.10),bone)
  for s in [-1,1]:
   ell('eye socket',(s*.14,-.25,2.11),(.09,.05,.10),bone_dark)
   ell('shoulder',(s*.37,0,1.64),(.12,.13,.12),bone)
   rod('humerus',(s*.38,0,1.60),(s*.44,-.06,1.18),.065,bone)
   rod('forearm',(s*.44,-.06,1.18),(s*.46,-.15,.81),.048,bone)
   rod('femur',(s*.18,0,.98),(s*.21,-.02,.57),.09,bone)
   rod('shin',(s*.21,-.02,.57),(s*.22,-.12,.15),.055,bone)
   ell('foot',(s*.22,-.18,.11),(.14,.22,.07),bone)
  for z in [1.23,1.35,1.47,1.59]:
   rod('left rib',(-.29,-.08,z),(0,-.22,z-.04),.032,bone)
   rod('right rib',(.29,-.08,z),(0,-.22,z-.04),.032,bone)
  rod('spine',(0,.08,1.0),(0,.06,1.85),.055,bone)
  ell('torn waistcloth',(0,-.06,.93),(.33,.25,.16),cloth)
  rod('rusty sword',(.46,-.15,.8),(.55,-.45,.24),.048,metal)
cam_data=bpy.data.cameras.new('camera')
cam=bpy.data.objects.new('camera',cam_data);bpy.context.collection.objects.link(cam)
cam.location=(0,-6,5.2)
cam.rotation_euler=(Vector((0,0,1.12))-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO';cam_data.ortho_scale=3.25;scene.camera=cam
out=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'assets','enemies')
os.makedirs(out,exist_ok=True)
for kind in ['wolf','goblin','skeleton']:
 bpy.ops.object.select_all(action='DESELECT')
 for old in list(bpy.context.scene.objects):
  if old.type=='MESH' or old.name=='enemy_root':old.select_set(True)
 bpy.ops.object.delete(use_global=False)
 build(kind)
 root=bpy.data.objects.new('enemy_root',None);bpy.context.collection.objects.link(root)
 for obj in list(bpy.context.scene.objects):
  if obj.type=='MESH':obj.parent=root
 # Save the neutral pose and animate the actual limbs, not just the body bob.
 parts=[(o,o.location.copy(),o.rotation_euler.copy()) for o in scene.objects if o.type=='MESH']
 for direction in range(8):
  for frame in range(4):
   phase=frame*math.tau/4
   for obj,base,rotation in parts:
    obj.location=base.copy()
    obj.rotation_euler=rotation.copy()
    name=obj.name.lower()
    side=-1 if base.x<0 else 1
    front=-1 if base.y<0 else 1
    if kind=='wolf':
     if 'leg upper' in name or 'paw' in name:
      stride=math.sin(phase+(0 if side*front>0 else math.pi))
      obj.location.y+=.17*stride
      obj.location.z+=.075*max(0,stride)
     elif 'tail' in name:
      obj.location.x+=.13*math.sin(phase)
     elif 'head' in name or 'muzzle' in name or 'nose' in name:
      obj.location.z+=.025*math.sin(phase*2)
    else:
     if 'leg' in name or 'femur' in name or 'shin' in name or 'foot' in name:
      stride=math.sin(phase+(0 if side<0 else math.pi))
      obj.location.y+=.16*stride
      obj.location.z+=.07*max(0,stride)
     if 'arm' in name or 'hand' in name or 'humerus' in name or 'forearm' in name:
      obj.location.y-=.10*math.sin(phase+(0 if side<0 else math.pi))
   root.rotation_euler.z=direction*math.tau/8
   root.location.z=.025*math.sin(phase*2)
   scene.render.filepath=os.path.join(out,f'{kind}_{direction}_{frame}.png')
   bpy.ops.render.render(write_still=True)
print('Rendered 96 animated enemy frames (3 kinds x 8 directions x 4 walking poses)')
