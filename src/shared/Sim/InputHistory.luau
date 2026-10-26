--!strict
-- Reads and writes a fighter's input history ring buffer.

local Constants = require(script.Parent.Constants)
local Input = require(script.Parent.Input)
local Types = require(script.Parent.Types)

type FighterState = Types.FighterState
type InputMask = Types.InputMask

local SIZE = Constants.HISTORY_SIZE

local function create(): { InputMask }
	return table.create(SIZE, 0)
end

local function write(fighter: FighterState, frame: number, mask: InputMask)
	fighter.history[frame % SIZE + 1] = mask
end

-- The mask for a frame. Frames before the match started read as neutral; callers stay within SIZE frames of now.
local function maskAt(fighter: FighterState, frame: number): InputMask
	if frame < 0 then
		return 0
	end
	return fighter.history[frame % SIZE + 1]
end

-- Numpad direction for a frame, using the fighter's current facing.
local function numpadAt(fighter: FighterState, frame: number): number
	return Input.toNumpad(maskAt(fighter, frame), fighter.facingRight)
end

-- Buttons that went down on this frame (not held from the frame before).
local function pressedAt(fighter: FighterState, frame: number): number
	local now = bit32.band(maskAt(fighter, frame), Input.BUTTON_BITS)
	return bit32.band(now, bit32.bnot(maskAt(fighter, frame - 1)))
end

return {
	create = create,
	write = write,
	maskAt = maskAt,
	numpadAt = numpadAt,
	pressedAt = pressedAt,
}
