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
# Smooth connected lofts replace the spherical torso and skirt silhouette.
def loft(name, rings, material):
    verts=[]
    faces=[]
    n=24
    for z,rx,ry,cx,cy in rings:
        for i in range(n):
            a=2*math.pi*i/n
            verts.append((cx+rx*math.cos(a),cy+ry*math.sin(a),z))
    for j in range(len(rings)-1):
        for i in range(n):
            k=j*n+i
            nxt=j*n+(i+1)%n
            faces.append((k,nxt,nxt+n,k+n))
    faces.append(tuple(reversed(tuple(range(n)))))
    faces.append(tuple((len(rings)-1)*n+i for i in range(n)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.parent=rig
    parts.append(obj)
    for face in mesh.polygons:
        face.use_smooth=True
    return obj
loft('connected female torso',[
    (1.20,.37,.27,0,0),(1.35,.32,.24,0,0),(1.53,.24,.20,0,0),
    (1.72,.28,.22,0,0),(1.88,.37,.25,0,0),(2.02,.29,.21,0,0),
    (2.10,.13,.13,0,0)],green)
loft('layered druid skirt',[
    (.89,.44,.31,0,.035),(1.03,.43,.29,0,.02),
    (1.24,.37,.26,0,0),(1.38,.29,.23,0,0)],dark)
loft('back cape',[(.70,.52,.13,0,.20),(1.14,.56,.14,0,.20),
    (1.65,.44,.14,0,.19),(1.99,.33,.13,0,.16)],green)

for side in [-1,1]:
    
    
    ball('hip',side*.24,0,1.19,.2,.24,.30,green)
    ball('bodice',side*.16,-.18,1.85,.18,.12,.20,leather)
    
    ball('hair strand',side*.26,.12,2.15,.13,.15,.52,hair)
    ball('eye',side*.10,-.225,2.42,.035,.02,.026,leather)


ball('neck',0,0,2.15,.12,.12,.16,skin)

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
loft('fitted leather corset',[(1.40,.275,.23,0,-.015),(1.53,.245,.215,0,-.015),(1.72,.285,.23,0,-.015),(1.84,.335,.235,0,-.015)],leather)
ball('waist belt',0,-.17,1.43,.31,.12,.055,gold)
ball('corset clasp',0,-.283,1.66,.055,.035,.10,gold)
ball('neckline trim',0,-.18,1.99,.29,.10,.05,gold)
ball('neckline inset',0,-.218,2.015,.16,.055,.075,skin)
ball('leaf mantle',0,.09,1.98,.46,.19,.11,dark)
for side in [-1,1]:
    
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
loft('face and jaw',[(2.18,.105,.12,0,-.05),(2.25,.16,.17,0,-.05),(2.40,.23,.19,0,-.035),(2.53,.21,.17,0,-.025),(2.63,.12,.13,0,-.01)],skin)
for side in [-1,1]:
    ball('ear',side*.235,-.015,2.37,.07,.065,.11,skin)
    
    
    ball('hand',side*.48,-.085,1.24,.085,.08,.115,skin)
    
    ball('foot',side*.19,-.16,.11,.16,.27,.11,leather)
    ball('hair lock',side*.23,-.19,2.14,.09,.09,.38,copper)
    ball('leaf cape edge',side*.52,.13,1.38,.095,.09,.58,moss)
ball('chin',0,-.21,2.255,.10,.045,.05,skin)
ball('nose bridge',0,-.238,2.40,.035,.035,.11,skin)
# Articulated two-segment limbs with real knee/elbow bends.
# Geometry is driven by joints for every pose rather than sliding whole legs.
limbs={}
def bone(name,a,b,radius,material):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=1,depth=1,location=(a+b)/2)
    obj=bpy.context.object
    obj.name=name
    obj.data.materials.append(material)
    obj.parent=rig
    parts.append(obj)
    set_bone(obj,a,b,radius)
    return obj
def set_bone(obj,a,b,radius):
    a,b=Vector(a),Vector(b)
    obj.location=(a+b)/2
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    obj.scale=(radius,radius,(b-a).length)
for side in [-1,1]:
    tag='L' if side<0 else 'R'
    hip=(side*.20,0,1.23)
    knee=(side*.21,-.04,.68)
    ankle=(side*.21,-.02,.15)
    shoulder=(side*.40,0,1.91)
    elbow=(side*.49,-.035,1.57)
    wrist=(side*.49,-.07,1.30)
    limbs[tag]={
        'thigh':bone(tag+' thigh',hip,knee,.155,skin),
        'shin':bone(tag+' boot',knee,ankle,.155,leather),
        'upper':bone(tag+' upper arm',shoulder,elbow,.108,skin),
        'lower':bone(tag+' forearm',elbow,wrist,.092,skin)}
camera_data=bpy.data.cameras.new('camera')
camera=bpy.data.objects.new('camera',camera_data)
bpy.context.collection.objects.link(camera)
camera.location=(0,-7,6.2)
camera.rotation_euler=(Vector((0,0,1.5))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=3.65
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
base=[(obj,obj.location.copy(),obj.rotation_euler.copy(),obj.scale.copy()) for obj in parts]
for direction in range(8):
    for animation,count in [('idle',1),('walk',8),('cast',2),('hit',1)]:
        for frame in range(count):
            rig.rotation_euler.z=direction*math.pi/4
            rig.location.z=0
            for obj,position,rotation,scale in base:
                obj.location=position.copy()
                obj.rotation_euler=rotation.copy()
                obj.scale=scale.copy()
            phase=frame*math.tau/8
            if animation=='walk':
                rig.location.z=.035*abs(math.sin(phase))
            elif animation=='hit':
                rig.location.z=-.06
            for side,tag in [(-1,'L'),(1,'R')]:
                stride=math.sin(phase)*(1 if side>0 else -1) if animation=='walk' else 0
                lift=max(0,math.cos(phase)*(1 if side>0 else -1)) if animation=='walk' else 0
                hip=Vector((side*.20,0,1.23))
                knee=Vector((side*.21,-.07+stride*.17,.69+lift*.075))
                ankle=Vector((side*.21,-.03+stride*.31,.15+lift*.14))
                shoulder=Vector((side*.40,0,1.91))
                elbow=Vector((side*.48,.03-stride*.14,1.60))
                wrist=Vector((side*.49,-.04-stride*.23,1.32))
                if animation=='cast' and side>0:
                    elbow=Vector((side*.50,-.24,1.91))
                    wrist=Vector((side*.54,-.38,2.05 if frame==0 else 2.18))
                set_bone(limbs[tag]['thigh'],hip,knee,.155)
                set_bone(limbs[tag]['shin'],knee,ankle,.15)
                set_bone(limbs[tag]['upper'],shoulder,elbow,.108)
                set_bone(limbs[tag]['lower'],elbow,wrist,.09)
                for obj in parts:
                    if obj.name in ('foot','boot heel','boot buckle','boot top','hand','wrist cuff','glove trim'):
                        if (obj.location.x>0)==(side>0):
                            if obj.name in ('foot','boot heel','boot buckle','boot top'):
                                obj.location.y+=stride*.31
                                obj.location.z+=lift*.14
                            else:
                                obj.location.y-=stride*.23
                                if animation=='cast' and side>0:
                                    obj.location.z+=.60
            if animation=='walk':
                for obj in parts:
                    if obj.name in ('hair strand','long curled hair','hair tip','hair lock','leaf cape edge'):
                        obj.location.y+=.05*math.sin(phase-.6)
            scene.render.filepath=os.path.join(output,f'{animation}_{direction}_{frame}.png')
            bpy.ops.render.render(write_still=True)
print('Rendered 96 articulated druid frames')
