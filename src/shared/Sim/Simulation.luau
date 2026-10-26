--!strict
-- Pure, deterministic combat simulation. Each step advances exactly one 60 Hz frame.
-- No Roblox APIs, clocks or random values here: the host decides when to step and supplies the inputs.
-- Written for exactly two fighters (FIGHTER_COUNT).

local Constants = require(script.Parent.Constants)
local FighterStates = require(script.Parent.FighterStates)
local Types = require(script.Parent.Types)

type FighterData = Types.FighterData
type FighterState = Types.FighterState
type FrameInputs = Types.FrameInputs
type SimState = Types.SimState

local HASH_MULTIPLIER = 31
local HASH_MODULUS = 2 ^ 32

local function newFighter(id: number, x: number, facingRight: boolean): FighterState
	return {
		id = id,
		x = x,
		z = 0,
		facingRight = facingRight,
		state = FighterStates.IDLE,
		stateFrame = 0,
	}
end

local function new(roster: { FighterData }): SimState
	local half = Constants.START_DISTANCE // 2
	return {
		frame = 0,
		fighters = {
			newFighter(1, -half, true),
			newFighter(2, Constants.START_DISTANCE - half, false),
		},
		roster = roster,
	}
end

-- Both fighters face each other, judged from positions before anyone moves this frame.
-- On an exact tie, fighter 1 is treated as the left one.
local function updateFacing(state: SimState)
	local p1, p2 = state.fighters[1], state.fighters[2]
	p1.facingRight = p1.x <= p2.x
	p2.facingRight = not p1.facingRight
end

-- Pushes overlapping fighters apart, splitting the overlap; the odd unit always goes to the right-hand fighter.
local function resolvePushboxes(state: SimState)
	local leftIndex, rightIndex = 1, 2
	if state.fighters[1].x > state.fighters[2].x then
		leftIndex, rightIndex = 2, 1
	end
	local left, right = state.fighters[leftIndex], state.fighters[rightIndex]
	local minGap = state.roster[leftIndex].pushboxHalfWidth + state.roster[rightIndex].pushboxHalfWidth
	local overlap = minGap - (right.x - left.x)
	if overlap > 0 then
		local leftShare = overlap // 2
		left.x -= leftShare
		right.x += overlap - leftShare
	end
end

local function step(state: SimState, inputs: FrameInputs)
	updateFacing(state)
	-- Fighters always update in index order so every machine produces the same result.
	for i = 1, Constants.FIGHTER_COUNT do
		FighterStates.update(state.fighters[i], state.roster[i], inputs[i])
	end
	resolvePushboxes(state)
	state.frame += 1
end

local function clone(state: SimState): SimState
	local fighters: { FighterState } = {}
	for i, fighter in state.fighters do
		fighters[i] = {
			id = fighter.id,
			x = fighter.x,
			z = fighter.z,
			facingRight = fighter.facingRight,
			state = fighter.state,
			stateFrame = fighter.stateFrame,
		}
	end
	return {
		frame = state.frame,
		fighters = fighters,
		roster = state.roster,
	}
end

local function mix(hash: number, value: number): number
	return (hash * HASH_MULTIPLIER + value) % HASH_MODULUS
end

-- Integer hash of the whole state, used to detect desyncs. Fields are mixed in a fixed order;
-- every hashed value must be an integer for the result to be exact.
local function checksum(state: SimState): number
	local hash = state.frame % HASH_MODULUS
	for i = 1, Constants.FIGHTER_COUNT do
		local fighter = state.fighters[i]
		hash = mix(hash, fighter.id)
		hash = mix(hash, fighter.x)
		hash = mix(hash, fighter.z)
		hash = mix(hash, if fighter.facingRight then 1 else 0)
		hash = mix(hash, fighter.state)
		hash = mix(hash, fighter.stateFrame)
	end
	return hash
end

return {
	new = new,
	step = step,
	clone = clone,
	checksum = checksum,
}
