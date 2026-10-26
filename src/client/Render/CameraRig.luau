--!strict
-- Side-on camera that keeps both fighters in view. Reads simulation state only.
-- Looks along -Z so screen right is world +X, matching the simulation's fight axis.

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
	local midX = (p1.x + p2.x) / 2 / Constants.UNITS_PER_STUD
	local midZ = (p1.z + p2.z) / 2 / Constants.UNITS_PER_STUD
	local separation = math.abs(p1.x - p2.x) / Constants.UNITS_PER_STUD
	local distance = math.max(MIN_DISTANCE, separation * DISTANCE_PER_SEPARATION + MIN_DISTANCE / 2)

	local target = Vector3.new(midX, LOOK_HEIGHT, midZ)
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0, EYE_RAISE, distance), target)
end

return {
	update = update,
}
