"""Import a .glb, .gltf, or .obj file passed on the command line into Blender.

Invoked via Blender's --python flag.
"""
import sys
import bpy


def main() -> int:
    try:
        idx = sys.argv.index("--")
        args = sys.argv[idx + 1:]
    except ValueError:
        args = sys.argv[1:]

    if not args:
        print("usage: blender_import.py <path>")
        return 1

    path = args[0]

    # Import file using native operators into the user's startup scene
    lower = path.lower()
    if lower.endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    elif lower.endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        print(f"Unsupported format: {path}")
        return 1

    return 0


if __name__ == "__main__":
    main()


