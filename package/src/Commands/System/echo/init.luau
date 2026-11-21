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
	Implements the `echo` command: Prints the input message to the terminal
	output.
]=]

return {
	Name = "echo",
	Permission = "Any",
	Aliases = {},
	Description = "Prints the input message to the terminal output",
	Args = {
		{ Name = "Message", Type = "string", Description = "The message to display", Default = "" },
	},
	--[=[
		Prints the input message to the terminal output.

		@param context The command context.
		@param message The message to display
		@return A status message when the command succeeds.
	]=]
	Run = function(context, message: string)
		return message
	end,
}
