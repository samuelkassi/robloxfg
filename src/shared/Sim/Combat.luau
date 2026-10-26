--!strict
-- Hit detection and hit results. Hitboxes are spheres, hurtboxes are upright capsules, and overlap is tested
-- with whole numbers and squared distances (no square roots), so it is exact on every machine.

local CombatIds = require(script.Parent.CombatIds)
local Constants = require(script.Parent.Constants)
local Geometry = require(script.Parent.Geometry)
local InputHistory = require(script.Parent.InputHistory)
local StateIds = require(script.Parent.StateIds)
local Types = require(script.Parent.Types)

type FighterData = Types.FighterData
type FighterState = Types.FighterState
type Hitbox = Types.Hitbox
type Hurtbox = Types.Hurtbox
type MoveData = Types.MoveData
type SimState = Types.SimState

-- Frames from the press to the last recovery frame.
local function totalFrames(move: MoveData): number
	return move.startup - 1 + move.active + move.recovery
end

local function currentMove(fighter: FighterState, data: FighterData): MoveData?
	if fighter.state ~= StateIds.ATTACK or fighter.moveId == 0 then
		return nil
	end
	return data.moves[fighter.moveId]
end

-- Which active frame (1-based) the move is on this frame, or 0 when it is not active.
local function activeIndex(fighter: FighterState, move: MoveData): number
	local index = fighter.stateFrame + 1 - move.startup + 1
	if index >= 1 and index <= move.active then
		return index
	end
	return 0
end

local function hurtboxOf(fighter: FighterState, data: FighterData): Hurtbox
	if fighter.state == StateIds.CROUCH then
		return data.crouchingHurtbox
	end
	return data.standingHurtbox
end

-- World position of a hitbox centre, in units.
local function hitboxCenter(fighter: FighterState, hitbox: Hitbox): (number, number, number)
	local scale = Constants.DIR_SCALE
	local dirX, dirZ = fighter.attackDirX, fighter.attackDirZ
	-- The attacker's right, seen from above with y up.
	local rightX, rightZ = -dirZ, dirX
	local x = fighter.x + Geometry.round((dirX * hitbox.forward + rightX * hitbox.side) / scale)
	local z = fighter.z + Geometry.round((dirZ * hitbox.forward + rightZ * hitbox.side) / scale)
	return x, fighter.y + hitbox.up, z
end

local function overlaps(
	x: number,
	y: number,
	z: number,
	radius: number,
	defender: FighterState,
	hurtbox: Hurtbox
): boolean
	local bottom, top = defender.y + hurtbox.bottom, defender.y + hurtbox.top
	local dy = if y < bottom then y - bottom elseif y > top then y - top else 0
	local dx, dz = x - defender.x, z - defender.z
	local reach = radius + hurtbox.radius
	return dx * dx + dy * dy + dz * dz <= reach * reach
end

-- Guarding needs a state that can block and the right direction held: back blocks highs and mids,
-- neutral blocks highs only, down-back blocks lows.
local function blocks(defender: FighterState, frame: number, hitLevel: number): boolean
	local state = defender.state
	if
		state ~= StateIds.IDLE
		and state ~= StateIds.WALK_BACK
		and state ~= StateIds.CROUCH
		and state ~= StateIds.BLOCKSTUN
	then
		return false
	end
	local numpad = InputHistory.numpadAt(defender, frame)
	if hitLevel == CombatIds.LOW then
		return numpad == 1
	elseif numpad == 4 then
		return hitLevel == CombatIds.HIGH or hitLevel == CombatIds.MID
	elseif numpad == 5 then
		return hitLevel == CombatIds.HIGH
	end
	return false
end

-- Hitting a fighter during the startup of their own attack is a counter hit.
local function inStartup(fighter: FighterState, data: FighterData): boolean
	local move = currentMove(fighter, data)
	return move ~= nil and fighter.stateFrame + 1 < move.startup
end

-- The result of fighter `index`'s move this frame (a CombatIds result), or 0 if it doesn't connect.
-- Reads state only, so both fighters can be checked before either result is applied.
local function check(state: SimState, index: number, frame: number): number
	local other = Constants.FIGHTER_COUNT + 1 - index
	local attacker, defender = state.fighters[index], state.fighters[other]
	local move = currentMove(attacker, state.roster[index])
	if move == nil or attacker.moveHit then
		return 0
	end
	local active = activeIndex(attacker, move)
	if active == 0 then
		return 0
	end
	local hurtbox = hurtboxOf(defender, state.roster[other])
	for _, hitbox in move.hitboxes[active] do
		local x, y, z = hitboxCenter(attacker, hitbox)
		if overlaps(x, y, z, hitbox.radius, defender, hurtbox) then
			if blocks(defender, frame, move.hitLevel) then
				return CombatIds.BLOCK
			elseif inStartup(defender, state.roster[other]) then
				return CombatIds.COUNTER
			end
			return CombatIds.HIT
		end
	end
	return 0
end

-- Applies a result from `check`. `moveId` is the attacker's move when it was checked: in a trade, applying
-- the other fighter's hit first has already cleared it. The defender's stun starts next frame and lasts long
-- enough that the attacker's advantage matches the move data for a hit on the first active frame.
local function apply(state: SimState, index: number, result: number, moveId: number, frame: number)
	local other = Constants.FIGHTER_COUNT + 1 - index
	local attacker, defender = state.fighters[index], state.fighters[other]
	local move = state.roster[index].moves[moveId]
	attacker.moveHit = true
	attacker.hitEventFrame = frame
	attacker.hitEventResult = result

	local advantage = if result == CombatIds.BLOCK
		then move.onBlock
		elseif result == CombatIds.COUNTER then move.onCounter
		else move.onHit
	local attackerRemaining = totalFrames(move) - move.startup
	defender.stunLength = math.max(1, advantage + attackerRemaining)
	defender.state = if result == CombatIds.BLOCK then StateIds.BLOCKSTUN else StateIds.HITSTUN
	defender.stateFrame = -1
	defender.moveId = 0
	defender.runArmed = false
	defender.y = 0

	if result ~= CombatIds.BLOCK then
		local damage = if result == CombatIds.COUNTER then move.counterDamage else move.damage
		defender.health = math.max(0, defender.health - damage)
	end
	local pushback = if result == CombatIds.BLOCK then move.blockPushback else move.hitPushback
	defender.pushbackLeft = pushback
	defender.pushbackStep = (pushback + Constants.PUSHBACK_FRAMES - 1) // Constants.PUSHBACK_FRAMES
end

return {
	totalFrames = totalFrames,
	currentMove = currentMove,
	activeIndex = activeIndex,
	hurtboxOf = hurtboxOf,
	hitboxCenter = hitboxCenter,
	check = check,
	apply = apply,
}
