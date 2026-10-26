--!strict
-- Fighter state machine. States are numbers so they can be hashed; per-fighter values come from FighterData.

local Input = require(script.Parent.Input)
local Types = require(script.Parent.Types)

type FighterData = Types.FighterData
type FighterState = Types.FighterState
type InputMask = Types.InputMask

local IDLE = 1
local WALK_FORWARD = 2
local WALK_BACK = 3

local function chooseState(numpad: number): number
	if numpad == 6 then
		return WALK_FORWARD
	elseif numpad == 4 then
		return WALK_BACK
	end
	return IDLE
end

-- Picks this frame's state from input, then applies its movement.
local function update(fighter: FighterState, data: FighterData, mask: InputMask)
	local nextState = chooseState(Input.toNumpad(mask, fighter.facingRight))
	if nextState == fighter.state then
		fighter.stateFrame += 1
	else
		fighter.state = nextState
		fighter.stateFrame = 0
	end

	local forward = if fighter.facingRight then 1 else -1
	if fighter.state == WALK_FORWARD then
		fighter.x += forward * data.walkForwardSpeed
	elseif fighter.state == WALK_BACK then
		fighter.x -= forward * data.walkBackSpeed
	end
end

return {
	IDLE = IDLE,
	WALK_FORWARD = WALK_FORWARD,
	WALK_BACK = WALK_BACK,
	update = update,
}
