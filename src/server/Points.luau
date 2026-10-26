--!strict
-- Awards a point when a player touches any part tagged "PointPart" and saves points to a DataStore.
-- This is out-of-match world logic, not combat, so Touched and os.clock() are fine here.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local POINT_TAG = "PointPart"
local TOUCH_COOLDOWN = 1 -- seconds before the same player can score again
local AUTOSAVE_INTERVAL = 60
local MAX_ATTEMPTS = 3

local store = DataStoreService:GetDataStore("PlayerPoints")

local pointValues: { [Player]: IntValue } = {}
local lastAwarded: { [Player]: number } = {}
local touchConnections: { [BasePart]: RBXScriptConnection } = {}
local savesInFlight = 0

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function withRetries(label: string, callback: () -> ()): boolean
	for attempt = 1, MAX_ATTEMPTS do
		local ok, err = pcall(callback)
		if ok then
			return true
		end
		warn(`{label} failed (attempt {attempt}/{MAX_ATTEMPTS}): {err}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(attempt * 2)
		end
	end
	return false
end

local function loadPlayer(player: Player)
	local saved = 0
	local ok = withRetries(`Load {player.Name}`, function()
		local value = store:GetAsync(keyFor(player))
		if typeof(value) == "number" then
			saved = value
		end
	end)

	if not player.Parent then
		return -- left while loading
	end
	if not ok then
		-- Without leaderstats the player can't score and we never save, so their stored points stay safe.
		warn(`Could not load points for {player.Name}; points are disabled this session`)
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = saved
	points.Parent = leaderstats

	leaderstats.Parent = player
	pointValues[player] = points
end

local function savePlayer(player: Player)
	local points = pointValues[player]
	if not points then
		return
	end

	local amount = points.Value
	savesInFlight += 1
	withRetries(`Save {player.Name}`, function()
		store:SetAsync(keyFor(player), amount, { player.UserId })
	end)
	savesInFlight -= 1
end

local function onPlayerRemoving(player: Player)
	savePlayer(player)
	pointValues[player] = nil
	lastAwarded[player] = nil
end

local function onTouched(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local points = pointValues[player]
	if not points then
		return
	end

	local now = os.clock()
	local last = lastAwarded[player]
	if last and now - last < TOUCH_COOLDOWN then
		return
	end
	lastAwarded[player] = now
	points.Value += 1
end

local function onTagAdded(instance: Instance)
	if not instance:IsA("BasePart") or touchConnections[instance] then
		return
	end
	touchConnections[instance] = instance.Touched:Connect(onTouched)
end

local function onTagRemoved(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local connection = touchConnections[instance]
	if connection then
		connection:Disconnect()
		touchConnections[instance] = nil
	end
end

local function start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	CollectionService:GetInstanceAddedSignal(POINT_TAG):Connect(onTagAdded)
	CollectionService:GetInstanceRemovedSignal(POINT_TAG):Connect(onTagRemoved)
	for _, instance in CollectionService:GetTagged(POINT_TAG) do
		onTagAdded(instance)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pointValues do
				task.spawn(savePlayer, player)
			end
		end
	end)

	game:BindToClose(function()
		for player in pointValues do
			task.spawn(savePlayer, player)
		end
		while savesInFlight > 0 do
			task.wait()
		end
	end)
end

return {
	start = start,
}
