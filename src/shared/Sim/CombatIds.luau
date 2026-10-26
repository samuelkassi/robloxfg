--!strict
-- Ids used by move data and hit results. Numbers so they can be hashed; names are for debug output only.

local HIGH = 1
local MID = 2
local LOW = 3
local THROW = 4

local HIT = 1
local BLOCK = 2
local COUNTER = 3

-- Extra counter-hit outcomes (crumple, launch) get ids here when juggles exist.
local EFFECT_NONE = 0

return table.freeze({
	HIGH = HIGH,
	MID = MID,
	LOW = LOW,
	THROW = THROW,
	LEVEL_NAMES = table.freeze({ [HIGH] = "high", [MID] = "mid", [LOW] = "low", [THROW] = "throw" }),

	HIT = HIT,
	BLOCK = BLOCK,
	COUNTER = COUNTER,
	RESULT_NAMES = table.freeze({ [HIT] = "HIT", [BLOCK] = "BLOCK", [COUNTER] = "COUNTER" }),

	EFFECT_NONE = EFFECT_NONE,
})
