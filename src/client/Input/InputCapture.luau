--!strict
-- Turns keyboard and Gamepad1 events into one input mask per simulation frame.
-- Held state comes from events; presses are latched until the next sample so sub-frame taps still count.

local UserInputService = game:GetService("UserInputService")

local Input = require(game:GetService("ReplicatedStorage").Shared.Sim.Input)
local Bindings = require(script.Parent.Bindings)

local GAMEPAD = Enum.UserInputType.Gamepad1
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

local heldBits: { [Enum.KeyCode]: number } = {}
local stickMask = 0
local latched = 0
local connections: { RBXScriptConnection } = {}

local function bitFor(input: InputObject): number?
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return Bindings.keyboard[input.KeyCode]
	elseif input.UserInputType == GAMEPAD then
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

local function clear()
	table.clear(heldBits)
	stickMask = 0
	latched = 0
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local bit = bitFor(input)
	if bit then
		heldBits[input.KeyCode] = bit
		latched = bit32.bor(latched, bit)
	end
end

local function onInputEnded(input: InputObject)
	heldBits[input.KeyCode] = nil
end

local function onInputChanged(input: InputObject)
	if input.UserInputType == GAMEPAD and input.KeyCode == Enum.KeyCode.Thumbstick1 then
		stickMask = stickToMask(input.Position)
		latched = bit32.bor(latched, stickMask)
	end
end

-- Returns this frame's mask and clears the press latch. Call once per simulation step.
local function sample(): number
	local mask = bit32.bor(latched, stickMask)
	for _, bit in heldBits do
		mask = bit32.bor(mask, bit)
	end
	latched = 0
	return Input.clean(mask)
end

local function start()
	if #connections > 0 then
		return
	end
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
	-- Releases are missed while the window is unfocused, so drop everything to avoid stuck keys.
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(clear))
	table.insert(connections, UserInputService.GamepadDisconnected:Connect(clear))
end

local function stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	clear()
end

return {
	start = start,
	stop = stop,
	sample = sample,
}
