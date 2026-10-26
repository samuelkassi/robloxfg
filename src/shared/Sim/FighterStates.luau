--!strict
-- Fighter state machine. Each frame it works out which state the input asks for (an attack, else movement),
-- decides whether the current state allows the switch (committed states only through their cancel windows),
-- then moves. Directions use the opponent's position from the start of the frame, so update order can't bias it.
-- Hits are resolved afterwards by Sim.Combat.

local Combat = require(script.Parent.Combat)
local Constants = require(script.Parent.Constants)
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

-- Free states an attack can start from. Committed states (dash, backdash, sidestep) need a cancel window
-- that lists ATTACK; crouching moves come later, so attacks don't start from CROUCH yet.
local ATTACK_FROM = {
	[StateIds.IDLE] = true,
	[StateIds.WALK_FORWARD] = true,
	[StateIds.WALK_BACK] = true,
	[StateIds.SIDEWALK_IN] = true,
	[StateIds.SIDEWALK_OUT] = true,
	[StateIds.RUN] = true,
}

-- Frames a committed state lasts, or nil for states that can change on any frame.
local function durationOf(fighter: FighterState, data: FighterData): number?
	local state = fighter.state
	if state == StateIds.ATTACK then
		return Combat.totalFrames(data.moves[fighter.moveId])
	elseif state == StateIds.HITSTUN or state == StateIds.BLOCKSTUN then
		return fighter.stunLength
	elseif state == StateIds.DASH then
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

-- The move an unused button press in the last BUTTON_BUFFER frames asks for, and that press's frame.
-- Motion moves are matched before plain button moves.
local function findAttack(fighter: FighterState, data: FighterData, frame: number): (number, number)
	for pressFrame = frame, math.max(0, frame - Constants.BUTTON_BUFFER + 1), -1 do
		if pressFrame <= fighter.consumedPressFrame then
			break
		end
		local buttons = InputHistory.pressedAt(fighter, pressFrame)
		if buttons ~= 0 then
			for pass = 1, 2 do
				for id, moveData in data.moves do
					local wantsMotion = moveData.motion ~= nil
					if (pass == 1) == wantsMotion and moveData.buttons == buttons then
						if
							not wantsMotion
							or (fighter.lastCommand == moveData.motion and fighter.lastCommandFrame == pressFrame)
						then
							return id, pressFrame
						end
					end
				end
			end
		end
	end
	return 0, -1
end

-- The state this frame's input asks for, highest priority first.
local function requestedState(fighter: FighterState, frame: number, numpad: number, tapDir: number): number
	if fighter.runArmed then
		return StateIds.RUN
	elseif MotionParser.dashTapped(fighter, frame, Motions.DASH_STEPS) then
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
	local duration = durationOf(fighter, data)
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
	fighter.moveId = 0
	if state == StateIds.JUMP then
		fighter.jumpDrift = if numpad == 9 then 1 elseif numpad == 7 then -1 else 0
	end
end

local function aimAt(fighter: FighterState, opponentX: number, opponentZ: number)
	fighter.attackDirX, fighter.attackDirZ =
		Geometry.unitScaled(fighter.x, fighter.z, opponentX, opponentZ, Constants.DIR_SCALE)
end

-- Moves the fighter for its current state. (opponentX, opponentZ) is the opponent at the start of the frame.
local function move(fighter: FighterState, data: FighterData, opponentX: number, opponentZ: number)
	local state = fighter.state
	if state == StateIds.WALK_FORWARD then
		Geometry.moveToward(fighter, opponentX, opponentZ, data.walkForwardSpeed)
	elseif state == StateIds.RUN then
		local accelFrames = math.min(fighter.stateFrame, data.runAccelFrames)
		local speed = data.runStartSpeed + (data.runMaxSpeed - data.runStartSpeed) * accelFrames // data.runAccelFrames
		Geometry.moveToward(fighter, opponentX, opponentZ, speed)
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
	elseif state == StateIds.ATTACK then
		-- Homing moves keep turning toward the opponent; linear ones keep the direction they started with.
		if data.moves[fighter.moveId].homing then
			aimAt(fighter, opponentX, opponentZ)
		end
	elseif (state == StateIds.HITSTUN or state == StateIds.BLOCKSTUN) and fighter.pushbackLeft > 0 then
		local slide = math.min(fighter.pushbackLeft, fighter.pushbackStep)
		Geometry.moveToward(fighter, opponentX, opponentZ, -slide)
		fighter.pushbackLeft -= slide
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
	-- Run: the third tap of 666 arms it, and it stays armed only while forward is held.
	if numpad ~= 6 then
		fighter.runArmed = false
	elseif MotionParser.dashTapped(fighter, frame, Motions.RUN_STEPS) then
		fighter.runArmed = true
	end

	-- An attack outranks movement. From a free state it must be one attacks start from; from a committed
	-- state the cancel windows decide.
	local attackId, pressFrame = findAttack(fighter, data, frame)
	local canAttack = attackId ~= 0 and (ATTACK_FROM[fighter.state] or durationOf(fighter, data) ~= nil)
	local requested = if canAttack then StateIds.ATTACK else requestedState(fighter, frame, numpad, tapDir)

	local nextState, entering = transition(fighter, data, requested)
	if entering then
		enter(fighter, nextState, numpad)
		if nextState == StateIds.ATTACK then
			fighter.moveId = attackId
			fighter.moveHit = false
			fighter.consumedPressFrame = pressFrame
			fighter.runArmed = false
			aimAt(fighter, opponentX, opponentZ)
		end
	else
		fighter.stateFrame += 1
	end
	move(fighter, data, opponentX, opponentZ)
end

return {
	update = update,
}
