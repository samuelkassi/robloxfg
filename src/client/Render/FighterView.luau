--!strict
-- Places one visual per fighter from simulation state. Reads state only; never writes it.
-- Uses ReplicatedStorage.FighterModels.Greybox if Studio provides one (pivot at the feet),
-- otherwise builds a plain grey box so a fresh rojo build still shows the fighters.
-- The grey box also shows crouching (shorter), an arm during a move's active frames, and a tint in
-- hitstun or blockstun.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Sim.Combat)
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
local ARM_THICKNESS = 0.5
local COLORS = { Color3.fromRGB(205, 205, 205), Color3.fromRGB(110, 110, 110) }
local HITSTUN_COLOR = Color3.fromRGB(225, 80, 80)
local BLOCKSTUN_COLOR = Color3.fromRGB(90, 140, 235)
local UNITS = Constants.UNITS_PER_STUD
-- How see-through fighters become while the hitbox view is on, so the hurtboxes inside show.
local GHOST_TRANSPARENCY = 0.75

type View = {
	model: Model,
	-- Set only for the fallback box.
	body: Part?,
	nose: Part?,
	arm: Part?,
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
	local arm = makePart("Arm", Vector3.one * ARM_THICKNESS, COLORS[index], model)
	arm.Transparency = 1
	model.PrimaryPart = body
	return { model = model, body = body, nose = nose, arm = arm }
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

-- Stretches the arm from the front of the body to the first hitbox while the move is active.
local function updateArm(arm: Part, root: CFrame, fighter: Types.FighterState, data: Types.FighterData)
	local move = Combat.currentMove(fighter, data)
	local active = if move then Combat.activeIndex(fighter, move) else 0
	if move == nil or active == 0 then
		arm.Transparency = 1
		return
	end
	local hitbox = move.hitboxes[active][1]
	local x, y, z = Combat.hitboxCenter(fighter, hitbox)
	local reach = Vector3.new(x, y, z) / UNITS
	local shoulder = (root * CFrame.new(0, hitbox.up / UNITS, -BODY_DEPTH / 2)).Position
	local length = (reach - shoulder).Magnitude
	if length < 0.01 then
		arm.Transparency = 1
		return
	end
	arm.Size = Vector3.new(ARM_THICKNESS, ARM_THICKNESS, length)
	arm.CFrame = CFrame.lookAt((shoulder + reach) / 2, reach)
	arm.Transparency = 0
end

-- `ghost` makes every fighter part see-through (client-side only), for the hitbox view.
local function update(state: Types.SimState, ghost: boolean)
	for i, view in views do
		local modifier = if ghost then GHOST_TRANSPARENCY else 0
		for _, part in view.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = modifier
			end
		end
		local fighter = state.fighters[i]
		local opponent = state.fighters[Constants.FIGHTER_COUNT + 1 - i]
		local position = Vector3.new(fighter.x, fighter.y, fighter.z) / UNITS
		-- Attacks face their attack direction (fixed for linear moves); otherwise face the opponent.
		local facing = if fighter.state == StateIds.ATTACK
			then Vector3.new(fighter.attackDirX, 0, fighter.attackDirZ)
			else Vector3.new(opponent.x / UNITS - position.X, 0, opponent.z / UNITS - position.Z)
		local root = if facing.Magnitude > 0 then CFrame.lookAt(position, position + facing) else CFrame.new(position)

		local body, nose, arm = view.body, view.nose, view.arm
		if body and nose and arm then
			local height = if fighter.state == StateIds.CROUCH then CROUCHING_HEIGHT else STANDING_HEIGHT
			body.Size = Vector3.new(BODY_WIDTH, height, BODY_DEPTH)
			body.CFrame = root * CFrame.new(0, height / 2, 0)
			body.Color = if fighter.state == StateIds.HITSTUN
				then HITSTUN_COLOR
				elseif fighter.state == StateIds.BLOCKSTUN then BLOCKSTUN_COLOR
				else COLORS[i]
			nose.CFrame = root * CFrame.new(0, height * 0.8, -(BODY_DEPTH + NOSE_SIZE.Z) / 2)
			updateArm(arm, root, fighter, state.roster[i])
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
