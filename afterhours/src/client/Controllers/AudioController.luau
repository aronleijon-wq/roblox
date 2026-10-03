-- AudioController: spelar ljuden i AudioConfig. Ljud utan id hoppas över tyst.
--   * Stadens bakgrundsljud loopar; under SILENT CITY tystnar allt (det är poängen).
--   * Delar taggade AH_AmbientSound med attributet "Sound" får ett loopande 3D-ljud.
--   * Händelseljud: strömavbrott, sirenen vid 02:30, larm på plats, knackningar.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Constants = require(ReplicatedStorage.Shared.Constants)

local AudioController = {}

local app
local folder: Folder
local loops: { [string]: Sound } = {}
local ambient: { [Instance]: Sound } = {}

local function make(name: string, parent: Instance): Sound?
	local def = AudioConfig.Sounds[name]
	if not def or def.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume or 0.5
	sound.Looped = def.looped == true
	if def.rollOff then
		sound.RollOffMaxDistance = def.rollOff
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
	end
	sound.Parent = parent
	return sound
end

-- Spelar ett ljud en gång, platt (2D) eller på en plats i världen.
function AudioController.play(name: string, position: Vector3?)
	if position then
		local holder = Instance.new("Part")
		holder.Name = "SoundAt"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = folder
		local sound = make(name, holder)
		if not sound then
			holder:Destroy()
			return
		end
		sound:Play()
		task.delay(if sound.Looped then 12 else 8, function()
			holder:Destroy()
		end)
		return
	end
	local sound = make(name, folder)
	if sound then
		sound.Looped = false
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

-- Startar/stoppar en namngiven loop (t.ex. larmet för en viss incident).
function AudioController.loop(key: string, name: string?, position: Vector3?)
	if loops[key] then
		local old = loops[key]
		loops[key] = nil
		local holder = old.Parent
		old:Destroy()
		if holder and holder:IsA("BasePart") and holder.Name == "LoopAt" then
			holder:Destroy()
		end
	end
	if not name then
		return
	end
	local parent: Instance = folder
	if position then
		local holder = Instance.new("Part")
		holder.Name = "LoopAt"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = folder
		parent = holder
	end
	local sound = make(name, parent)
	if sound then
		sound.Looped = true
		sound:Play()
		loops[key] = sound
	elseif position then
		parent:Destroy()
	end
end

local function silent(): boolean
	return ReplicatedStorage:GetAttribute("Silent") == true
end

local function updateAmbience()
	local quiet = silent()
	SoundService.AmbientReverb = if quiet then Enum.ReverbType.Hallway else Enum.ReverbType.City
	for _, sound in folder:GetDescendants() do
		if sound:IsA("Sound") and sound.Looped then
			local def = AudioConfig.Sounds[sound.Name]
			sound.Volume = if quiet then 0 else (def and def.volume or 0.5)
		end
	end
	for part, sound in ambient do
		local def = AudioConfig.Sounds[sound.Name]
		local powered = not ReplicatedStorage:GetAttribute("PowerOut") or part:GetAttribute("NeedsPower") == false
		sound.Volume = if quiet or not powered then 0 else (def and def.volume or 0.5)
	end
end

local function addAmbient(part: Instance)
	local name = part:GetAttribute("Sound")
	if type(name) ~= "string" or ambient[part] then
		return
	end
	local sound = make(name, part)
	if sound then
		sound.Looped = true
		sound:Play()
		ambient[part] = sound
		updateAmbience()
	end
end

local function onWorldEvent(event)
	if event.type == "IncidentStart" then
		if event.id == "FalseAlarm" and event.data and event.data.position then
			AudioController.loop("FalseAlarm", "Alarm", event.data.position)
		elseif event.id == "Blackout" or event.id == "CascadeFailure" then
			AudioController.play("PowerDown")
		end
	elseif event.type == "IncidentEnd" then
		if event.id == "FalseAlarm" then
			AudioController.loop("FalseAlarm", nil)
		elseif event.id == "Blackout" or event.id == "CascadeFailure" then
			AudioController.play("PowerUp")
		end
	elseif event.type == "Sound" and type(event.cue) == "string" then
		AudioController.play(event.cue, event.position)
	elseif event.type == "Keypad" then
		AudioController.play(if event.ok then "KeypadOk" else "KeypadNo")
	end
end

function AudioController.start(appRef)
	app = appRef
	folder = Instance.new("Folder")
	folder.Name = "AfterhoursAudio"
	folder.Parent = Workspace
	app.audio = AudioController

	AudioController.loop("City", "CityAmbience")

	for _, part in CollectionService:GetTagged(Constants.Tags.AmbientSound) do
		addAmbient(part)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.AmbientSound):Connect(addAmbient)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.AmbientSound):Connect(function(part)
		local sound = ambient[part]
		ambient[part] = nil
		if sound then
			sound:Destroy()
		end
	end)

	ReplicatedStorage:GetAttributeChangedSignal("Silent"):Connect(updateAmbience)
	ReplicatedStorage:GetAttributeChangedSignal("PowerOut"):Connect(updateAmbience)
	ReplicatedStorage:GetAttributeChangedSignal("CommsDown"):Connect(function()
		AudioController.loop("Static", if ReplicatedStorage:GetAttribute("CommsDown") then "Static" else nil)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(Constants.WorldAttributes.Phase):Connect(function()
		if ReplicatedStorage:GetAttribute(Constants.WorldAttributes.Phase) == Constants.Phases.Extraction then
			AudioController.play("ShiftSiren")
		end
	end)
	app.worldEvents:Connect(onWorldEvent)
	updateAmbience()
end

return AudioController
