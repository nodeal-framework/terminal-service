--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

--[=[
	Implements the `history` command: Shows recent command history.
]=]

return {
	Name = "history",
	Permission = "Moderator", -- shows every player's commands, staff ones included
	Aliases = { "hist" },
	Description = "Shows recent command history",
	Args = {
		{
			Name = "Count",
			Type = "number",
			Description = "How many entries to show",
			Default = 20,
			Optional = true,
		},
	},
	--[=[
		Shows recent command history.

		@param context The command context.
		@param count How many entries to show
		@return A status message when the command succeeds.
	]=]
	Run = function(context, count: number)
		local entries = context.Terminal:GetHistory()
		if #entries == 0 then
			return "No commands executed yet."
		end

		local startIdx = math.max(1, #entries - math.max(0, count - 1))
		local lines = {}
		for i = startIdx, #entries do
			local e = entries[i]
			table.insert(lines, `{i}  {e.line}`)
		end
		return table.concat(lines, "\n")
	end,
}
