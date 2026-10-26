--!strict
-- Turns one player's keyboard keys (and optionally a gamepad) into one input mask per simulation frame.
-- Create one capture per local player. Held state comes from events; presses are latched until the next
-- sample so sub-frame taps still count.

local UserInputService = game:GetService("UserInputService")

local Input = require(game:GetService("ReplicatedStorage").Shared.Sim.Input)
local Bindings = require(script.Parent.Bindings)

local SECTOR_ANGLE = math.pi / 4

-- 45-degree stick sectors counter-clockwise from right. Equal sectors leave no neutral gap between directions.
local STICK_SECTORS = {
	[0] = Input.RIGHT,
	[1] = Input.UP + Input.RIGHT,
	[2] = Input.UP,
	[3] = Input.UP + Input.LEFT,
	[4] = Input.LEFT,
	[5] = Input.DOWN + Input.LEFT,
	[6] = Input.DOWN,
	[7] = Input.DOWN + Input.RIGHT,
}

export type Capture = {
	keyboard: { [Enum.KeyCode]: number },
	gamepad: Enum.UserInputType?, -- e.g. Gamepad1, or nil for keyboard only
	heldBits: { [Enum.KeyCode]: number },
	stickMask: number,
	latched: number,
	connections: { RBXScriptConnection },
}

local function new(keyboard: { [Enum.KeyCode]: number }, gamepad: Enum.UserInputType?): Capture
	return {
		keyboard = keyboard,
		gamepad = gamepad,
		heldBits = {},
		stickMask = 0,
		latched = 0,
		connections = {},
	}
end

local function bitFor(capture: Capture, input: InputObject): number?
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return capture.keyboard[input.KeyCode]
	elseif capture.gamepad and input.UserInputType == capture.gamepad then
		return Bindings.gamepad[input.KeyCode]
	end
	return nil
end

local function stickToMask(position: Vector3): number
	local x, y = position.X, position.Y
	if x * x + y * y < Bindings.stickDeadzone * Bindings.stickDeadzone then
		return 0
	end
	local sector = math.floor(math.atan2(y, x) / SECTOR_ANGLE + 0.5) % 8
	return STICK_SECTORS[sector]
end

local function clear(capture: Capture)
	table.clear(capture.heldBits)
	capture.stickMask = 0
	capture.latched = 0
end

-- Returns this frame's mask and clears the press latch. Call once per simulation step.
local function sample(capture: Capture): number
	local mask = bit32.bor(capture.latched, capture.stickMask)
	for _, bit in capture.heldBits do
		mask = bit32.bor(mask, bit)
	end
	capture.latched = 0
	return Input.clean(mask)
end

local function start(capture: Capture)
	if #capture.connections > 0 then
		return
	end
	local connections = capture.connections
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			local bit = bitFor(capture, input)
			if bit then
				capture.heldBits[input.KeyCode] = bit
				capture.latched = bit32.bor(capture.latched, bit)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			capture.heldBits[input.KeyCode] = nil
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				capture.gamepad
				and input.UserInputType == capture.gamepad
				and input.KeyCode == Enum.KeyCode.Thumbstick1
			then
				capture.stickMask = stickToMask(input.Position)
				capture.latched = bit32.bor(capture.latched, capture.stickMask)
			end
		end)
	)
	-- Releases are missed while the window is unfocused, so drop everything to avoid stuck keys.
	table.insert(
		connections,
		UserInputService.WindowFocusReleased:Connect(function()
			clear(capture)
		end)
	)
	table.insert(
		connections,
		UserInputService.GamepadDisconnected:Connect(function()
			clear(capture)
		end)
	)
end

local function stop(capture: Capture)
	for _, connection in capture.connections do
		connection:Disconnect()
	end
	table.clear(capture.connections)
	clear(capture)
end

return {
	new = new,
	start = start,
	stop = stop,
	sample = sample,
}
