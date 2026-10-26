--!strict
-- Pure, deterministic combat simulation. Each step advances exactly one 60 Hz frame.
-- No Roblox APIs, clocks or random values here: the host decides when to step and supplies the inputs.

local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

type FighterState = Types.FighterState
type FrameInputs = Types.FrameInputs
type InputMask = Types.InputMask
type SimState = Types.SimState

local HASH_MULTIPLIER = 31
local HASH_MODULUS = 2 ^ 32

local function new(): SimState
	local fighters: { FighterState } = {}
	for i = 1, Constants.FIGHTER_COUNT do
		fighters[i] = { id = i }
	end
	return {
		frame = 0,
		fighters = fighters,
	}
end

local function updateFighter(_state: SimState, _fighter: FighterState, _input: InputMask) end

local function step(state: SimState, inputs: FrameInputs)
	-- Fighters always update in index order so every machine produces the same result.
	for i = 1, Constants.FIGHTER_COUNT do
		updateFighter(state, state.fighters[i], inputs[i])
	end
	state.frame += 1
end

local function clone(state: SimState): SimState
	local fighters: { FighterState } = {}
	for i, fighter in state.fighters do
		fighters[i] = { id = fighter.id }
	end
	return {
		frame = state.frame,
		fighters = fighters,
	}
end

-- Integer hash of the whole state, used to detect desyncs. Fields are mixed in a fixed order;
-- every hashed value must be an integer for the result to be exact.
local function checksum(state: SimState): number
	local hash = state.frame % HASH_MODULUS
	for i = 1, Constants.FIGHTER_COUNT do
		hash = (hash * HASH_MULTIPLIER + state.fighters[i].id) % HASH_MODULUS
	end
	return hash
end

return {
	new = new,
	step = step,
	clone = clone,
	checksum = checksum,
}
