"""One-time T13a asset creation. Refuses to overwrite the editable source."""
from pathlib import Path
import math
import random
import bpy
from mathutils import Vector, Quaternion

HERE = Path(__file__).resolve().parent
TARGET = HERE / 'Data_Rescue_Mine.blend'
if TARGET.exists():
    raise RuntimeError('Source already exists. Edit the blend and run export_mine.py instead.')
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(13)

def material(name, color, rough=0.8, metal=0.0, emission=0):
    m = bpy.data.materials.new('MN_MAT_' + name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    return m

M = {
    'iron': material('Cast_Iron', (.075,.085,.08), .64,.55),
    'blue': material('BlueGrey_Siding', (.19,.26,.29), .59,.45),
    'roof': material('BlueGrey_Roof', (.12,.17,.20), .7,.35),
    'rust': material('Rust', (.25,.10,.045)),
    'wood': material('Aged_Wood', (.24,.18,.105), .9),
    'concrete': material('Concrete', (.32,.33,.29)),
    'rock': material('Rock', (.17,.19,.18), .96),
    'mud': material('Mud', (.095,.075,.045), .94),
    'gravel': material('Gravel', (.22,.23,.20)),
    'ivory': material('Computer_Ivory', (.60,.59,.45), .57),
    'screen': material('CRT_Screen', (.012,.045,.035), .25),
    'yellow': material('Warning_Ochre', (.67,.40,.07)),
    'paper': material('Seal_Paper', (.72,.65,.46)),
    'red': material('Seal_Red', (.43,.055,.035)),
    'water': material('Puddle', (.065,.105,.11), .12,.15),
    'dark': material('Adit_Dark', (.005,.007,.008), 1),
    'lamp': material('Lamp_Emissive', (1,.60,.22), .3,0,4),
}
scene = bpy.context.scene
scene.name = 'mine_site'
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
group = None
root = None

def empty(name, loc=(0,0,0), parent=None):
    o = bpy.data.objects.new('MN_' + name, None)
    scene.collection.objects.link(o)
    o.location = loc
    o.parent = parent
    o.empty_display_size = .3
    return o

def finish(o, name, mat):
    o.name = 'MN_' + name
    o.data.name = o.name + '_Mesh'
    o.parent = group
    o.data.materials.append(M[mat])
    return o

def box(name, loc, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(o, name, mat)
    if bevel:
        mod = o.modifiers.new('EdgeWear', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def cyl(name, loc, radius, depth, mat, vertices=12, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    return finish(bpy.context.object, name, mat)

def beam(name, a, b, width, mat):
    d = Vector(b)-Vector(a)
    o = box(name, (Vector(a)+Vector(b))/2, (width,width,d.length), mat)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z','Y')
    return o

def collision(name, loc, size):
    o = empty('Collision_' + name, loc, root)
    o.empty_display_type = 'CUBE'
    o.empty_display_size = 1
    o.scale = [v/2 for v in size]
    o['shape'] = 'box'
    o['half_extents_from_node_scale'] = True
    o['purpose'] = 'T13b: create a hidden BoxShape3D with size = abs(scale) * 2'
    return o

def marker(name, loc):
    o = empty('Interact_' + name, loc, root)
    o.empty_display_type = 'SPHERE'
    o['placeholder_only'] = True
    return o

def section(name):
    global group
    group = empty(name, parent=root)

font = bpy.data.fonts.load('C:/Windows/Fonts/msyhbd.ttc')
def label(name, text, loc, size, mat='ivory'):
    curve = bpy.data.curves.new('MN_' + name, 'FONT')
    curve.body = text
    curve.font = font
    curve.size = size
    curve.align_x = 'CENTER'
    curve.align_y = 'CENTER'
    curve.extrude = .001
    o = bpy.data.objects.new('MN_' + name, curve)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (math.pi/2,0,0)
    o.parent = group
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target='MESH')
    finish(o,name,mat)
    return o

root = empty('MineSite')
root['origin'] = 'Entrance center, ground level; Blender +Y into camp; glTF -Z into camp'
section('Ground')
box('Ground_Base',(0,14,-.3),(32,32,.6),'mud')
box('Track_Ballast',(0,15,.015),(2.8,26,.03),'gravel')
collision('Ground',(0,14,-.3),(32,32,.6))
for i,(x,y,sx,sy) in enumerate([(-3,5,2,1.1),(5,9,1.4,2),(-4,19,2.3,1),(10,5,1.6,.8)]):
    o=cyl('Puddle_%02d'%i,(x,y,.025),1,.018,'water',16)
    o.scale=(sx,sy,1)
for i in range(40):
    x=random.choice([-1,1])*random.uniform(3,14)
    y=random.uniform(1,28)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,.03))
    o=finish(bpy.context.object,'LooseRock_%02d'%i,'rock')
    o.scale=(random.uniform(.12,.3),random.uniform(.1,.25),random.uniform(.06,.13))

section('Gate')
for x in [-3,3]:
    box('Gate_Pier', (x,0,1.9),(.48,.55,3.8),'concrete',.04)
box('Gate_Header',(0,0,3.7),(6.8,.6,.65),'blue',.04)
label('Gate_Title','矿场 · 关闭',(0,-.315,3.7),.40)
box('Closure_Plate',(-4,-.14,1.55),(1.55,.10,.75),'ivory',.025)
label('Closure_Text','禁止入内',(-4,-.20,1.55),.25,'red')
# Open gate leaves keep the entrance corridor clear.
for side in [-1,1]:
    x=side*2.9
    for z in [.28,1.1,2.05]:
        box('Gate_Leaf_Rail',(x,1.25,z),(.09,2.5,.08),'rust')
    for j in range(9):
        box('Gate_Leaf_Bar',(x,j*.3,1.15),(.065,.065,1.9),'iron')
    # Separated torn strips on the two open leaves.
    o=box('Torn_Seal', (x-side*.065,.30,1.35),(.025,.62,.14),'paper')
    o.rotation_euler.x=side*.28
    box('Seal_Red_Stamp',(x-side*.082,.30,1.35),(.012,.12,.11),'red')
    collision('Gate_Leaf_'+str(side),(x,1.25,1.1),(.16,2.5,2.2))
for side in [-1,1]:
    for i in range(7):
        x=side*(3.4+i*2)
        box('Fence_Post',(x,0,1.15),(.11,.12,2.3),'rust')
    for z in [.35,1.1,1.95]:
        box('Fence_Rail',(side*9.5,0,z),(12,.07,.07),'iron')
    for i in range(36):
        x=side*(3.3+i*.34)
        beam('Fence_Wire',(x,0,.3),(x+.28,0,1.95),.018,'iron')
    collision('FrontFence_'+str(side),(side*9.5,0,1.1),(13,.25,2.2))
marker('Gate',(0,0,1.2))
marker('TornSeal',(-2.8,.3,1.35))

def shed(prefix,x,y,w,d):
    box(prefix+'_Foundation',(x,y,.06),(w+.3,d+.3,.12),'concrete')
    box(prefix+'_Rear',(x,y+d/2,1.5),(w,.16,3),'blue')
    for side in [-1,1]:
        box(prefix+'_Side',(x+side*w/2,y,1.5),(.16,d,3),'blue')
        collision(prefix+'_Side_'+str(side),(x+side*w/2,y,1.5),(.2,d,3))
    # 1.3 m front doorway at center; open windows on each side.
    panel=(w-1.3)/2
    for side in [-1,1]:
        px=x+side*(.65+panel/2)
        box(prefix+'_FrontBase',(px,y-d/2,.5),(panel,.16,1),'blue')
        box(prefix+'_WindowHeader',(px,y-d/2,2.65),(panel,.16,.7),'blue')
        for edge in [-1,1]:
            box(prefix+'_WindowFrame',(px+edge*(panel/2-.04),y-d/2,1.65),(.08,.20,1.3),'wood')
        collision(prefix+'_Front_'+str(side),(px,y-d/2,1.5),(panel,.2,3))
    box(prefix+'_Lintel',(x,y-d/2,2.65),(1.3,.16,.7),'wood')
    for side in [-1,1]:
        o=box(prefix+'_Roof',(x+side*w/4,y,3.25),(w/2+.35,d+.7,.14),'roof')
        o.rotation_euler.y=side*.18
        for j in range(int(d/.3)+2):
            beam(prefix+'_RoofRib',(x,y-d/2-.3+j*.3,3.53),(x+side*(w/2+.25),y-d/2-.3+j*.3,3.03),.028,'iron')
    collision(prefix+'_Rear',(x,y+d/2,1.5),(w,.2,3))

section('Dispatch')
shed('Dispatch',-8,8,5,5)
box('Dispatch_Desk',(-8,9.2,.85),(2,.8,.12),'wood',.025)
for x in [-8.8,-7.2]:
    for y in [8.9,9.5]:
        box('Desk_Leg',(x,y,.42),(.08,.08,.84),'iron')
box('Computer_Base',(-8,9.2,.99),(.7,.6,.16),'ivory',.035)
box('Computer_CRT',(-8,9.3,1.34),(.65,.57,.54),'ivory',.055)
box('Computer_Screen',(-8,8.998,1.35),(.51,.025,.38),'screen',.015)
box('Computer_Keyboard',(-8,8.6,.95),(.66,.23,.055),'ivory',.015)
for row in range(3):
    for col in range(10):
        box('Keyboard_Key',(-8.27+col*.058,8.53+row*.06,.985),(.045,.042,.015),'iron')
box('Dispatch_Chair',(-8,8,.48),(.5,.5,.09),'wood')
for x in [-8.2,-7.8]:
    for y in [7.8,8.2]:
        box('Chair_Leg',(x,y,.24),(.045,.045,.48),'iron')
box('Chair_Back',(-8,7.78,.8),(.5,.07,.6),'wood')
label('Dispatch_Label','调度室',(-8,5.40,2.7),.27)
collision('Dispatch_Desk',(-8,9.2,.8),(2,.8,1.6))
marker('Computer',(-8,8.85,1.35))

section('WinchHouse')
shed('WinchHouse',8,19,6,5)
cyl('Winch_Drum',(8,19,.95),.6,1.6,'rust',20,(0,math.pi/2,0))
for x in [7.15,8.85]:
    cyl('Winch_Flange',(x,19,.95),.8,.12,'iron',20,(0,math.pi/2,0))
    box('Winch_Bearing',(x,19,.5),(.25,.6,1),'iron')
for i in range(12):
    cyl('Winch_CableWrap',(7.25+i*.13,19,.95),.62,.04,'iron',20,(0,math.pi/2,0))
box('Winch_Motor',(9.5,19,.6),(.8,1,.7),'blue',.08)
box('Winch_Control',(6.6,17.2,1.0),(.4,.35,1.2),'blue',.03)
cyl('Winch_Stop',(6.6,17.0,1.3),.07,.05,'red',12,(math.pi/2,0,0))
collision('Winch',(8,19,.8),(3.8,1.6,1.6))
marker('WinchControl',(6.6,16.95,1.3))
label('Winch_Label','绞车房',(8,16.40,2.7),.27)

section('Railway')
for x in [-.62,.62]:
    box('Rail',(x,15,.13),(.075,26,.13),'iron')
for i in range(35):
    box('Rail_Sleeper',(0,2.4+i*.72,.055),(1.85,.16,.11),'wood')
box('Cart_Chassis',(0,14,.55),(1.5,2.2,.18),'iron')
box('Cart_Bed',(0,14,.8),(1.6,2.25,.16),'rust')
for x in [-.78,.78]:
    o=box('Cart_Side',(x,14,1.15),(.12,2.25,.75),'rust')
    o.rotation_euler.y=-math.copysign(.12,x)
for y in [12.9,15.1]:
    box('Cart_End',(0,y,1.15),(1.6,.12,.75),'rust')
for x in [-.69,.69]:
    for y in [13.3,14.7]:
        cyl('Cart_Wheel',(x,y,.35),.25,.16,'iron',16,(0,math.pi/2,0))
collision('Cart',(0,14,.8),(1.8,2.4,1.6))
marker('MineCart',(0,12.8,1.15))

section('Adit')
for x in [-2.3,2.3]:
    box('Adit_Pier',(x,27,1.5),(1,1.5,3),'concrete',.08)
box('Adit_Lintel',(0,27,3.1),(5.6,1.5,1),'concrete',.08)
box('Adit_DarkCap',(0,27.75,1.6),(3.6,.1,3.2),'dark')
collision('Adit_Closed',(0,27.8,1.9),(6,.4,3.8))
for i in range(9):
    x=(i-4)*3.9
    if abs(x)<3: continue
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,29,2.0))
    o=finish(bpy.context.object,'RockFace_%02d'%i,'rock')
    o.scale=(3.2,2.4,random.uniform(3,5))
