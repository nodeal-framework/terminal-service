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
	Implements the `help` command: Lists all commands grouped by category or
	shows detailed usage for a specific command.
]=]

local Help = {}

Help.Name = "help"
Help.Permission = "Any"
Help.Aliases = { "man", "?" }
Help.Description = "Lists all commands grouped by category or shows detailed usage for a specific "
	.. "command"
Help.Args = {
	{
		Name = "Command",
		Type = "command",
		Description = "Command name to get details",
		Optional = true,
	},
}

--[=[
	Lists all commands grouped by category or shows detailed usage for a
	specific command.

	@param context The command context.
	@param commandName The command name to look up.
	@return A status message when the command succeeds.
]=]
function Help.Run(context, commandName: string?)
	local TerminalService = context.Terminal
	if not commandName then
		local byCategory = {}
		for _, command in TerminalService:GetCommands() do
			local cat = command.Category or "Other"
			if not byCategory[cat] then
				byCategory[cat] = {}
			end
			table.insert(byCategory[cat], command)
		end

		local list = { "Available Commands:" }
		local sortedCats = {}
		for cat in byCategory do
			table.insert(sortedCats, cat)
		end
		table.sort(sortedCats)

		for _, cat in sortedCats do
			table.insert(list, "")
			table.insert(list, `  [{cat}]`)
			local sorted = {}
			for _, c in byCategory[cat] do
				table.insert(sorted, c)
			end
			table.sort(sorted, function(a, b)
				return a.Name < b.Name
			end)
			for _, c in sorted do
				local aliasText = (#c.Aliases > 0) and ` (aliases: {table.concat(c.Aliases, ", ")})`
					or ""
				table.insert(list, `    {c.Name}{aliasText} - {c.Description}`)
			end
		end

		table.insert(list, "")
		table.insert(
			list,
			"Shell syntax: if/for/while/until/case, functions, source, aliases, variables, pipes."
		)
		table.insert(list, "Tip: Use '` <player>' to redirect stdout to a player's terminal.")
		table.insert(list, "Tip: Pipe commands with '|', chain with ';', '&&', '||'.")
		table.insert(
			list,
			"Tip: Here-documents work: 'cat <<EOF ... EOF' and '<<-EOF' strip leading tabs."
		)
		table.insert(
			list,
			"Tip: There is no filesystem: '< file', 'cat file' and 'cd' are unavailable."
		)
		return table.concat(list, "\n")
	end

	local command = TerminalService:GetCommand(commandName)
	if not command then
		return `Command '{commandName}' not found.`
	end

	local detail = {
		`Command: {command.Name}`,
		`Category: {command.Category or "Other"}`,
		`Description: {command.Description}`,
	}

	if #command.Aliases > 0 then
		table.insert(detail, `Aliases: {table.concat(command.Aliases, ", ")}`)
	end

	if command.Permission and command.Permission ~= "Any" then
		table.insert(detail, `Permission: {command.Permission}`)
	end

	if #command.Args > 0 then
		table.insert(detail, "Arguments:")
		for _, argSpec in command.Args do
			local reqText = argSpec.Optional and "[Optional]" or "[Required]"
			local defaultText = argSpec.Default ~= nil and ` (Default: {tostring(argSpec.Default)})`
				or ""
			table.insert(
				detail,
				`  * {argSpec.Name} ({argSpec.Type}) {reqText}{defaultText} - {argSpec.Description or ""}`
			)
		end
	else
		table.insert(detail, "Arguments: None")
	end

	return table.concat(detail, "\n")
end

return Help
