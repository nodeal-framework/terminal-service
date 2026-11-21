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
	Implements the `try` command: Preview a terminal type's custom UI and
	autocompletion.
]=]

return {
	Name = "try",
	Permission = "Any",
	Description = "Preview a terminal type's custom UI and autocompletion.",
	Args = {
		{
			Name = "Type",
			Type = "type",
			Description = "The type you want to test (e.g. Vector3, Color3, EnumItem...)",
		},
		{
			Name = "Value",
			--[=[
				Returns the type name typed as the first argument.

				@param rawArgs The raw argument tokens.
				@return The type name.
			]=]
			Type = function(rawArgs)
				return rawArgs[1] or "string"
			end,
			Description = "The value to test for the selected type",
		},
	},
	--[=[
		Preview a terminal type's custom UI and autocompletion.

		@param context The command context.
		@param typeName The type name to resolve.
		@param value The value to inspect.
		@return A status message when the command succeeds.
	]=]
	Run = function(context, typeName, value)
		return string.format(
			"Success! Tested type '%s'.\nParsed Value: %s (%s)",
			typeName,
			tostring(value),
			typeof(value)
		)
	end,
}
