--!strict
-- Fixed timing and space values for the combat simulation.

local FRAMES_PER_SECOND = 60

return table.freeze({
	FRAMES_PER_SECOND = FRAMES_PER_SECOND,
	FRAME_DURATION = 1 / FRAMES_PER_SECOND,
	-- (start) Most steps one host tick may run to catch up; leftover time beyond this is dropped.
	MAX_STEPS_PER_UPDATE = 4,
	FIGHTER_COUNT = 2,
	-- Positions are whole units so the simulation never accumulates fractions; only rendering converts to studs.
	UNITS_PER_STUD = 1000,
	-- (start) Distance between the fighters at round start, in units.
	START_DISTANCE = 8000,
})
