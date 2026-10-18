# Blender project editing

- The user designated `Data_Rescue_Forest_Station.blend` in this directory as the single master source. It contains the complete Botaniq forest and the approved station.
- Edit this existing file in place for future requests. Do not create alternate scene versions or rebuild the approved house unless requested.
- Preserve the removed blue bed state, transparent windows, and the original forest. Default viewport shading must remain SOLID for performance.
- `mountain_station/build_station.py` and `botaniq_forest/enrich_mountain_forest.py` are historical generation scripts, not the current source of truth. Do not run them to apply incremental edits.
- `mountain_station/export_current_station.py` exports the current master station to the existing Godot GLB without rebuilding. It intentionally excludes the forest.
- The user prefers reviewing visuals themselves; do not add visual review/render loops unless requested. Check execution and requested output data only.