for side in [-1,1]:
    collision('RearRock_'+str(side),(side*9.5,28.7,2.5),(13,3,5))
label('Adit_Warning','危险 · 禁止进入',(0,26.23,3.1),.28,'yellow')
marker('Adit',(0,26,1.5))

section('GeneratorCamp')
box('Generator_Skid',(9,7,.15),(2.7,1.5,.25),'iron')
box('Generator_Housing',(9,7,.77),(2.2,1.2,1.05),'yellow',.09)
for i in range(9):
    box('Generator_Vent',(8.3+i*.12,6.39,.82),(.05,.025,.55),'iron')
cyl('Generator_Exhaust',(9.7,7,1.6),.07,.8,'rust')
cyl('Generator_ExhaustCap',(9.7,7,2.02),.13,.05,'iron')
box('Generator_Control',(9.65,6.37,.95),(.35,.04,.36),'iron')
cyl('Generator_Status',(9.65,6.34,1.04),.035,.025,'lamp',12,(math.pi/2,0,0))
collision('Generator',(9,7,.8),(2.7,1.5,1.6))
marker('Generator',(9.6,6.2,.95))
for i,(x,y) in enumerate([(11,8),(12.1,8.3),(11.6,9.4)]):
    cyl('FuelDrum_%d'%i,(x,y,.47),.34,.94,'blue',16)
    for z in [.14,.78]:
        cyl('FuelDrum_Rim',(x,y,z),.36,.045,'rust',16)
    cyl('FuelDrum_Cap',(x+.12,y,.95),.06,.025,'iron')
