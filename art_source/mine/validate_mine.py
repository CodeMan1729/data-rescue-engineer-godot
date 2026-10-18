"""Non-visual source and GLB checks; writes a complete node inventory."""
from pathlib import Path
import json
import struct
import bpy

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'Data_Rescue_Mine.blend'
if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
report = {'coordinate_system': {'source': 'Z up, +Y into camp, meters', 'glb': 'Y up, -Z into camp, meters'}, 'scenes': {}}
expected_markers = {'Gate','TornSeal','Computer','WinchControl','MineCart','Adit','Generator','WarningSign'}
assert all(a.spaces.active.shading.type == 'SOLID' for s in bpy.data.screens for a in s.areas if a.type == 'VIEW_3D')
assert all(m.name.startswith('MN_MAT_') for m in bpy.data.materials)
assert all(max(i.size) <= 2048 for i in bpy.data.images if i.type == 'IMAGE')
for name, budget in [('mine_site',150000),('mine_vista',20000)]:
    s = bpy.data.scenes[name]
    assert s.unit_settings.system == 'METRIC' and s.unit_settings.scale_length == 1
    assert all(o.name.startswith('MN_') for o in s.objects)
    assert not any(o.type in {'LIGHT','CAMERA','FONT'} for o in s.objects)
    root = s.objects['MN_MineSite' if name == 'mine_site' else 'MN_MineVista']
    assert root.location.length == 0
    objects = []
    for o in sorted(s.objects, key=lambda o:o.name):
        triangles = 0
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            triangles = len(o.data.loop_triangles)
        objects.append({'name':o.name,'parent':o.parent.name if o.parent else None,
                        'type':o.type,'location_blender':list(o.location),
                        'scale':list(o.scale),'triangles':triangles})
    p = HERE.parents[1] / 'assets' / 'mine' / (name+'.glb')
    with p.open('rb') as f:
        magic,version,length = struct.unpack('<III',f.read(12))
        assert magic == 0x46546C67 and version == 2 and length == p.stat().st_size
        chunk,kind = struct.unpack('<II',f.read(8))
        assert kind == 0x4E4F534A
        gltf = json.loads(f.read(chunk))
    nodes = {n['name']:n for n in gltf['nodes']}
    assert set(nodes) == {o.name for o in s.objects}, 'Exported node set differs from source'
    triangles = sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
    assert triangles <= budget
    assert not gltf.get('images'), 'Current asset should use portable constant PBR materials'
    lamps = [m for m in gltf['materials'] if m['name']=='MN_MAT_Lamp_Emissive']
    assert len(lamps)==1 and max(lamps[0]['emissiveFactor'])>0
    markers = [o['name'] for o in objects if o['name'].startswith('MN_Interact_')]
    collisions = [o['name'] for o in objects if o['name'].startswith('MN_Collision_')]
    if name == 'mine_site':
        assert set(markers) == {'MN_Interact_'+m for m in expected_markers}
        for n in collisions:
            assert 'mesh' not in nodes[n] and nodes[n]['extras']['shape']=='box'
        pos = nodes['MN_Interact_Computer']['translation']
        assert abs(pos[0]+8)<.001 and abs(pos[1]-1.35)<.001 and abs(pos[2]+8.85)<.001
    else:
        assert not markers and not collisions
    report['scenes'][name] = {'triangles_glb':triangles,'budget':budget,'glb_bytes':p.stat().st_size,
                             'nodes':objects,'interaction_markers':markers,'collision_markers':collisions}
(HERE/'node_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for name, data in report['scenes'].items():
    print(name, 'nodes=',len(data['nodes']),'triangles=',data['triangles_glb'], 'collisions=',len(data['collision_markers']), 'interactions=',len(data['interaction_markers']))
print('T13A_VALIDATION_OK')
