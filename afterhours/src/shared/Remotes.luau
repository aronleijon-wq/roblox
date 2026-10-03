-- Remotes: skapar (server) eller hittar (klient) alla RemoteEvents och RemoteFunctions.
-- Namnen kommer från Constants.Remotes så att båda sidor alltid är överens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)

local Remotes = {}

local FOLDER_NAME = "AfterhoursRemotes"

function Remotes.get(): { [string]: any }
	local remotes = {}
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		for _, name in Constants.Remotes.Events do
			local remote = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
			remotes[name] = remote
		end
		for _, name in Constants.Remotes.Functions do
			local remote = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
			remotes[name] = remote
		end
	else
		local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		for _, name in Constants.Remotes.Events do
			remotes[name] = folder:WaitForChild(name)
		end
		for _, name in Constants.Remotes.Functions do
			remotes[name] = folder:WaitForChild(name)
		end
	end
	return remotes
end

return Remotes
