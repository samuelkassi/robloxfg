--!strict
-- Places one visual per fighter from simulation state. Reads state only; never writes it.
-- Uses ReplicatedStorage.FighterModels.Greybox if Studio provides one (pivot at the feet),
-- otherwise builds a plain grey box so a fresh rojo build still shows the fighters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Sim.Constants)
local StateIds = require(ReplicatedStorage.Shared.Sim.StateIds)
local Types = require(ReplicatedStorage.Shared.Sim.Types)

local MODELS_FOLDER = "FighterModels"
local MODEL_NAME = "Greybox"
-- Fallback box only, in studs.
local BODY_WIDTH = 2
local BODY_DEPTH = 1.5
local STANDING_HEIGHT = 6
local CROUCHING_HEIGHT = 3.5
local NOSE_SIZE = Vector3.new(0.6, 0.6, 0.6)
local COLORS = { Color3.fromRGB(205, 205, 205), Color3.fromRGB(110, 110, 110) }

type View = {
	model: Model,
	-- Set only for the fallback box, which shows crouching by changing height.
	body: Part?,
	nose: Part?,
}

local folder: Folder? = nil
local views: { View } = {}

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function makeView(index: number): View
	local source = ReplicatedStorage:FindFirstChild(MODELS_FOLDER)
	local template = source and source:FindFirstChild(MODEL_NAME)
	if template and template:IsA("Model") then
		return { model = template:Clone() }
	end
	-- A grey box with a nose on its front face so facing is visible.
	local model = Instance.new("Model")
	local body = makePart("Body", Vector3.new(BODY_WIDTH, STANDING_HEIGHT, BODY_DEPTH), COLORS[index], model)
	local nose = makePart("Nose", NOSE_SIZE, Color3.fromRGB(40, 40, 40), model)
	model.PrimaryPart = body
	return { model = model, body = body, nose = nose }
end

local function start(state: Types.SimState)
	if folder then
		return
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Fighters"
	for i = 1, Constants.FIGHTER_COUNT do
		local view = makeView(i)
		view.model.Name = `Fighter{state.fighters[i].id}`
		view.model.Parent = newFolder
		views[i] = view
	end
	newFolder.Parent = workspace
	folder = newFolder
end

local function update(state: Types.SimState)
	for i, view in views do
		local fighter = state.fighters[i]
		local opponent = state.fighters[Constants.FIGHTER_COUNT + 1 - i]
		local position = Vector3.new(fighter.x, fighter.y, fighter.z) / Constants.UNITS_PER_STUD
		local target =
			Vector3.new(opponent.x / Constants.UNITS_PER_STUD, position.Y, opponent.z / Constants.UNITS_PER_STUD)
		local root = if (target - position).Magnitude > 0 then CFrame.lookAt(position, target) else CFrame.new(position)

		local body, nose = view.body, view.nose
		if body and nose then
			local height = if fighter.state == StateIds.CROUCH then CROUCHING_HEIGHT else STANDING_HEIGHT
			body.Size = Vector3.new(BODY_WIDTH, height, BODY_DEPTH)
			body.CFrame = root * CFrame.new(0, height / 2, 0)
			nose.CFrame = root * CFrame.new(0, height * 0.8, -(BODY_DEPTH + NOSE_SIZE.Z) / 2)
		else
			view.model:PivotTo(root)
		end
	end
end

local function stop()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(views)
end

return {
	start = start,
	update = update,
	stop = stop,
}
