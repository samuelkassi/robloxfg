--!strict
-- Turns variable real-time deltas into whole 60 Hz simulation steps.
-- It never reads a clock: the host passes in each tick's dt.

local Constants = require(script.Parent.Constants)

export type FixedStepper = {
	onStep: () -> (),
	accumulator: number,
	-- Fraction of a frame left in the accumulator. Debug only; rendering shows the latest frame uninterpolated.
	alpha: number,
	-- Frames of real time thrown away because a tick needed more than MAX_STEPS_PER_UPDATE steps.
	droppedFrames: number,
}

local function new(onStep: () -> ()): FixedStepper
	return {
		onStep = onStep,
		accumulator = 0,
		alpha = 0,
		droppedFrames = 0,
	}
end

-- Runs as many steps as dt allows, up to the cap, and returns how many ran.
local function advance(stepper: FixedStepper, dt: number): number
	stepper.accumulator += dt
	local steps = 0
	while stepper.accumulator >= Constants.FRAME_DURATION do
		if steps == Constants.MAX_STEPS_PER_UPDATE then
			-- Drop the backlog so a long stall slows the game down instead of locking it in catch-up.
			stepper.droppedFrames += math.floor(stepper.accumulator / Constants.FRAME_DURATION)
			stepper.accumulator = 0
			break
		end
		stepper.onStep()
		stepper.accumulator -= Constants.FRAME_DURATION
		steps += 1
	end
	stepper.alpha = stepper.accumulator / Constants.FRAME_DURATION
	return steps
end

return {
	new = new,
	advance = advance,
}
