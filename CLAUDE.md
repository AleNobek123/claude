# Bee Tycoon: Honey Empire – notes for Claude

- Roblox bee simulator, published. Owner writes in Polish and wants short replies; in-game UI is 100% English.
- Focus on this game only (the pencil simulator is on hold).
- Rojo layout (`default.project.json`): `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client.
- `tools/*.luau` are edit-time Studio tools (BuildMap, IntegrateV6, FixDecor…), run from the Command Bar, not shipped.
- New 3D models: make them in Blender (Blender MCP), export FBX with `axis_forward='-Z', axis_up='Y'`, owner imports via File → Import 3D, then an Integrate tool turns meshes into `ReplicatedStorage.Assets` templates.
- Before committing: compile changed files with `luau-compile --binary` (and `luau-analyze` for globals), run `python3 tools/gen_manifest.py` (keeps `sync-manifest.json` current for the HTTP sync snippet).
- Waiting on the owner: `Config.GroupId` (no group yet) and `Config.AdReward.ProductId` (rewarded ads not eligible yet) stay 0.
- Feedback/bug reports are stored in the DataStore `BeeTycoon_Feedback_v1` (Creator Hub → Data Stores Manager).
