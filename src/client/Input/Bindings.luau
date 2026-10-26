--!strict
-- Default device bindings from raw Roblox inputs to input-mask bits. Data only, so it can be made rebindable.

local Input = require(game:GetService("ReplicatedStorage").Shared.Sim.Input)

local keyboard: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.W] = Input.UP,
	[Enum.KeyCode.A] = Input.LEFT,
	[Enum.KeyCode.S] = Input.DOWN,
	[Enum.KeyCode.D] = Input.RIGHT,
	[Enum.KeyCode.U] = Input.B1,
	[Enum.KeyCode.I] = Input.B2,
	[Enum.KeyCode.J] = Input.B3,
	[Enum.KeyCode.K] = Input.B4,
}

-- Tekken layout: X/Y are punches, A/B are kicks.
local gamepad: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.DPadUp] = Input.UP,
	[Enum.KeyCode.DPadLeft] = Input.LEFT,
	[Enum.KeyCode.DPadDown] = Input.DOWN,
	[Enum.KeyCode.DPadRight] = Input.RIGHT,
	[Enum.KeyCode.ButtonX] = Input.B1,
	[Enum.KeyCode.ButtonY] = Input.B2,
	[Enum.KeyCode.ButtonA] = Input.B3,
	[Enum.KeyCode.ButtonB] = Input.B4,
}

return {
	keyboard = keyboard,
	gamepad = gamepad,
	-- (start) How far the left stick must tilt, in any direction, before it counts as one of 8 directions.
	stickDeadzone = 0.5,
}
