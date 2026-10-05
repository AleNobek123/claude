# Bee Tycoon: Honey Empire

Symulator pszczelarski na Roblox (w stylu Bee Swarm Simulator): zbieranie pyłku, ul na siatce
heksagonalnej z synergiami, mutacje, jajka z pity, eventy co 15 minut, holograficzne leaderboardy
i monetyzacja (Developer Products + Gamepassy).

## Struktura (Rojo)

```
default.project.json        mapowanie folderów na usługi Roblox
src/shared   -> ReplicatedStorage.Shared       Config, BeeData, BeeClass, Synergy, HexGrid, BeeCodec, Net, Format, Signal
src/server   -> ServerScriptService.Server     Main + Services/* (12 serwisów) + Util/Notify
src/client   -> StarterPlayerScripts.Client    ClientMain + Controllers/* (UI, renderery, sterowanie)
tools/BuildMap.luau          buduje Workspace.Map i zastępcze modele (uruchamiany w trybie edycji)
tools/IntegrateAssets.luau   zamienia model zaimportowany z Blendera na szablony w ReplicatedStorage.Assets
tools/gen_manifest.py        generuje sync-manifest.json (lista plików do synchronizacji ze Studio)
```

Wszystkie liczby balansu są w `src/shared/Config.luau`.

## Praca z Rojo (opcjonalnie)

```
rojo serve
```
i połącz wtyczkę Rojo w Studio. Mapa i modele 3D nie są w repozytorium: buduje je `tools/BuildMap.luau`.

## Modele 3D

Modele powstały w Blenderze 5.2 (`Documents/BeeTycoon/Models/BeeTycoon_Models.blend`) i są wyeksportowane do
`BeeTycoon_Assets.fbx`. Import: Studio → File → Import 3D, potem uruchomienie `tools/IntegrateAssets.luau`
i ponowne `tools/BuildMap.luau`.

## Przed publikacją

1. Opublikuj place i włącz Game Settings → Security → Enable Studio Access to API Services (DataStore).
2. Utwórz produkty i gamepassy w Creator Dashboard i wpisz ich ID w `Config.Products` / `Config.Gamepasses`.
3. Ustaw maksymalną liczbę graczy na 8 (tyle jest uli).
