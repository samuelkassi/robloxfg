--!strict
-- Motion inputs as data, in numpad notation relative to facing. The list is in priority order:
-- supers before specials, then longer motions before shorter ones, so 236236 wins over 236.
-- A command's id is its index in this list.

export type Motion = {
	name: string,
	steps: { number },
	kind: number,
}

local SPECIAL = 1
local SUPER = 2

local LIST: { Motion } = {
	{ name = "236236", steps = { 2, 3, 6, 2, 3, 6 }, kind = SUPER },
	{ name = "214214", steps = { 2, 1, 4, 2, 1, 4 }, kind = SUPER },
	{ name = "41236", steps = { 4, 1, 2, 3, 6 }, kind = SPECIAL },
	{ name = "63214", steps = { 6, 3, 2, 1, 4 }, kind = SPECIAL },
	{ name = "623", steps = { 6, 2, 3 }, kind = SPECIAL },
	{ name = "236", steps = { 2, 3, 6 }, kind = SPECIAL },
	{ name = "214", steps = { 2, 1, 4 }, kind = SPECIAL },
}
for _, motion in LIST do
	table.freeze(motion.steps)
	table.freeze(motion)
end

return table.freeze({
	SPECIAL = SPECIAL,
	SUPER = SUPER,
	LIST = table.freeze(LIST),
	DASH_STEPS = table.freeze({ 6, 6 }),
	BACKDASH_STEPS = table.freeze({ 4, 4 }),
})
