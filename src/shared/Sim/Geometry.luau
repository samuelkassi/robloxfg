--!strict
-- Whole-unit movement on the x/z ground plane. Uses only + - * / and math.sqrt, which IEEE 754 rounds
-- identically on every machine (no trig), and rounds every result back to whole units.

local Types = require(script.Parent.Types)

type FighterState = Types.FighterState

local function round(value: number): number
	return math.floor(value + 0.5)
end

local function length(dx: number, dz: number): number
	return math.sqrt(dx * dx + dz * dz)
end

-- Moves the fighter `distance` units toward (centerX, centerZ); a negative distance moves away.
local function moveToward(fighter: FighterState, centerX: number, centerZ: number, distance: number)
	local dx, dz = centerX - fighter.x, centerZ - fighter.z
	local len = length(dx, dz)
	if len == 0 then
		return
	end
	fighter.x += round(dx * distance / len)
	fighter.z += round(dz * distance / len)
end

-- Steps the fighter `distance` units along the unit direction (dirX, dirZ), then restores its distance to
-- (centerX, centerZ), so repeated steps trace an arc around that point.
local function circle(
	fighter: FighterState,
	centerX: number,
	centerZ: number,
	dirX: number,
	dirZ: number,
	distance: number
)
	local radius = length(fighter.x - centerX, fighter.z - centerZ)
	local offsetX = fighter.x + dirX * distance - centerX
	local offsetZ = fighter.z + dirZ * distance - centerZ
	local len = length(offsetX, offsetZ)
	if len == 0 then
		return
	end
	fighter.x = round(centerX + offsetX * radius / len)
	fighter.z = round(centerZ + offsetZ * radius / len)
end

return {
	round = round,
	length = length,
	moveToward = moveToward,
	circle = circle,
}