collision('FuelDrums',(11.6,8.7,.5),(2,2.2,1))
for a,b in [((9,7,.05),(6,10,.05)),((6,10,.05),(5.5,17,.05)),((5.5,17,.05),(6.6,17.2,.3))]:
    beam('Temporary_PowerCable',a,b,.045,'iron')
for x in [7,12.5]:
    for y in [5.5,10.5]:
        box('RainShelter_Post',(x,y,1.4),(.09,.09,2.8),'iron')
o=box('RainShelter_Roof',(9.75,8,2.85),(6.1,5.7,.10),'roof')
o.rotation_euler.x=.08
for i in range(16):
    beam('RainShelter_Rib',(6.75+i*.4,5.15,2.62),(6.75+i*.4,10.85,3.08),.035,'iron')

section('Lighting')
for i,(x,y) in enumerate([(-3,0),(3,0),(-5,12),(4,23)]):
    cyl('Lamp_Post_%d'%i,(x,y,2.1),.065,4.2,'iron')
    beam('Lamp_Arm',(x,y,4.15),(x+.6,y,4.15),.07,'iron')
    box('Lamp_Hood',(x+.6,y,4.12),(.55,.35,.18),'iron',.03)
    box('Lamp_Emitter',(x+.6,y,4.02),(.40,.24,.035),'lamp')
