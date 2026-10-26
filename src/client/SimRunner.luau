--!strict
-- Client host for the simulation: feeds render-frame deltas into the fixed 60 Hz stepper.
-- Wall-clock time and Roblox services belong here, never in Shared.Sim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sim = ReplicatedStorage.Shared.Sim
local Constants = require(Sim.Constants)
local FixedStepper = require(Sim.FixedStepper)
local Input = require(Sim.Input)
local Motions = require(Sim.Motions)
local Simulation = require(Sim.Simulation)
local StateIds = require(Sim.StateIds)
local Types = require(Sim.Types)
local Greybox = require(ReplicatedStorage.Shared.Fighters.Greybox)
local InputCapture = require(script.Parent.Input.InputCapture)
local CameraRig = require(script.Parent.Render.CameraRig)
local FighterView = require(script.Parent.Render.FighterView)

local BIND_NAME = "Simulation"
-- Runs just after Roblox processes input, so sampling and stepping happen before camera and render.
local BIND_PRIORITY = Enum.RenderPriority.Input.Value + 1
local DEBUG_INTERVAL = 1 -- seconds between debug lines
local INPUT_LOG_SIZE = 120 -- (start) frames of local input kept for netcode and replay

-- Player 1 is the local device; player 2 stays neutral until there is an opponent to drive it.
local inputs: Types.FrameInputs = table.create(Constants.FIGHTER_COUNT, 0)

-- Ring buffer of local inputs, slot = frame % INPUT_LOG_SIZE + 1.
local inputLog: { Types.FrameInput } = {}
for i = 1, INPUT_LOG_SIZE do
	inputLog[i] = { frame = -1, mask = 0 }
end

local state: Types.SimState? = nil
local running = false

local function start()
	if running then
		return
	end
	running = true

	local simState = Simulation.new({ Greybox, Greybox })
	state = simState
	InputCapture.start()
	FighterView.start(simState)

	local lastMask = 0
	local lastStates = table.create(Constants.FIGHTER_COUNT, StateIds.IDLE)
	local lastCommandFrames = table.create(Constants.FIGHTER_COUNT, -1)

	-- Debug: print each fighter's state changes and newly detected motion commands.
	local function printChanges(frame: number)
		for i, fighter in simState.fighters do
			if fighter.state ~= lastStates[i] then
				print(`[State] P{i} f={frame} {StateIds.NAMES[fighter.state]}`)
				lastStates[i] = fighter.state
			end
			if fighter.lastCommand ~= 0 and fighter.lastCommandFrame ~= lastCommandFrames[i] then
				local motion = Motions.LIST[fighter.lastCommand]
				print(`[Command] P{i} f={frame} {motion.name}{Input.describeButtons(fighter.lastCommandButtons)}`)
				lastCommandFrames[i] = fighter.lastCommandFrame
			end
		end
	end

	local stepper = FixedStepper.new(function()
		-- Sample per step, not per render tick, so each frame gets its own input.
		local frame = simState.frame
		local mask = InputCapture.sample()
		local entry = inputLog[frame % INPUT_LOG_SIZE + 1]
		entry.frame = frame
		entry.mask = mask
		inputs[1] = mask

		if mask ~= lastMask then
			print(`[Input] f={frame} {Input.describe(mask)}`)
			lastMask = mask
		end

		Simulation.step(simState, inputs)
		printChanges(frame)
	end)

	local stepsSinceDebug = 0
	local debugTimer = 0
	RunService:BindToRenderStep(BIND_NAME, BIND_PRIORITY, function(dt: number)
		stepsSinceDebug += FixedStepper.advance(stepper, dt)
		-- Rendering follows the simulation: draw the latest frame after stepping, never feed back into it.
		FighterView.update(simState)
		CameraRig.update(simState)

		debugTimer += dt
		if debugTimer >= DEBUG_INTERVAL then
			local p1, p2 = simState.fighters[1], simState.fighters[2]
			print(
				`[Sim] frame {simState.frame}  steps/s {stepsSinceDebug}  dropped {stepper.droppedFrames}`
					.. `  p1 ({p1.x}, {p1.z})  p2 ({p2.x}, {p2.z})`
			)
			stepsSinceDebug = 0
			debugTimer -= DEBUG_INTERVAL
		end
	end)
end

local function stop()
	if not running then
		return
	end
	running = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	InputCapture.stop()
	FighterView.stop()
end

-- Read-only view for rendering; never write to the returned state.
local function getState(): Types.SimState?
	return state
end

-- The local input sampled for a frame, or nil once it has left the log.
local function getLoggedInput(frame: number): Types.InputMask?
	local entry = inputLog[frame % INPUT_LOG_SIZE + 1]
	return if entry.frame == frame then entry.mask else nil
end

return {
	start = start,
	stop = stop,
	getState = getState,
	getLoggedInput = getLoggedInput,
}
