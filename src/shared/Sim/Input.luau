--!strict
-- The per-frame input bitmask: 4 screen-relative direction bits plus buttons 1-4.
-- Pure helpers shared by every device layer and the simulation.

local Types = require(script.Parent.Types)

type InputMask = Types.InputMask

local UP = 1
local DOWN = 2
local LEFT = 4
local RIGHT = 8
local B1 = 16
local B2 = 32
local B3 = 64
local B4 = 128

local BUTTONS = { B1, B2, B3, B4 }

-- (start) Opposite directions held together cancel to neutral on that axis.
local SOCD_NEUTRAL_PAIRS = { LEFT + RIGHT, UP + DOWN }

local function has(mask: InputMask, bits: number): boolean
	return bit32.band(mask, bits) == bits
end

-- Applies SOCD cleaning; every device's mask goes through this before it reaches the simulation.
local function clean(mask: InputMask): InputMask
	for _, pair in SOCD_NEUTRAL_PAIRS do
		if has(mask, pair) then
			mask = bit32.band(mask, bit32.bnot(pair))
		end
	end
	return mask
end

-- Numpad direction (1-9, 5 = neutral) relative to the fighter's facing: 6 is forward.
local function toNumpad(mask: InputMask, facingRight: boolean): number
	local forward = if facingRight then RIGHT else LEFT
	local back = if facingRight then LEFT else RIGHT
	local x = (if has(mask, forward) then 1 else 0) - (if has(mask, back) then 1 else 0)
	local y = (if has(mask, UP) then 1 else 0) - (if has(mask, DOWN) then 1 else 0)
	return 5 + x + 3 * y
end

-- The buttons in a mask as "+1+2", or "" when none are pressed.
local function describeButtons(mask: InputMask): string
	local text = ""
	for button, bit in BUTTONS do
		if has(mask, bit) then
			text ..= `+{button}`
		end
	end
	return text
end

-- Numpad notation with buttons, as seen facing right, e.g. "3+1" or "5+1+2".
local function describe(mask: InputMask): string
	return tostring(toNumpad(mask, true)) .. describeButtons(mask)
end

return {
	UP = UP,
	DOWN = DOWN,
	LEFT = LEFT,
	RIGHT = RIGHT,
	B1 = B1,
	B2 = B2,
	B3 = B3,
	B4 = B4,
	BUTTON_BITS = B1 + B2 + B3 + B4,
	clean = clean,
	toNumpad = toNumpad,
	describeButtons = describeButtons,
	describe = describe,
}
