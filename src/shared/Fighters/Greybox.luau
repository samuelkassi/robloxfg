--!strict
-- Placeholder fighter used by both sides until real fighters exist.

local Types = require(script.Parent.Parent.Sim.Types)

local data: Types.FighterData = table.freeze({
	walkForwardSpeed = 42, -- (start) about 2.5 studs/s
	walkBackSpeed = 33, -- (start) about 2 studs/s
	pushboxHalfWidth = 1000, -- (start) 1 stud
})

return data
