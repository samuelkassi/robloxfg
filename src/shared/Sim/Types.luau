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

-- A sphere placed relative to the attacker: `forward` along the attack direction, `side` to the attacker's
-- right, `up` above the attacker's feet. Units.
export type Hitbox = {
	forward: number,
	side: number,
	up: number,
	radius: number,
}

-- An upright capsule around the fighter's position: the segment from `bottom` to `top` above the feet,
-- widened by `radius`. Units.
export type Hurtbox = {
	radius: number,
	bottom: number,
	top: number,
}

-- One move. Frame counts follow frame-data convention: the press is frame 1, so startup 10 ("i10") means
-- the first active frame is frame 10. Advantage values are for a hit on the first active frame; the engine
-- derives hitstun and blockstun from them, so hitting on a later active frame gives correspondingly more.
export type MoveData = {
	name: string,
	buttons: number, -- Input button bits that must be newly pressed together
	motion: number?, -- a Motions.LIST id the buttons must complete, or nil for a plain button move
	justFrame: number, -- just-frame window in frames, 0 when the move has none
	startup: number,
	active: number,
	recovery: number,
	onHit: number,
	onBlock: number,
	onCounter: number,
	hitLevel: number, -- CombatIds level
	damage: number,
	counterDamage: number,
	counterEffect: number, -- CombatIds effect on counter hit
	homing: boolean, -- homing moves track a sidestepping opponent; linear ones keep their start direction
	hitPushback: number, -- units the defender slides back on hit
	blockPushback: number,
	hitboxes: { { Hitbox } }, -- one list per active frame
	cancels: { CancelWindow }, -- strings and cancels; empty until strings exist
}

-- A fighter's fixed data. Never changes during a match. Distances are units, speeds are units per frame.
export type FighterData = {
	health: number,
	standingHurtbox: Hurtbox,
	crouchingHurtbox: Hurtbox,
	moves: { MoveData }, -- a move's id is its index
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
	-- Run starts at runStartSpeed and reaches runMaxSpeed after runAccelFrames.
	runStartSpeed: number,
	runMaxSpeed: number,
	runAccelFrames: number,
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
	-- Set by the third tap of 666 and kept while 6 is held, so the run starts as soon as the dash can cancel.
	runArmed: boolean,

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

	health: number,
	-- The move being performed while in ATTACK, else 0.
	moveId: number,
	moveHit: boolean, -- the current move has already connected (a move hits at most once)
	-- Attack direction as a unit vector scaled by DIR_SCALE; fixed at the start of linear moves.
	attackDirX: number,
	attackDirZ: number,
	-- Frame of the newest button press already used to start a move, so a buffered press is used once.
	consumedPressFrame: number,
	-- Length of the current HITSTUN or BLOCKSTUN.
	stunLength: number,
	pushbackLeft: number, -- units still to slide back
	pushbackStep: number, -- units per frame
	-- The last time this fighter's move connected, for debug output: frame and CombatIds result.
	hitEventFrame: number,
	hitEventResult: number,
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
