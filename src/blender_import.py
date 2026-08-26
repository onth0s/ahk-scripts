"""Import a .glb or .obj file passed on the command line, then frame the view.

Invoked by L1__B_04 via Blender's --python flag. Blender's -- separator
passes everything after it to sys.argv verbatim, so argv[0] is the script,
argv[1] may be the literal "--" (skipped), and argv[2] is the file path.
"""
import sys

import bpy


def main() -> int:
    args = sys.argv[1:]
    if args and args[0] == "--":
        args = args[1:]
    if not args:
        print("usage: blender_import.py <path>")
        return 1

    path = args[0]
    if path.lower().endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        bpy.ops.wm.obj_import(filepath=path)

    bpy.ops.view3d.view_all()
    return 0


if __name__ == "__main__":
    sys.exit(main())
