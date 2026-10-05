#!/usr/bin/env python3
"""Builds sync-manifest.json: maps every Luau file in src/ to its Studio path and class.

Mirrors the Rojo rules used by default.project.json:
  *.server.luau -> Script, *.client.luau -> LocalScript, *.luau -> ModuleScript.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOUNTS = {
    "src/shared": ["ReplicatedStorage", "Shared"],
    "src/server": ["ServerScriptService", "Server"],
    "src/client": ["StarterPlayer", "StarterPlayerScripts", "Client"],
}

files = []
for mount, base in MOUNTS.items():
    for path in sorted((ROOT / mount).rglob("*.luau")):
        rel = path.relative_to(ROOT / mount)
        name = path.name
        if name.endswith(".server.luau"):
            cls, stem = "Script", name[: -len(".server.luau")]
        elif name.endswith(".client.luau"):
            cls, stem = "LocalScript", name[: -len(".client.luau")]
        else:
            cls, stem = "ModuleScript", name[: -len(".luau")]
        files.append({
            "path": base + list(rel.parent.parts) + [stem],
            "class": cls,
            "file": str(path.relative_to(ROOT)).replace("\\", "/"),
        })

(ROOT / "sync-manifest.json").write_text(json.dumps({"files": files}, indent=1) + "\n")
print(f"{len(files)} files in manifest")
