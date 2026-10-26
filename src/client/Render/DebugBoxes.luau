--!strict
-- See-through view of every hurtbox and active hitbox, toggled with F2. Reads simulation state only.
-- The start of training mode's hitbox view. Hurtboxes sit inside the bodies, so while it is on, FighterView
-- ghosts the fighters (see isEnabled).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Combat = require(ReplicatedStorage.Shared.Sim.Combat)
local Constants = require(ReplicatedStorage.Shared.Sim.Constants)
local Types = require(ReplicatedStorage.Shared.Sim.Types)

local TOGGLE_KEY = Enum.KeyCode.F2
local TRANSPARENCY = 0.5
local HURTBOX_COLOR = Color3.fromRGB(60, 140, 255)
local HITBOX_COLOR = Color3.fromRGB(255, 50, 50)
local MAX_HITBOXES = 4 -- per fighter per frame
local UNITS = Constants.UNITS_PER_STUD

type Boxes = {
	hurtBody: CylinderHandleAdornment,
	hurtTop: SphereHandleAdornment,
	hurtBottom: SphereHandleAdornment,
	hits: { SphereHandleAdornment },
}

local folder: Folder? = nil
local boxes: { Boxes } = {}
local enabled = false
local toggleConnection: RBXScriptConnection? = nil

local function configure(adornment: HandleAdornment, color: Color3, anchor: BasePart, parent: Instance)
	adornment.Color3 = color
	adornment.Transparency = TRANSPARENCY
	adornment.Visible = false
	adornment.Adornee = anchor
	adornment.Parent = parent
end

local function sphere(color: Color3, anchor: BasePart, parent: Instance): SphereHandleAdornment
	local adornment = Instance.new("SphereHandleAdornment")
	configure(adornment, color, anchor, parent)
	return adornment
end

local function cylinder(color: Color3, anchor: BasePart, parent: Instance): CylinderHandleAdornment
	local adornment = Instance.new("CylinderHandleAdornment")
	configure(adornment, color, anchor, parent)
	return adornment
end

local function placeCap(cap: SphereHandleAdornment, radius: number, x: number, y: number, z: number)
	cap.Radius = radius
	cap.CFrame = CFrame.new(x, y, z)
	cap.Visible = enabled
end

local function start()
	if folder then
		return
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "DebugBoxes"
	-- Adornments are positioned relative to this invisible part at the world origin.
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.CFrame = CFrame.new()
	anchor.Parent = newFolder

	for i = 1, Constants.FIGHTER_COUNT do
		local hits = {}
		for n = 1, MAX_HITBOXES do
			hits[n] = sphere(HITBOX_COLOR, anchor, newFolder)
		end
		boxes[i] = {
			hurtBody = cylinder(HURTBOX_COLOR, anchor, newFolder),
			hurtTop = sphere(HURTBOX_COLOR, anchor, newFolder),
			hurtBottom = sphere(HURTBOX_COLOR, anchor, newFolder),
			hits = hits,
		}
	end
	newFolder.Parent = workspace
	folder = newFolder
	toggleConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			enabled = not enabled
		end
	end)
end

local function update(state: Types.SimState)
	for i, fighterBoxes in boxes do
		local fighter = state.fighters[i]
		local data = state.roster[i]
		local x, z = fighter.x / UNITS, fighter.z / UNITS

		-- Hurtbox capsule: a cylinder between the segment ends, capped with spheres.
		local hurtbox = Combat.hurtboxOf(fighter, data)
		local radius = hurtbox.radius / UNITS
		local bottom = (fighter.y + hurtbox.bottom) / UNITS
		local top = (fighter.y + hurtbox.top) / UNITS
		local body = fighterBoxes.hurtBody
		body.Radius = radius
		body.Height = top - bottom
		-- Cylinder adornments extend along their look direction; tip it upright.
		body.CFrame = CFrame.new(x, (bottom + top) / 2, z) * CFrame.Angles(math.pi / 2, 0, 0)
		body.Visible = enabled
		placeCap(fighterBoxes.hurtTop, radius, x, top, z)
		placeCap(fighterBoxes.hurtBottom, radius, x, bottom, z)

		-- Hitboxes for this frame, if a move is active.
		local move = Combat.currentMove(fighter, data)
		local active = if move then Combat.activeIndex(fighter, move) else 0
		local list = if move and active > 0 then move.hitboxes[active] else nil
		for n, hitSphere in fighterBoxes.hits do
			local hitbox = list and list[n]
			if enabled and hitbox then
				local hx, hy, hz = Combat.hitboxCenter(fighter, hitbox)
				hitSphere.Radius = hitbox.radius / UNITS
				hitSphere.CFrame = CFrame.new(hx / UNITS, hy / UNITS, hz / UNITS)
				hitSphere.Visible = true
			else
				hitSphere.Visible = false
			end
		end
	end
end

local function isEnabled(): boolean
	return enabled
end

local function stop()
	if toggleConnection then
		toggleConnection:Disconnect()
		toggleConnection = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(boxes)
end

return {
	start = start,
	update = update,
	isEnabled = isEnabled,
	stop = stop,
}
