--[[
	Sound
	Background music playlist (crossfaded) and pooled sound effects, with Music/SFX toggles
	driven by the player's saved settings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)

local Sound = {}

local C
local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local pools = {} -- [name] = { Sound }
local musicOn = true
local sfxOn = true
local current: Sound? = nil
local trackIndex = 0

local MUSIC_VOLUME = 0.32

local function group(name: string, volume: number)
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	g.Volume = volume
	return g
end

function Sound:Play(name: string, opts)
	if not sfxOn then
		return
	end
	local def = Assets.Sounds[name]
	if not def then
		return
	end
	opts = opts or {}
	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	local sound
	for _, s in pool do
		if not s.IsPlaying then
			sound = s
			break
		end
	end
	if not sound then
		if #pool >= 6 then
			sound = pool[1]
		else
			sound = Instance.new("Sound")
			sound.SoundId = def.Id
			sound.SoundGroup = sfxGroup
			sound.Parent = SoundService
			table.insert(pool, sound)
		end
	end
	sound.Volume = (opts.Volume or 1) * def.Volume
	sound.PlaybackSpeed = opts.Pitch or (1 + (math.random() - 0.5) * (opts.Vary or 0.08))
	if opts.At then
		-- positional: borrow an attachment in the world
		local att = Instance.new("Attachment")
		att.WorldPosition = opts.At
		att.Parent = Workspace.Terrain
		local positional = sound:Clone()
		positional.RollOffMaxDistance = 120
		positional.Parent = att
		positional:Play()
		positional.Ended:Once(function()
			att:Destroy()
		end)
		task.delay(6, function()
			if att.Parent then
				att:Destroy()
			end
		end)
		return
	end
	sound.TimePosition = 0
	sound:Play()
end

function Sound:_nextTrack()
	trackIndex = trackIndex % #Assets.Music + 1
	local nextSound = Instance.new("Sound")
	nextSound.SoundId = Assets.Music[trackIndex]
	nextSound.Volume = 0
	nextSound.SoundGroup = musicGroup
	nextSound.Parent = SoundService
	nextSound:Play()
	TweenService:Create(nextSound, TweenInfo.new(2.5), { Volume = 1 }):Play()
	local old = current
	if old then
		local fade = TweenService:Create(old, TweenInfo.new(2.5), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			old:Destroy()
		end)
	end
	current = nextSound
	nextSound.Ended:Once(function()
		if current == nextSound then
			self:_nextTrack()
		end
	end)
	-- tracks that fail to load are skipped
	task.delay(8, function()
		if current == nextSound and not nextSound.IsLoaded then
			self:_nextTrack()
		end
	end)
end

function Sound:SetMusic(on: boolean)
	musicOn = on
	TweenService:Create(musicGroup, TweenInfo.new(0.6), { Volume = on and MUSIC_VOLUME or 0 }):Play()
end

function Sound:SetSfx(on: boolean)
	sfxOn = on
end

function Sound:Init(controllers)
	C = controllers
	musicGroup = group("Music", MUSIC_VOLUME)
	sfxGroup = group("SFX", 0.9)
	C.UI.Juice.Sound = function(name)
		self:Play(name)
	end
end

function Sound:Start()
	trackIndex = math.random(0, #Assets.Music - 1)
	self:_nextTrack()
	C.State:OnChange({ "Settings" }, function(data)
		local settings = data.Settings or {}
		if settings.Music ~= nil and settings.Music ~= musicOn then
			self:SetMusic(settings.Music)
		end
		if settings.Sfx ~= nil then
			self:SetSfx(settings.Sfx)
		end
	end)
end

return Sound
