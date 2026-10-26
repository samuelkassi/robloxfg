--!strict
-- Basic moves shared, or nearly shared, by every fighter. Every value here is a (start) value.

local CombatIds = require(script.Parent.Parent.Sim.CombatIds)
local Input = require(script.Parent.Parent.Sim.Input)
local Types = require(script.Parent.Parent.Sim.Types)

local function hitbox(forward: number, up: number, radius: number): Types.Hitbox
	return table.freeze({ forward = forward, side = 0, up = up, radius = radius })
end

-- 1: fast high punch. i10, +1 on block, +8 on hit.
local JAB: Types.MoveData = table.freeze({
	name = "Jab",
	buttons = Input.B1,
	motion = nil,
	justFrame = 0,
	startup = 10,
	active = 2,
	recovery = 16,
	onHit = 8,
	onBlock = 1,
	onCounter = 8,
	hitLevel = CombatIds.HIGH,
	damage = 5,
	counterDamage = 7,
	counterEffect = CombatIds.EFFECT_NONE,
	homing = false,
	hitPushback = 300,
	blockPushback = 400,
	hitboxes = table.freeze({
		table.freeze({ hitbox(1500, 4700, 400) }),
		table.freeze({ hitbox(1700, 4700, 400) }),
	}),
	cancels = table.freeze({}),
})

return table.freeze({
	JAB = JAB,
})
