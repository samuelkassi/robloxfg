--!strict
-- Fighter movement state machine. Each frame it works out which state the input asks for, decides whether
-- the current state allows the switch (committed states only through their cancel windows), then moves.
-- Movement directions use the opponent's position from the start of the frame, so update order can't bias it.

local Geometry = require(script.Parent.Geometry)
local Input = require(script.Parent.Input)
local InputHistory = require(script.Parent.InputHistory)
local Intent = require(script.Parent.Intent)
local Motions = require(script.Parent.Motions)
local MotionParser = require(script.Parent.MotionParser)
local StateIds = require(script.Parent.StateIds)
local Types = require(script.Parent.Types)

type FighterData = Types.FighterData
type FighterState = Types.FighterState
type InputMask = Types.InputMask

-- Frames a committed state lasts, or nil for states that can change on any frame.
local function durationOf(state: number, data: FighterData): number?
	if state == StateIds.DASH then
		return data.dashFrames
	elseif state == StateIds.BACKDASH then
		return data.backdashFrames
	elseif state == StateIds.SIDESTEP_IN or state == StateIds.SIDESTEP_OUT then
		return data.sidestepFrames
	elseif state == StateIds.JUMP then
		return data.jumpFrames
	end
	return nil
end

-- The state this frame's input asks for, highest priority first.
local function requestedState(fighter: FighterState, frame: number, numpad: number, tapDir: number): number
	if MotionParser.dashTapped(fighter, frame, Motions.DASH_STEPS) then
		return StateIds.DASH
	elseif MotionParser.dashTapped(fighter, frame, Motions.BACKDASH_STEPS) then
		return StateIds.BACKDASH
	elseif tapDir == 8 then
		return StateIds.SIDESTEP_IN
	elseif tapDir == 2 then
		return StateIds.SIDESTEP_OUT
	end

	local heldDir, heldKind = fighter.heldDir, fighter.heldKind
	if heldKind == Intent.SIDEWALK then
		return if heldDir == 8 then StateIds.SIDEWALK_IN else StateIds.SIDEWALK_OUT
	elseif numpad == 7 or numpad == 9 or (heldDir == 8 and heldKind == Intent.HOLD) then
		return StateIds.JUMP
	elseif
		numpad == 1
		or numpad == 3
		or (heldDir == 2 and heldKind == Intent.HOLD)
		or (fighter.state == StateIds.CROUCH and numpad == 2)
	then
		return StateIds.CROUCH
	elseif numpad == 6 then
		return StateIds.WALK_FORWARD
	elseif numpad == 4 then
		return StateIds.WALK_BACK
	end
	return StateIds.IDLE
end

-- Returns the state to be in this frame and whether it is a fresh entry.
local function transition(fighter: FighterState, data: FighterData, requested: number): (number, boolean)
	local current = fighter.state
	local duration = durationOf(current, data)
	if duration == nil or fighter.stateFrame >= duration - 1 then
		-- Free to change; a finished committed state re-enters if asked for again (e.g. holding 9 jumps again).
		return requested, requested ~= current or duration ~= nil
	end
	-- The cancel replaces the frame the current state would play next.
	local cancel = data.cancels[current]
	if cancel and fighter.stateFrame + 1 >= cancel.fromFrame and table.find(cancel.into, requested) then
		return requested, true
	end
	return current, false
end

local function enter(fighter: FighterState, state: number, numpad: number)
	fighter.state = state
	fighter.stateFrame = 0
	if state == StateIds.JUMP then
		fighter.jumpDrift = if numpad == 9 then 1 elseif numpad == 7 then -1 else 0
	end
end

-- Moves the fighter for its current state. (opponentX, opponentZ) is the opponent at the start of the frame.
local function move(fighter: FighterState, data: FighterData, opponentX: number, opponentZ: number)
	local state = fighter.state
	if state == StateIds.WALK_FORWARD then
		Geometry.moveToward(fighter, opponentX, opponentZ, data.walkForwardSpeed)
	elseif state == StateIds.WALK_BACK then
		Geometry.moveToward(fighter, opponentX, opponentZ, -data.walkBackSpeed)
	elseif state == StateIds.DASH then
		if fighter.stateFrame < data.dashMoveFrames then
			Geometry.moveToward(fighter, opponentX, opponentZ, data.dashSpeed)
		end
	elseif state == StateIds.BACKDASH then
		if fighter.stateFrame < data.backdashMoveFrames then
			Geometry.moveToward(fighter, opponentX, opponentZ, -data.backdashSpeed)
		end
	elseif
		state == StateIds.SIDESTEP_IN
		or state == StateIds.SIDESTEP_OUT
		or state == StateIds.SIDEWALK_IN
		or state == StateIds.SIDEWALK_OUT
	then
		-- The fight axis runs from the screen-left fighter to the screen-right one; "in" is away from the camera,
		-- which looks along (axisZ, -axisX).
		local sign = if fighter.facingRight then 1 else -1
		local axisX, axisZ = (opponentX - fighter.x) * sign, (opponentZ - fighter.z) * sign
		local len = Geometry.length(axisX, axisZ)
		if len > 0 then
			local inward = state == StateIds.SIDESTEP_IN or state == StateIds.SIDEWALK_IN
			local speed = if state == StateIds.SIDEWALK_IN or state == StateIds.SIDEWALK_OUT
				then data.sidewalkSpeed
				else data.sidestepSpeed
			local dirSign = if inward then 1 else -1
			Geometry.circle(fighter, opponentX, opponentZ, axisZ / len * dirSign, -axisX / len * dirSign, speed)
		end
	elseif state == StateIds.JUMP then
		local t, total = fighter.stateFrame + 1, data.jumpFrames
		fighter.y = (4 * data.jumpHeight * t * (total - t)) // (total * total)
		if fighter.jumpDrift ~= 0 then
			Geometry.moveToward(fighter, opponentX, opponentZ, fighter.jumpDrift * data.jumpDriftSpeed)
		end
		return
	end
	fighter.y = 0
end

-- Advances one fighter by one frame. Its input for this frame must already be in its history.
local function update(
	fighter: FighterState,
	data: FighterData,
	frame: number,
	mask: InputMask,
	opponentX: number,
	opponentZ: number
)
	local numpad = Input.toNumpad(mask, fighter.facingRight)
	local tapDir = Intent.update(fighter, numpad, InputHistory.numpadAt(fighter, frame - 1))
	MotionParser.updateCommand(fighter, frame)

	local nextState, entering = transition(fighter, data, requestedState(fighter, frame, numpad, tapDir))
	if entering then
		enter(fighter, nextState, numpad)
	else
		fighter.stateFrame += 1
	end
	move(fighter, data, opponentX, opponentZ)
end

return {
	update = update,
}
