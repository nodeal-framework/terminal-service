return {
	Name = "test",
	Permission = "Any",
	Description = "Test a terminal type and preview its custom UI and autocompletion.",
	Args = {
		{ 
			Name = "Type", 
			Type = "type", 
			Description = "The type you want to test (e.g. Vector3, Color3, EnumItem...)" 
		},
		{ 
			Name = "Value", 
			Type = function(rawArgs) 
				-- rawArgs[1] contains the value of the first argument, which is the Type Name
				return rawArgs[1] or "string"
			end, 
			Description = "The value to test for the selected type"
		}
	},
	Run = function(context, typeName, value)
		return string.format("Success! Tested type '%s'.\nParsed Value: %s (%s)", typeName, tostring(value), typeof(value))
	end
}
