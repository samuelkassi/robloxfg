--!strict
-- Simulation state types. State holds only plain numbers, booleans, strings and tables of them
-- (no Instances, userdata or functions), so it can be cloned for rollback and checksummed.

-- One frame of input for one fighter. Bit layout is in Sim.Input; 0 is neutral.
export type InputMask = number

-- One mask per fighter, indexed 1..FIGHTER_COUNT.
export type FrameInputs = { InputMask }

-- One fighter's input tagged with the frame it was sampled for.
export type FrameInput = {
	frame: number,
	mask: InputMask,
}

-- From `fromFrame` of a committed state onward, the fighter may switch into any state listed in `into`.
export type CancelWindow = {
	fromFrame: number,
	into: { number },
}

-- A fighter's fixed data. Never changes during a match. Distances are units, speeds are units per frame.
export type FighterData = {
	walkForwardSpeed: number,
	walkBackSpeed: number,
	pushboxRadius: number,
	dashFrames: number,
	dashMoveFrames: number, -- frames that move; the rest is recovery
	dashSpeed: number,
	backdashFrames: number,
	backdashMoveFrames: number, -- cancelling the recovery after these is what makes the Korean backdash fast
	backdashSpeed: number,
	sidestepFrames: number,
	sidestepSpeed: number,
	sidewalkSpeed: number,
	jumpFrames: number,
	jumpHeight: number,
	jumpDriftSpeed: number,
	-- Keyed by StateIds of committed states (dash, backdash, sidestep).
	cancels: { [number]: CancelWindow },
}

export type FighterState = {
	id: number,
	x: number, -- units; the ground plane is x/z
	y: number, -- units above the floor
	z: number,
	-- True when this fighter is the screen-left one, so screen right is its forward.
	facingRight: boolean,
	state: number, -- a StateIds value
	stateFrame: number, -- frames spent in the current state, 0 on entry
	jumpDrift: number, -- -1 back, 0 straight up, 1 forward, for the current jump

	-- Raw input masks, slot = frame % HISTORY_SIZE + 1.
	history: { InputMask },

	-- Tap/hold reading of a pure 8 or 2 (see Sim.Intent).
	pendingDir: number, -- 8 or 2 while undecided, else 0
	pendingFrames: number,
	pendingAfterTap: boolean, -- the press came soon after a tap of the same direction
	heldDir: number, -- 8 or 2 once a hold is decided and still held, else 0
	heldKind: number, -- Intent.HOLD or Intent.SIDEWALK while heldDir is set
	tapDir: number, -- direction of the most recent tap, else 0
	sinceTap: number, -- frames since that tap, capped

	-- Most recent motion command (see Sim.Motions); 0 when none is buffered.
	lastCommand: number,
	lastCommandButtons: number,
	lastCommandFrame: number, -- frame of the button press, -1 when none
}

export type SimState = {
	frame: number,
	fighters: { FighterState },
	-- 1 when fighter 1 is on screen left, -1 when fighter 2 is.
	sideSign: number,
	-- Fighter 1 to fighter 2 offset from the previous frame, used to notice the fighters passing each other.
	axisX: number,
	axisZ: number,
	-- Frozen fighter data, indexed like fighters. Shared by clones and left out of the checksum.
	roster: { FighterData },
}

return {}
