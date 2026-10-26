--!strict
-- Fighter state ids. Numbers so state can be hashed; names are for debug output only.

local IDLE = 1
local WALK_FORWARD = 2
local WALK_BACK = 3
local CROUCH = 4
local DASH = 5
local BACKDASH = 6
local SIDESTEP_IN = 7
local SIDESTEP_OUT = 8
local SIDEWALK_IN = 9
local SIDEWALK_OUT = 10
local JUMP = 11

local NAMES = table.freeze({
	[IDLE] = "IDLE",
	[WALK_FORWARD] = "WALK_FORWARD",
	[WALK_BACK] = "WALK_BACK",
	[CROUCH] = "CROUCH",
	[DASH] = "DASH",
	[BACKDASH] = "BACKDASH",
	[SIDESTEP_IN] = "SIDESTEP_IN",
	[SIDESTEP_OUT] = "SIDESTEP_OUT",
	[SIDEWALK_IN] = "SIDEWALK_IN",
	[SIDEWALK_OUT] = "SIDEWALK_OUT",
	[JUMP] = "JUMP",
})

return table.freeze({
	IDLE = IDLE,
	WALK_FORWARD = WALK_FORWARD,
	WALK_BACK = WALK_BACK,
	CROUCH = CROUCH,
	DASH = DASH,
	BACKDASH = BACKDASH,
	SIDESTEP_IN = SIDESTEP_IN,
	SIDESTEP_OUT = SIDESTEP_OUT,
	SIDEWALK_IN = SIDEWALK_IN,
	SIDEWALK_OUT = SIDEWALK_OUT,
	JUMP = JUMP,
	NAMES = NAMES,
})