section('WarningSign')
box('Warning_Post',(-4,22,1),(.1,.1,2),'rust')
box('Warning_Board',(-4,22,1.8),(1.5,.10,.8),'yellow',.03)
label('Warning_Text','当心塌方',(-4,21.94,1.8),.25,'iron')
marker('WarningSign',(-4,21.8,1.8))

# Separate scene, same origin and footprint. No site geometry is duplicated here.
scene = bpy.data.scenes.new('mine_vista')
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
root = empty('MineVista')
section('Vista_Silhouette')
box('Vista_Ground',(0,14,-.3),(32,32,.6),'mud')
for name,x,y,w,d in [('Dispatch',-8,8,5,5),('Winch',8,19,6,5)]:
    box('Vista_'+name,(x,y,1.5),(w,d,3),'blue')
    for side in [-1,1]:
        o=box('Vista_'+name+'_Roof',(x+side*w/4,y,3.25),(w/2+.35,d+.7,.14),'roof')
        o.rotation_euler.y=side*.18
for x in [-3,3]: box('Vista_GatePost',(x,0,1.9),(.48,.55,3.8),'concrete')
box('Vista_GateHeader',(0,0,3.7),(6.8,.6,.65),'blue')
for side in [-1,1]: box('Vista_Fence',(side*9.5,0,1),(13,.12,2),'iron')
box('Vista_Shelter',(9.75,8,2.85),(6.1,5.7,.15),'roof')
for x in [7,12.5]:
    for y in [5.5,10.5]: box('Vista_ShelterPost',(x,y,1.4),(.1,.1,2.8),'iron')
box('Vista_Adit',(0,27,1.9),(5.6,1.5,3.8),'concrete')
box('Vista_AditDark',(0,26.23,1.5),(3.6,.03,3),'dark')
for i,x in enumerate([-14,-10,-6,6,10,14]):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,29,2))
    o=finish(bpy.context.object,'Vista_Rock_%d'%i,'rock')
    o.scale=(3.2,2.4,4)
for i,(x,y) in enumerate([(-3,0),(3,0),(-5,12),(4,23)]):
    box('Vista_LampPost_%d'%i,(x,y,2.1),(.09,.09,4.2),'iron')
    box('Vista_Lamp_Emitter_%d'%i,(x+.3,y,4.05),(.55,.35,.15),'lamp')

bpy.context.window.scene = bpy.data.scenes['mine_site']
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.type = 'SOLID'
            area.spaces.active.shading.color_type = 'MATERIAL'
            area.spaces.active.region_3d.view_distance = 46
            area.spaces.active.region_3d.view_location = (0,13,1)
            area.spaces.active.region_3d.view_rotation = Quaternion((.88,.39,.12,.23)).normalized()
bpy.ops.object.select_all(action='DESELECT')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print('T13A_BUILD_OK', TARGET)
