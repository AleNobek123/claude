--[[
	DayNight
	Deterministic day/night clock shared by server and clients (driven by server time, so it
	needs no replication). Day lasts DayRatio times longer than night.

	  Phase(now)        0..1 position in the cycle (0 = sunrise)
	  IsNight(now)      true during the night part
	  ClockTime(now)    Lighting.ClockTime: day maps 6:00 -> 18:00, night maps 18:00 -> 6:00
	  Sleeps(slot, now) true for the bees that go home to sleep at night (every other slot = 50%)
]]

local DayNight = {}

DayNight.Cycle = 840 -- seconds for a full day + night (14 minutes)
DayNight.DayRatio = 2.5 -- day lasts 2.5x as long as night
DayNight.SleepShare = 0.5 -- share of each swarm that sleeps at night

DayNight.DayLength = DayNight.Cycle * DayNight.DayRatio / (DayNight.DayRatio + 1) -- 600 s
DayNight.NightLength = DayNight.Cycle - DayNight.DayLength -- 240 s

function DayNight.Phase(now: number): number
	return (now % DayNight.Cycle) / DayNight.Cycle
end

function DayNight.IsNight(now: number): boolean
	return now % DayNight.Cycle >= DayNight.DayLength
end

-- seconds until the next sunrise / sunset
function DayNight.NextChange(now: number): number
	local t = now % DayNight.Cycle
	if t < DayNight.DayLength then
		return DayNight.DayLength - t
	end
	return DayNight.Cycle - t
end

function DayNight.ClockTime(now: number): number
	local t = now % DayNight.Cycle
	if t < DayNight.DayLength then
		return 6 + 12 * (t / DayNight.DayLength)
	end
	return (18 + 12 * ((t - DayNight.DayLength) / DayNight.NightLength)) % 24
end

-- 0 at midday, 1 at midnight, smooth in between (for lighting blends)
function DayNight.Darkness(now: number): number
	local clock = DayNight.ClockTime(now)
	local fromNoon = math.abs(clock - 12) -- 0 at noon, 12 at midnight
	return math.clamp((fromNoon - 4.5) / 3, 0, 1)
end

function DayNight.Sleeps(slot: number, now: number): boolean
	if not DayNight.IsNight(now) then
		return false
	end
	-- every other slot, so exactly half of a full hive sleeps
	return slot % math.max(1, math.floor(1 / DayNight.SleepShare + 0.5)) == 0
end

return DayNight
