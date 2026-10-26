--!strict
-- Reads a pure 8 or 2 as a tap (sidestep) or a hold (jump/crouch, or sidewalk right after a tap).
-- Nothing commits until the stick is released or TAP_WINDOW frames pass. Diagonals are never ambiguous:
-- 7/9 and 1/3 are handled directly by the state machine.

local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

type FighterState = Types.FighterState

local NONE = 0
local HOLD = 1
local SIDEWALK = 2

-- 1 for 7/8/9, -1 for 1/2/3, 0 otherwise.
local function verticalGroup(numpad: number): number
	if numpad >= 7 then
		return 1
	elseif numpad <= 3 then
		return -1
	end
	return 0
end

-- Advances the tap/hold reading by one frame. Returns the direction (8 or 2) of a tap completed this frame,
-- or 0. A decided hold is left in fighter.heldDir / fighter.heldKind until released.
local function update(fighter: FighterState, numpad: number, previousNumpad: number): number
	if fighter.sinceTap <= Constants.SIDEWALK_WINDOW then
		fighter.sinceTap += 1
	end

	if fighter.heldDir ~= 0 and numpad ~= fighter.heldDir then
		fighter.heldDir = 0
		fighter.heldKind = NONE
	end

	local fresh = (numpad == 8 or numpad == 2) and verticalGroup(previousNumpad) ~= verticalGroup(numpad)
	if fresh then
		fighter.pendingDir = numpad
		fighter.pendingFrames = 0
		fighter.pendingAfterTap = fighter.tapDir == numpad and fighter.sinceTap <= Constants.SIDEWALK_WINDOW
	end

	local pending = fighter.pendingDir
	if pending == 0 then
		return 0
	end

	if numpad == pending then
		fighter.pendingFrames += 1
		if fighter.pendingFrames >= Constants.TAP_WINDOW then
			fighter.heldDir = pending
			fighter.heldKind = if fighter.pendingAfterTap then SIDEWALK else HOLD
			fighter.pendingDir = 0
		end
		return 0
	end

	fighter.pendingDir = 0
	-- Rolling onto a diagonal of the same side (8 to 9, 2 to 1) is not a tap; the diagonal takes over.
	if verticalGroup(numpad) == verticalGroup(pending) then
		return 0
	end
	fighter.tapDir = pending
	fighter.sinceTap = 0
	return pending
end

return {
	NONE = NONE,
	HOLD = HOLD,
	SIDEWALK = SIDEWALK,
	update = update,
}
