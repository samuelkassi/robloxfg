--!strict
-- Simulation state types. State holds only plain numbers, booleans, strings and tables of them
-- (no Instances, userdata or functions), so it can be cloned for rollback and checksummed.

-- One frame of input for one fighter. Bit layout comes with input capture; 0 is neutral.
export type InputMask = number

-- One mask per fighter, indexed 1..FIGHTER_COUNT.
export type FrameInputs = { InputMask }

-- One fighter's input tagged with the frame it was sampled for.
export type FrameInput = {
	frame: number,
	mask: InputMask,
}

export type FighterState = {
	id: number,
}

export type SimState = {
	frame: number,
	fighters: { FighterState },
}

return {}
