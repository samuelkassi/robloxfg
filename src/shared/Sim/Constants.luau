--!strict
-- Fixed timing values for the combat simulation.

local FRAMES_PER_SECOND = 60

return table.freeze({
	FRAMES_PER_SECOND = FRAMES_PER_SECOND,
	FRAME_DURATION = 1 / FRAMES_PER_SECOND,
	-- (start) Most steps one host tick may run to catch up; leftover time beyond this is dropped.
	MAX_STEPS_PER_UPDATE = 4,
	FIGHTER_COUNT = 2,
})
