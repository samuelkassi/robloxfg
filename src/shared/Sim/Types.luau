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

-- A fighter's fixed data. Never changes during a match. Distances are units, speeds are units per frame.
export type FighterData = {
	walkForwardSpeed: number,
	walkBackSpeed: number,
	pushboxHalfWidth: number,
}

export type FighterState = {
	id: number,
	x: number, -- units along the fight axis
	z: number, -- units off the fight axis; stays 0 until sidestep exists
	facingRight: boolean,
	state: number, -- a FighterStates id
	stateFrame: number, -- frames spent in the current state
}

export type SimState = {
	frame: number,
	fighters: { FighterState },
	-- Frozen fighter data, indexed like fighters. Shared by clones and left out of the checksum.
	roster: { FighterData },
}

return {}
