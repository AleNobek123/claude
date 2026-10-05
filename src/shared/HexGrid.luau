--[[
	HexGrid
	Axial-coordinate hex grid for the hive. Slot 1 is the centre; slots spiral outwards
	ring by ring, so unlocking slots in order always grows the hive evenly.
	Layout is "pointy-top": x = size * sqrt(3) * (q + r/2), y = size * 1.5 * r.
]]

local HexGrid = {}

HexGrid.Directions = {
	Vector2.new(1, 0),
	Vector2.new(1, -1),
	Vector2.new(0, -1),
	Vector2.new(-1, 0),
	Vector2.new(-1, 1),
	Vector2.new(0, 1),
}

local cache = {}

local function key(q: number, r: number): string
	return q .. "," .. r
end

-- Returns { slots = { [i] = Vector2(q, r) }, lookup = { ["q,r"] = i }, neighbors = { [i] = {j,...} } }
function HexGrid.Get(radius: number)
	if cache[radius] then
		return cache[radius]
	end

	local slots = { Vector2.new(0, 0) }
	for ring = 1, radius do
		local hex = HexGrid.Directions[5] * ring
		for side = 1, 6 do
			for _ = 1, ring do
				table.insert(slots, hex)
				hex += HexGrid.Directions[side]
			end
		end
	end

	local lookup = {}
	for i, hex in slots do
		lookup[key(hex.X, hex.Y)] = i
	end

	local neighbors = {}
	for i, hex in slots do
		local list = {}
		for _, dir in HexGrid.Directions do
			local n = hex + dir
			local j = lookup[key(n.X, n.Y)]
			if j then
				table.insert(list, j)
			end
		end
		neighbors[i] = list
	end

	local grid = { slots = slots, lookup = lookup, neighbors = neighbors, count = #slots }
	cache[radius] = grid
	return grid
end

-- 2D offset of a slot from the hive centre, in studs (x right, y up)
function HexGrid.ToOffset(radius: number, slot: number, size: number): Vector2
	local hex = HexGrid.Get(radius).slots[slot]
	local x = size * math.sqrt(3) * (hex.X + hex.Y / 2)
	local y = size * 1.5 * hex.Y
	return Vector2.new(x, -y)
end

function HexGrid.Neighbors(radius: number, slot: number): { number }
	return HexGrid.Get(radius).neighbors[slot] or {}
end

return HexGrid
