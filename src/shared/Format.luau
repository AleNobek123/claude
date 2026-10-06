--[[
	Format
	Number and time formatting for the UI.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

function Format.Short(n: number): string
	n = n or 0
	if math.abs(n) < 1000 then
		return tostring(math.floor(n + 0.5))
	end
	local tier = math.min(math.floor(math.log10(math.abs(n)) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	-- trim zeros only after a decimal point ("1.40" -> "1.4", but "110" stays "110")
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return text .. SUFFIXES[tier + 1]
end

function Format.Commas(n: number): string
	local s = tostring(math.floor(n or 0))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- "4:05" under an hour, "01:10:00" from one hour up
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Format.Percent(p: number): string
	if p == 0 then
		return "0%"
	elseif p < 1 then
		return string.format("%.1f%%", p)
	end
	return (string.format("%.1f", p):gsub("%.0$", "")) .. "%"
end

return Format
