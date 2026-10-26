--!strict
-- Placeholder fighter used by both sides until real fighters exist. Every value here is a (start) value.

local CommonMoves = require(script.Parent.CommonMoves)
local StateIds = require(script.Parent.Parent.Sim.StateIds)
local Types = require(script.Parent.Parent.Sim.Types)

local SIDESTEP_CANCEL: Types.CancelWindow = table.freeze({
	fromFrame = 6,
	into = table.freeze({
		StateIds.BACKDASH,
		StateIds.CROUCH,
		StateIds.SIDESTEP_IN,
		StateIds.SIDESTEP_OUT,
		StateIds.SIDEWALK_IN,
		StateIds.SIDEWALK_OUT,
		StateIds.ATTACK,
	}),
})

local data: Types.FighterData = table.freeze({
	health = 170,
	-- Body is 6 studs tall standing and 3.5 crouching, matching the grey box.
	standingHurtbox = table.freeze({ radius = 700, bottom = 700, top = 5300 }),
	crouchingHurtbox = table.freeze({ radius = 700, bottom = 700, top = 2800 }),
	moves = table.freeze({ CommonMoves.JAB }),
	walkForwardSpeed = 42, -- about 2.5 studs/s
	walkBackSpeed = 33, -- about 2 studs/s
	pushboxRadius = 1000,
	dashFrames = 16,
	dashMoveFrames = 12,
	dashSpeed = 110,
	backdashFrames = 20,
	backdashMoveFrames = 12,
	backdashSpeed = 100,
	sidestepFrames = 18,
	sidestepSpeed = 120,
	sidewalkSpeed = 70,
	jumpFrames = 40,
	jumpHeight = 2500,
	jumpDriftSpeed = 40,
	runStartSpeed = 80,
	runMaxSpeed = 130, -- about 7.8 studs/s
	runAccelFrames = 20,
	cancels = table.freeze({
		[StateIds.DASH] = table.freeze({
			fromFrame = 4,
			into = table.freeze({
				StateIds.CROUCH,
				StateIds.BACKDASH,
				StateIds.SIDESTEP_IN,
				StateIds.SIDESTEP_OUT,
				StateIds.RUN,
				StateIds.ATTACK,
			}),
		}),
		-- Crouch cancel from frame 6 is what makes the Korean backdash (4, 4, 1, 4, 4, 1...) work.
		[StateIds.BACKDASH] = table.freeze({
			fromFrame = 6,
			into = table.freeze({ StateIds.CROUCH, StateIds.SIDESTEP_IN, StateIds.SIDESTEP_OUT, StateIds.ATTACK }),
		}),
		[StateIds.SIDESTEP_IN] = SIDESTEP_CANCEL,
		[StateIds.SIDESTEP_OUT] = SIDESTEP_CANCEL,
	}),
})

return data
