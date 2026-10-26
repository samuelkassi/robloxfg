--!strict
-- Fixed timing, space and input-reading values for the combat simulation.

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

	-- Frames of input each fighter remembers. Must cover the longest motion with full slack.
	HISTORY_SIZE = 64,
	-- (start) Most frames allowed between one direction of a motion and the next.
	MOTION_SLACK = 8,
	-- (start) Frames a button press stays usable for completing a motion.
	BUTTON_BUFFER = 5,
	-- (start) Most frames between the two taps of a dash (66) or backdash (44).
	DASH_WINDOW = 10,
	-- (start) A pure 8 or 2 released before this many frames is a tap (sidestep); held this long it is a hold.
	TAP_WINDOW = 6,
	-- (start) A hold that starts within this many frames after a tap of the same direction is a sidewalk.
	SIDEWALK_WINDOW = 12,
})
