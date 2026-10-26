--!strict
-- Client host for the simulation: feeds render-frame deltas into the fixed 60 Hz stepper.
-- Wall-clock time and Roblox services belong here, never in Shared.Sim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sim = ReplicatedStorage.Shared.Sim
local Constants = require(Sim.Constants)
local FixedStepper = require(Sim.FixedStepper)
local Simulation = require(Sim.Simulation)
local Types = require(Sim.Types)

local BIND_NAME = "Simulation"
-- Runs just after Roblox processes input, so sampling and stepping happen before camera and render.
local BIND_PRIORITY = Enum.RenderPriority.Input.Value + 1
local DEBUG_INTERVAL = 1 -- seconds between debug lines

-- Placeholder until input capture: every fighter is neutral every frame.
local neutralInputs: Types.FrameInputs = table.create(Constants.FIGHTER_COUNT, 0)

local state: Types.SimState? = nil
local running = false

local function start()
	if running then
		return
	end
	running = true

	local simState = Simulation.new()
	state = simState
	local stepper = FixedStepper.new(function()
		Simulation.step(simState, neutralInputs)
	end)

	local stepsSinceDebug = 0
	local debugTimer = 0
	RunService:BindToRenderStep(BIND_NAME, BIND_PRIORITY, function(dt: number)
		stepsSinceDebug += FixedStepper.advance(stepper, dt)
		debugTimer += dt
		if debugTimer >= DEBUG_INTERVAL then
			print(`[Sim] frame {simState.frame}  steps/s {stepsSinceDebug}  dropped {stepper.droppedFrames}`)
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
end

-- Read-only view for rendering; never write to the returned state.
local function getState(): Types.SimState?
	return state
end

return {
	start = start,
	stop = stop,
	getState = getState,
}
