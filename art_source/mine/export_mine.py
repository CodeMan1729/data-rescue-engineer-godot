"""Export existing mine scenes only. Never generate or save source geometry."""
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'Data_Rescue_Mine.blend'
DEST = HERE.parents[1] / 'assets' / 'mine'
if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
DEST.mkdir(parents=True, exist_ok=True)
original_scene = bpy.context.window.scene
try:
    for name in ('mine_site', 'mine_vista'):
        scene = bpy.data.scenes.get(name)
        if scene is None:
            raise RuntimeError('Missing source scene: ' + name)
        bpy.context.window.scene = scene
        bpy.ops.export_scene.gltf(
            filepath=str(DEST / (name + '.glb')),
            export_format='GLB', use_active_scene=True,
            export_yup=True, export_extras=True,
            export_cameras=False, export_lights=False,
            export_animations=False, export_apply=True,
        )
finally:
    bpy.context.window.scene = original_scene
print('T13A_EXPORT_OK')
