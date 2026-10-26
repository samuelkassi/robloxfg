--!strict
-- Finds motions in a fighter's input history.
-- A motion's steps must appear in order, each within `slack` frames of the next; frames in between are ignored,
-- so 6323 still reads as 623. Two equal steps in a row need a frame of another direction between them,
-- so 66 is two taps, while 1,4,1,4 still counts as 44.

local Constants = require(script.Parent.Constants)
local InputHistory = require(script.Parent.InputHistory)
local Motions = require(script.Parent.Motions)
local Types = require(script.Parent.Types)

type FighterState = Types.FighterState

-- True if `steps` can be read from history with its last step on a frame in [endMin, endMax].
local function matches(fighter: FighterState, steps: { number }, endMin: number, endMax: number, slack: number): boolean
	local count = #steps
	local first = math.max(endMin - (count - 1) * slack, endMax - Constants.HISTORY_SIZE + 1, 0)
	if endMax < first then
		return false
	end

	local numpads: { [number]: number } = {}
	for frame = first, endMax do
		numpads[frame] = InputHistory.numpadAt(fighter, frame)
	end

	-- reach[frame] is true when steps 1..i can be read ending on that frame.
	local reach: { [number]: boolean } = {}
	for frame = first, endMax do
		reach[frame] = numpads[frame] == steps[1]
	end
	for i = 2, count do
		local step, previous = steps[i], steps[i - 1]
		local nextReach: { [number]: boolean } = {}
		for frame = first, endMax do
			local found = false
			if numpads[frame] == step then
				local sawOther = false
				for earlier = frame - 1, math.max(first, frame - slack), -1 do
					if reach[earlier] and (step ~= previous or sawOther) then
						found = true
						break
					end
					if numpads[earlier] ~= step then
						sawOther = true
					end
				end
			end
			nextReach[frame] = found
		end
		reach = nextReach
	end

	for frame = math.max(endMin, first), endMax do
		if reach[frame] then
			return true
		end
	end
	return false
end

-- True on the frame the second tap of a dash (66) or backdash (44) goes down.
local function dashTapped(fighter: FighterState, frame: number, steps: { number }): boolean
	local direction = steps[#steps]
	if InputHistory.numpadAt(fighter, frame) ~= direction or InputHistory.numpadAt(fighter, frame - 1) == direction then
		return false
	end
	return matches(fighter, steps, frame, frame, Constants.DASH_WINDOW)
end

-- Sets the fighter's buffered command: the highest-priority motion completed by the latest button press
-- in the last BUTTON_BUFFER frames, or 0 when there is none.
local function updateCommand(fighter: FighterState, frame: number)
	fighter.lastCommand = 0
	fighter.lastCommandButtons = 0
	fighter.lastCommandFrame = -1
	for pressFrame = frame, math.max(0, frame - Constants.BUTTON_BUFFER + 1), -1 do
		local buttons = InputHistory.pressedAt(fighter, pressFrame)
		if buttons ~= 0 then
			for id, motion in Motions.LIST do
				if
					matches(
						fighter,
						motion.steps,
						pressFrame - Constants.MOTION_SLACK,
						pressFrame,
						Constants.MOTION_SLACK
					)
				then
					fighter.lastCommand = id
					fighter.lastCommandButtons = buttons
					fighter.lastCommandFrame = pressFrame
					return
				end
			end
			return
		end
	end
end

return {
	matches = matches,
	dashTapped = dashTapped,
	updateCommand = updateCommand,
}
