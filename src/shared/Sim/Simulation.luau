--!strict
-- Pure, deterministic combat simulation. Each step advances exactly one 60 Hz frame.
-- No Roblox APIs, clocks or random values here: the host decides when to step and supplies the inputs.
-- Written for exactly two fighters (FIGHTER_COUNT).

local Constants = require(script.Parent.Constants)
local FighterStates = require(script.Parent.FighterStates)
local Geometry = require(script.Parent.Geometry)
local InputHistory = require(script.Parent.InputHistory)
local Intent = require(script.Parent.Intent)
local StateIds = require(script.Parent.StateIds)
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
		y = 0,
		z = 0,
		facingRight = facingRight,
		state = StateIds.IDLE,
		stateFrame = 0,
		jumpDrift = 0,
		runArmed = false,
		history = InputHistory.create(),
		pendingDir = 0,
		pendingFrames = 0,
		pendingAfterTap = false,
		heldDir = 0,
		heldKind = Intent.NONE,
		tapDir = 0,
		sinceTap = Constants.SIDEWALK_WINDOW + 1,
		lastCommand = 0,
		lastCommandButtons = 0,
		lastCommandFrame = -1,
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
		sideSign = 1,
		axisX = Constants.START_DISTANCE,
		axisZ = 0,
		roster = roster,
	}
end

-- Keeps track of which fighter is on screen left. Circling rotates the axis a little each frame and never
-- flips it; only the fighters passing each other turns the axis by more than 90 degrees in one frame.
local function updateSides(state: SimState)
	local p1, p2 = state.fighters[1], state.fighters[2]
	local axisX, axisZ = p2.x - p1.x, p2.z - p1.z
	if axisX * state.axisX + axisZ * state.axisZ < 0 then
		state.sideSign = -state.sideSign
	end
	state.axisX, state.axisZ = axisX, axisZ
	p1.facingRight = state.sideSign == 1
	p2.facingRight = not p1.facingRight
end

-- Pushes overlapping fighters apart along the line between them. The overlap is split evenly;
-- the odd unit always goes to fighter 2.
local function resolvePushboxes(state: SimState)
	local p1, p2 = state.fighters[1], state.fighters[2]
	local dx, dz = p2.x - p1.x, p2.z - p1.z
	local distance = Geometry.length(dx, dz)
	local minDistance = state.roster[1].pushboxRadius + state.roster[2].pushboxRadius
	if distance >= minDistance then
		return
	end
	local ux, uz
	if distance == 0 then
		ux, uz = state.sideSign, 0
	else
		ux, uz = dx / distance, dz / distance
	end
	local overlap = math.ceil(minDistance - distance)
	local share1 = overlap // 2
	local share2 = overlap - share1
	p1.x -= Geometry.round(ux * share1)
	p1.z -= Geometry.round(uz * share1)
	p2.x += Geometry.round(ux * share2)
	p2.z += Geometry.round(uz * share2)
end

local function step(state: SimState, inputs: FrameInputs)
	local frame = state.frame
	for i = 1, Constants.FIGHTER_COUNT do
		InputHistory.write(state.fighters[i], frame, inputs[i])
	end
	updateSides(state)

	-- Both fighters move relative to where the other stood at the start of the frame.
	local p1, p2 = state.fighters[1], state.fighters[2]
	local startX = { p1.x, p2.x }
	local startZ = { p1.z, p2.z }
	-- Fighters always update in index order so every machine produces the same result.
	for i = 1, Constants.FIGHTER_COUNT do
		local other = Constants.FIGHTER_COUNT + 1 - i
		FighterStates.update(state.fighters[i], state.roster[i], frame, inputs[i], startX[other], startZ[other])
	end
	resolvePushboxes(state)
	state.frame += 1
end

local function cloneFighter(fighter: FighterState): FighterState
	local copy = table.clone(fighter)
	copy.history = table.clone(fighter.history)
	return copy
end

local function clone(state: SimState): SimState
	return {
		frame = state.frame,
		fighters = { cloneFighter(state.fighters[1]), cloneFighter(state.fighters[2]) },
		sideSign = state.sideSign,
		axisX = state.axisX,
		axisZ = state.axisZ,
		roster = state.roster,
	}
end

local function mix(hash: number, value: number): number
	return (hash * HASH_MULTIPLIER + value) % HASH_MODULUS
end

local function bool(value: boolean): number
	return if value then 1 else 0
end

-- Integer hash of the whole state, used to detect desyncs. Fields are mixed in a fixed order;
-- every hashed value must be an integer for the result to be exact.
local function checksum(state: SimState): number
	local hash = state.frame % HASH_MODULUS
	hash = mix(hash, state.sideSign)
	hash = mix(hash, state.axisX)
	hash = mix(hash, state.axisZ)
	for i = 1, Constants.FIGHTER_COUNT do
		local fighter = state.fighters[i]
		hash = mix(hash, fighter.id)
		hash = mix(hash, fighter.x)
		hash = mix(hash, fighter.y)
		hash = mix(hash, fighter.z)
		hash = mix(hash, bool(fighter.facingRight))
		hash = mix(hash, fighter.state)
		hash = mix(hash, fighter.stateFrame)
		hash = mix(hash, fighter.jumpDrift)
		hash = mix(hash, bool(fighter.runArmed))
		hash = mix(hash, fighter.pendingDir)
		hash = mix(hash, fighter.pendingFrames)
		hash = mix(hash, bool(fighter.pendingAfterTap))
		hash = mix(hash, fighter.heldDir)
		hash = mix(hash, fighter.heldKind)
		hash = mix(hash, fighter.tapDir)
		hash = mix(hash, fighter.sinceTap)
		hash = mix(hash, fighter.lastCommand)
		hash = mix(hash, fighter.lastCommandButtons)
		hash = mix(hash, fighter.lastCommandFrame)
		for slot = 1, Constants.HISTORY_SIZE do
			hash = mix(hash, fighter.history[slot])
		end
	end
	return hash
end

return {
	new = new,
	step = step,
	clone = clone,
	checksum = checksum,
}
