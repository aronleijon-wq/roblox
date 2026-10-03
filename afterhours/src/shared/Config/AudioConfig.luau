-- AudioConfig: alla ljud i spelet. Ljud är ett spelsystem här: man ska ibland höra något
-- innan man ser det, och ibland ska tystnaden vara det läskiga.
--
-- Ljudfilerna ligger i afterhours/assets/audio/. Roblox kräver att ljud laddas upp till ditt
-- konto: ladda upp filerna i Creator Hub (Creations -> Audio) eller Studio (Asset Manager)
-- och klistra in deras id nedan, t.ex. id = "rbxassetid://1234567890".
-- Ett tomt id betyder att ljudet hoppas över; spelet fungerar ändå (allt viktigt visas också).

local AudioConfig = {}

AudioConfig.Sounds = {
	-- Bakgrund (loopar)
	CityAmbience = { id = "", file = "city_ambience.ogg", volume = 0.35, looped = true },
	ElectricalHum = { id = "", file = "electrical_hum.ogg", volume = 0.5, looped = true, rollOff = 40 },
	StationDrone = { id = "", file = "station_drone.ogg", volume = 0.5, looped = true, rollOff = 60 },
	-- Händelser
	RadioBlip = { id = "", file = "radio_blip.ogg", volume = 0.6 },
	PowerDown = { id = "", file = "power_down.ogg", volume = 0.8 },
	PowerUp = { id = "", file = "power_up.ogg", volume = 0.7 },
	Alarm = { id = "", file = "alarm.ogg", volume = 0.6, looped = true, rollOff = 90 },
	ShiftSiren = { id = "", file = "shift_siren.ogg", volume = 0.7 },
	Knock = { id = "", file = "knock.ogg", volume = 0.9, rollOff = 70 },
	Static = { id = "", file = "static.ogg", volume = 0.5, looped = true },
	Secure = { id = "", file = "secure.ogg", volume = 0.6 },
	Pickup = { id = "", file = "pickup.ogg", volume = 0.5 },
	Rare = { id = "", file = "rare.ogg", volume = 0.7 },
	KeypadOk = { id = "", file = "keypad_ok.ogg", volume = 0.6 },
	KeypadNo = { id = "", file = "keypad_no.ogg", volume = 0.6 },
}

return AudioConfig
