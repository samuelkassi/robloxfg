--!strict
-- Side-on camera that keeps both fighters in view. Reads simulation state only.
-- It sits on the perpendicular of the fight axis (screen-left fighter to screen-right fighter), so it rotates
-- as the fighters circle; looking along (axisZ, -axisX) keeps the screen-left fighter on the left.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Sim.Constants)
local Types = require(ReplicatedStorage.Shared.Sim.Types)

local LOOK_HEIGHT = 3.5 -- (start) studs above the floor the camera aims at
local EYE_RAISE = 1 -- (start) studs the camera sits above its aim point
local MIN_DISTANCE = 14 -- (start) studs from the fight axis
local DISTANCE_PER_SEPARATION = 0.7 -- (start) extra distance per stud between fighters

local function update(state: Types.SimState)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local p1, p2 = state.fighters[1], state.fighters[2]
	local left, right = p1, p2
	if not p1.facingRight then
		left, right = p2, p1
	end
	local axisX = (right.x - left.x) / Constants.UNITS_PER_STUD
	local axisZ = (right.z - left.z) / Constants.UNITS_PER_STUD
	local separation = math.sqrt(axisX * axisX + axisZ * axisZ)
	if separation == 0 then
		axisX, axisZ, separation = 1, 0, 1
	end
	-- Unit vector from the fight axis toward the camera.
	local towardCameraX, towardCameraZ = -axisZ / separation, axisX / separation

	local distance = math.max(MIN_DISTANCE, separation * DISTANCE_PER_SEPARATION + MIN_DISTANCE / 2)
	local midX = (p1.x + p2.x) / 2 / Constants.UNITS_PER_STUD
	local midZ = (p1.z + p2.z) / 2 / Constants.UNITS_PER_STUD
	local target = Vector3.new(midX, LOOK_HEIGHT, midZ)
	local eye = target + Vector3.new(towardCameraX * distance, EYE_RAISE, towardCameraZ * distance)
	camera.CFrame = CFrame.lookAt(eye, target)
end

return {
	update = update,
}
