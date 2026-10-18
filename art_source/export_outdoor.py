"""Read-only outdoor export. Run with Blender --background --factory-startup --python.

Uses the saved lightweight particle preview distribution, without reseeding or
saving the master. Temporary meshes/materials exist only in this process.
"""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import math
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/Data_Rescue_Forest_Station.blend'
DEST = ROOT / 'assets/outdoor'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    before = digest(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    source_scene = bpy.context.scene
    # The station GLB has its floor plank centre at the origin.
    foundation = bpy.data.objects['MS_Foundation'].matrix_world.translation
    floor = bpy.data.objects['MS_Floor_Plank_00_0'].matrix_world.translation.z
    offset = Vector((foundation.x, foundation.y, floor))
    convert = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
    translate = Matrix.Translation(-offset)
    dg = bpy.context.evaluated_depsgraph_get()
    records = []
    originals = {}
    for instance in dg.object_instances:
        if instance.is_instance and instance.object.original.name.startswith('bq_'):
            obj = instance.object.original
            originals[obj.name] = obj
            matrix = convert @ translate @ instance.matrix_world @ convert.inverted()
            records.append((obj.name, [round(matrix[r][c], 6) for c in range(4) for r in range(3)]))
    assert records, 'No source vegetation instances'
    terrains = [o for o in source_scene.objects if o.type == 'MESH' and o.name.startswith(('Forest |', 'Botaniq | continuous'))]
    assert len(terrains) == 2
    export_scene = bpy.data.scenes.new('T06_Export_Only')
    bpy.context.window.scene = export_scene
    DEST.mkdir(parents=True, exist_ok=True)
    materials = {}

    def material(source):
        # Blender's procedural Botaniq shaders are not glTF shaders. Use the
        # authored solid-preview colours; do not bake/render or alter the source.
        if source.name not in materials:
            mat = bpy.data.materials.new('OD_' + source.name)
            mat.diffuse_color = source.diffuse_color
            mat.use_nodes = True
            shader = mat.node_tree.nodes.get('Principled BSDF')
            shader.inputs['Base Color'].default_value = source.diffuse_color
            shader.inputs['Roughness'].default_value = 0.9
            materials[source.name] = mat
        return materials[source.name]

    def export(name, objects):
        for obj in list(export_scene.objects):
            export_scene.collection.objects.unlink(obj)
        for obj in objects:
            export_scene.collection.objects.link(obj)
        bpy.context.view_layer.update()
        bpy.ops.export_scene.gltf(filepath=str(DEST / (name + '.glb')),
            export_format='GLB', use_active_scene=True, export_yup=True,
            export_animations=False, export_cameras=False, export_lights=False,
            export_extras=False, export_apply=True)

    prototypes = []
    species = []
    for index, name in enumerate(sorted(originals)):
        source = originals[name]
        kind = 'tree' if 'Tree_' in name else ('rock' if 'Rock_' in name else 'ground')
        species.append({'name': name, 'id': index, 'kind': kind})
        for lod, budget in [('Near', 6000 if kind == 'tree' else 1800), ('Far', 900 if kind == 'tree' else 250)]:
            mesh = source.data.copy()
            mesh.materials.clear()
            for mat in source.data.materials:
                mesh.materials.append(material(mat))
            obj = bpy.data.objects.new('OD_%03d_%s' % (index, lod), mesh)
            export_scene.collection.objects.link(obj)
            if len(mesh.polygons) > budget:
                modifier = obj.modifiers.new('RuntimeBudget', 'DECIMATE')
                modifier.ratio = budget / len(mesh.polygons)
            prototypes.append(obj)
    export('vegetation', prototypes)
    chunks = defaultdict(list)
    bounds = [float('inf'), float('inf'), -float('inf'), -float('inf')]
    for source in terrains:
        vertices = [translate @ source.matrix_world @ v.co for v in source.data.vertices]
        faces = defaultdict(list)
        for face in source.data.polygons:
            center = sum((vertices[i] for i in face.vertices), Vector()) / len(face.vertices)
            faces[(math.floor(center.x / 32), math.floor(-center.y / 32))].append(face)
        label = 'Ground' if source.name.startswith('Forest') else 'Meadow'
        for cell, polygons in sorted(faces.items()):
            indices = sorted({i for face in polygons for i in face.vertices})
            remap = {old: new for new, old in enumerate(indices)}
            mesh = bpy.data.meshes.new(label)
            mesh.from_pydata([vertices[i] for i in indices], [], [[remap[i] for i in p.vertices] for p in polygons])
            for mat in source.data.materials:
                mesh.materials.append(material(mat))
            for poly, original in zip(mesh.polygons, polygons):
                poly.material_index = original.material_index
                poly.use_smooth = True
            obj = bpy.data.objects.new('OD_' + label, mesh)
            chunks[cell].append(obj)
        if label == 'Ground':
            bounds = [min(v.x for v in vertices), min(-v.y for v in vertices), max(v.x for v in vertices), max(-v.y for v in vertices)]
    chunk_names = []
    for cell, objects in sorted(chunks.items()):
        name = 'region_%d_%d' % cell
        export(name, objects)
        chunk_names.append(name)
    lookup = {item['name']: item['id'] for item in species}
    instances = defaultdict(list)
    for name, transform in records:
        instances[str(lookup[name])].append(transform)
    for values in instances.values():
        values.sort()
    manifest = {'source_sha256': before, 'offset_blender': list(offset),
        'distribution': 'saved particle viewport preview', 'cell_size': 32,
        'bounds_xz': bounds, 'chunks': chunk_names, 'species': species,
        'instances': dict(sorted(instances.items())), 'instance_count': len(records),
        'files_sha256': {p.name: digest(p) for p in sorted(DEST.glob('*.glb'))}}
    (DEST / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n', encoding='utf-8')
    assert digest(SOURCE) == before, 'Source changed'
    print('T06_EXPORT_OK', len(chunks), 'regions;', len(species), 'species;', len(records), 'instances')


if __name__ == '__main__':
    main()
