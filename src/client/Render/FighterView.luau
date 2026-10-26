--!strict
-- Places one visual per fighter from simulation state. Reads state only; never writes it.
-- Uses ReplicatedStorage.FighterModels.Greybox if Studio provides one (pivot at the feet),
-- otherwise builds a plain grey box so a fresh rojo build still shows the fighters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Sim.Constants)
local Types = require(ReplicatedStorage.Shared.Sim.Types)

local MODELS_FOLDER = "FighterModels"
local MODEL_NAME = "Greybox"
local BODY_SIZE = Vector3.new(2, 6, 1.5) -- studs, fallback box only
local NOSE_SIZE = Vector3.new(0.6, 0.6, 0.6)
local COLORS = { Color3.fromRGB(205, 205, 205), Color3.fromRGB(110, 110, 110) }

local folder: Folder? = nil
local models: { Model } = {}

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

-- A grey box with a nose on its front face so facing is visible.
local function buildFallback(color: Color3): Model
	local model = Instance.new("Model")
	local body = makePart("Body", BODY_SIZE, color, model)
	local nose = makePart("Nose", NOSE_SIZE, Color3.fromRGB(40, 40, 40), model)
	body.CFrame = CFrame.new(0, BODY_SIZE.Y / 2, 0)
	nose.CFrame = CFrame.new(0, BODY_SIZE.Y * 0.8, -(BODY_SIZE.Z + NOSE_SIZE.Z) / 2)
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

local function makeModel(index: number): Model
	local source = ReplicatedStorage:FindFirstChild(MODELS_FOLDER)
	local template = source and source:FindFirstChild(MODEL_NAME)
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return buildFallback(COLORS[index])
end

local function start(state: Types.SimState)
	if folder then
		return
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Fighters"
	for i = 1, Constants.FIGHTER_COUNT do
		local model = makeModel(i)
		model.Name = `Fighter{state.fighters[i].id}`
		model.Parent = newFolder
		models[i] = model
	end
	newFolder.Parent = workspace
	folder = newFolder
end

local function update(state: Types.SimState)
	for i, model in models do
		local fighter = state.fighters[i]
		local position = Vector3.new(fighter.x, 0, fighter.z) / Constants.UNITS_PER_STUD
		local facing = Vector3.new(if fighter.facingRight then 1 else -1, 0, 0)
		model:PivotTo(CFrame.lookAt(position, position + facing))
	end
end

local function stop()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(models)
end

return {
	start = start,
	update = update,
	stop = stop,
}
